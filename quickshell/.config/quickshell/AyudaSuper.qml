// AyudaSuper: mantener SUPER sola unos 0,6 s (pulsación larga de Hyprland + 300 ms) enseña los esenciales y las teclas de la ventana o del modo
// actual; desaparece al soltar (ORION 5.9). No toma el teclado ni el ratón.
// Hyprland avisa al pulsar y al soltar (atajos.lua): qs ipc call ayudaSuper mantener | soltar
// Si mientras tanto pasa algo en el compositor (otro atajo, cambio de ventana) o se mueve el ratón
// (SUPER + arrastrar), no aparece: solo responde a SUPER mantenida a solas.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: ayuda
    property var esenciales: []          // filas {tecla, texto} de la chuleta (docs/atajos.md, ★)
    property bool visible: false
    property bool interrumpida: false
    property bool pulsada: false
    property string motivo: ""
    // Eventos que delatan un atajo o un cambio hecho por la persona (los títulos cambian solos: no cuentan)
    readonly property var interrupciones: ["workspace", "workspacev2", "activewindow", "activewindowv2",
        "openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "submap", "activespecial",
        "focusedmon", "togglegroup", "pin", "minimized"]
    property string cursorAntes: ""

    function mantener() {
        interrumpida = false; visible = false; pulsada = true;
        leerCursor.destino = "antes"; leerCursor.running = true;
        espera.restart();
    }
    function soltar() { pulsada = false; espera.stop(); visible = false; }

    Timer { id: espera; interval: 300; onTriggered: { if (ayuda.interrumpida) return; leerCursor.destino = "despues"; leerCursor.running = true; } }
    Process {
        id: leerCursor
        property string destino: ""
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pos = this.text.trim();
                if (leerCursor.destino === "antes") ayuda.cursorAntes = pos;
                else if (ayuda.pulsada && !ayuda.interrumpida && pos === ayuda.cursorAntes) ayuda.visible = true;
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(evento) {
            // Abrir un panel (SUPER+R, SUPER+D…) también cuenta; avisos y OSD que aparecen solos, no
            const panel = evento.name === "openlayer" && !/osd|emergente|notif|ayuda|tooltip/i.test(evento.data);
            if (ayuda.pulsada && (panel || ayuda.interrupciones.includes(evento.name))) { ayuda.interrumpida = true; ayuda.visible = false; ayuda.motivo = evento.name; } }
    }

    readonly property var ventana: Hyprland.activeToplevel
    readonly property var filasVentana: ModoTeclado.activo ? [] : [
        { tecla: "SUPER+C", texto: "Cerrar" }, { tecla: "SUPER+F", texto: "Pantalla completa" },
        { tecla: "SUPER+V", texto: "Flotante" }, { tecla: "SUPER+SHIFT+flechas", texto: "Mover" }]

    PanelWindow {
        visible: ayuda.visible
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 56
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: tarjeta.width + 48
        implicitHeight: tarjeta.height + 48
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-ayuda-super"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Rectangle {
            id: tarjeta
            anchors.centerIn: parent
            width: Math.min(880, columna.implicitWidth + 48)
            height: columna.implicitHeight + 48
            radius: EstiloPanel.rPanel
            color: Paleta.fondo
            border { width: 1; color: EstiloPanel.bordeFuerte }
            ColumnLayout {
                id: columna
                anchors { fill: parent; margins: 24 }
                spacing: 12
                RowLayout {
                    spacing: 8
                    Etiqueta { text: ModoTeclado.activo ? "MODO " + ModoTeclado.nombre.toUpperCase() : "ESENCIALES" }
                    Item { Layout.fillWidth: true }
                    Text { text: "Suelta SUPER para cerrar · SUPER+H: todos los atajos"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                }
                Text {
                    visible: ModoTeclado.activo
                    text: ModoTeclado.ayuda
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 13 }
                }
                GridLayout {
                    visible: !ModoTeclado.activo
                    columns: 3; columnSpacing: 24; rowSpacing: 8
                    Repeater {
                        model: ayuda.esenciales.slice(0, 15)
                        RowLayout {
                            required property var modelData
                            spacing: 8
                            Tecla { texto: modelData.tecla; anchoMax: 140 }
                            Text { Layout.preferredWidth: 150; text: modelData.texto.split(/[:(·,]/)[0].trim(); elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
                        }
                    }
                }
                RowLayout {
                    visible: ayuda.filasVentana.length > 0 && ayuda.ventana !== null
                    spacing: 12
                    Etiqueta { text: "VENTANA" }
                    Text {
                        Layout.maximumWidth: 200
                        text: EstadoEscritorio.privacidad ? "Ventana actual" : (ayuda.ventana?.title ?? "")
                        elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    Repeater {
                        model: ayuda.filasVentana
                        RowLayout {
                            required property var modelData
                            spacing: 4
                            Tecla { texto: modelData.tecla }
                            Text { text: modelData.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
                        }
                    }
                }
            }
        }
    }
}
