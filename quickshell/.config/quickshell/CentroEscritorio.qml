pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: centro
    espacio: "centro-escritorio"
    anchoTarjeta: Math.min(780, (screen?.width ?? 1280) - 40)
    opacidadTarjeta: 1
    alturaRelativa: .06
    panelCuidado: true
    property string salida: "Guarda un checkpoint antes de reorganizar tus ventanas. Podrás devolverlas a sus espacios y deshacer la restauración."
    function ejecutar(args) {
        if (accion.running) return;
        salida = "Procesando…";
        accion.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/escritorio.py", ...args];
        accion.running = true;
    }
    onAbriendose: Qt.callLater(() => perfiles.forceActiveFocus())
    Repeater {
        model: ["cristal", "lectura", "minimo", "rendimiento"]
        Item {
            required property string modelData
            required property int index
            Shortcut { sequence: "Alt+" + (index + 1); context: Qt.ApplicationShortcut; enabled: centro.abierto; onActivated: centro.ejecutar(["perfil", modelData]) }
        }
    }
    Process {
        id: accion
        stdout: StdioCollector { onStreamFinished: if (text.trim()) centro.salida = text.trim(); }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) centro.salida = text.trim(); }
    }
    component Accion: BotonPanel {
        property string ayuda: ""
        enabled: !accion.running
        ToolTip.visible: hovered && ayuda !== ""
        ToolTip.text: ayuda
        ToolTip.delay: 450
    }
    component Seccion: Text {
        color: EstiloPanel.tenue
        font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.5 }
    }
    ColumnLayout {
        width: parent.width
        spacing: 10
        EncabezadoPanel { seccion: "CENTRO DEL ESCRITORIO"; titulo: "Hazlo tuyo"; simbolo: "󰒓"; onCerrar: centro.abierto=false }
        RowLayout {
            Layout.fillWidth: true
            Rectangle { width: 7; height: 7; radius: 4; color: Paleta.verde }
            Text { Layout.fillWidth: true; text: EstadoEscritorio.motivos; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 12 } }
            Text { text: "Alt + 1…4"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 10 } }
        }
        RowLayout {
            id: perfiles
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    {id:"cristal",titulo:"Cristal",detalle:"Luz y profundidad",icono:"󰌌",color:Paleta.naranja},
                    {id:"lectura",titulo:"Lectura",detalle:"Claridad al leer",icono:"󰑴",color:Paleta.azul},
                    {id:"minimo",titulo:"Mínimo",detalle:"Solo lo esencial",icono:"󰓅",color:Paleta.verde},
                    {id:"rendimiento",titulo:"Rendimiento",detalle:"Espacio y rapidez",icono:"󰒓",color:Paleta.morado}
                ]
                Accion {
                    id: perfil
                    required property var modelData
                    implicitHeight: 94
                    text: modelData.titulo
                    destacado: EstadoEscritorio.perfil === modelData.id
                    tinte: modelData.color
                    ayuda: modelData.detalle
                    contentItem: ColumnLayout {
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: perfil.modelData.icono; color: perfil.tinte; font { family: Paleta.fuente; pixelSize: 22 } }
                            Item { Layout.fillWidth: true }
                            Text { text: perfil.destacado ? "✓" : ""; color: perfil.tinte; font.pixelSize: 14 }
                        }
                        Text { Layout.fillWidth: true; text: perfil.text; elide: Text.ElideRight; color: Paleta.texto; font { family: EstiloPanel.fuente; pixelSize: 14; weight: Font.DemiBold } }
                        Text { Layout.fillWidth: true; text: perfil.modelData.detalle; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                    }
                    onClicked: centro.ejecutar(["perfil", modelData.id])
                }
            }
        }
        Seccion { text: "ORGANIZACIÓN Y PRIVACIDAD" }
        GridLayout {
            Layout.fillWidth: true; columns: 3; columnSpacing: 8; rowSpacing: 8
            Accion { text: "Guardar checkpoint"; simbolo: "󰆓"; onClicked: centro.ejecutar(["checkpoint", "guardar"]) }
            Accion { text: "Restaurar espacios"; simbolo: "󰁯"; ayuda: "Devuelve las ventanas existentes a los espacios guardados y guarda una opción para deshacer."; onClicked: centro.ejecutar(["checkpoint", "restaurar"]) }
            Accion { text: "Deshacer restauración"; ayuda: "Recupera los espacios anteriores a la última restauración."; onClicked: centro.ejecutar(["checkpoint", "deshacer"]) }
            Accion { text: Reunion.activa ? "Privacidad · reunión" : EstadoEscritorio.privacidad ? "Privacidad activada" : "Activar privacidad"; simbolo: "󰒃"; enabled: !Reunion.activa && !accion.running; destacado: EstadoEscritorio.privacidad; onClicked: centro.ejecutar(["privacidad"]) }
            Accion { text: "Juego automático"; simbolo: "󰊗"; onClicked: centro.ejecutar(["juego", "automatico"]) }
            Accion { text: "Diagnóstico"; simbolo: "󰋊"; onClicked: centro.ejecutar(["diagnostico"]) }
        }
        Seccion { text: "CAPTURA EN SEGUNDO PLANO" }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Accion { text: "Replay automático"; simbolo: "󰑋"; ayuda: "Graba con cargador; pausa con batería, privacidad o perfil mínimo."; onClicked: centro.ejecutar(["replay", "auto"]) }
            Accion { text: "Pausar replay"; simbolo: "󰏤"; onClicked: centro.ejecutar(["replay", "stop"]) }
            Accion { text: "Guardar últimos 30 s"; simbolo: "󰕧"; onClicked: centro.ejecutar(["replay", "save"]) }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(86, (screen?.height ?? 720) - 555)
            Layout.minimumHeight: 60
            radius: 10; color: EstiloPanel.superficie
            border { width: 1; color: EstiloPanel.borde }
            ScrollView {
                anchors { fill: parent; margins: 8 }
                clip: true
                TextArea { text: centro.salida; readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: EstiloPanel.tenue; selectionColor: Qt.alpha(Paleta.naranja,.35); font { family: EstiloPanel.fuente; pixelSize: 12 } background: null }
            }
        }
        Accion { text: "Mesa de trabajo · ventanas, plantillas y rutinas"; simbolo: "󰕰"; tinte: Paleta.azul; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "mesa", "abrir", "ventanas"]) }
        Text { Layout.fillWidth: true; text: "La privacidad oculta títulos y pausa el replay. Los checkpoints duran esta sesión."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; font { family: EstiloPanel.fuente; pixelSize: 11 } }
    }
}
