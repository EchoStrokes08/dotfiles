// OSD: el indicador flotante de volumen, micro, brillo, Bloq Mayús, música y avisos.
// Aparece en la isla del reloj (RelojBarra.qml) o, si la barra no se ve, abajo al centro; se va solo tras 1,5 s.
//
// Volumen y micro: se muestran SOLOS al cambiar (escucha PipeWire), venga de donde venga.
// El resto lo avisan los atajos después de hacer el cambio (así las teclas funcionan aunque qs no esté):
//   qs ipc call osd brillo                      lee el brillo y lo muestra
//   qs ipc call osd bloqMayus                   lee Bloq Mayús de todos los teclados
//   qs ipc call osd media                       muestra la canción actual
//   qs ipc call osd mensaje "Texto" "icono"     aviso libre (icono = código Nerd Font en hex, p. ej. f0297)
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Scope {
    id: osd

    // Lo que se está mostrando
    property string icono: ""
    property string texto: ""        // mensaje (si no hay barra)
    property real valor: -1          // 0..1 = barra; -1 = sin barra
    property bool apagado: false     // silenciado / desactivado (atenúa la barra)
    property bool activo: false      // ¿se está mostrando?

    function g(cp) { return String.fromCodePoint(cp); }

    // color de la barra y el icono: gris si está apagado, aviso si el volumen pasa del 100 %
    readonly property color tono: apagado ? Paleta.gris : valor > 1.001 ? Paleta.aviso : Paleta.acento
    signal latido()                  // cada cambio: el icono late una vez

    function mostrar(ic, val, txt, off) {
        icono = ic; valor = val; texto = txt ?? ""; apagado = off ?? false;
        // Con la barra a la vista, el aviso lo enseña la isla del reloj (Isla.qml); esta pastilla
        // queda para cuando la barra no se ve (juego, pantalla completa).
        Isla.mostrar(ic, val, txt, off);
        activo = true;
        latido();
        ocultar.restart();
    }
    Timer { id: ocultar; interval: 1500; onTriggered: osd.activo = false }

    // No mostrar nada mientras PipeWire carga sus valores al arrancar
    property bool listo: false
    Timer { interval: 2000; running: true; onTriggered: osd.listo = true }

    // ── Volumen y micro (automático) ────────────────────────────────────
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [osd.salida, osd.entrada] }

    function mostrarVolumen() {
        const a = salida?.audio;
        if (!a || !listo) return;
        const v = a.volume;
        mostrar(a.muted ? g(0xF075F) : g(v < 0.34 ? 0xF057F : v < 0.67 ? 0xF0580 : 0xF057E), v, "", a.muted);
    }
    Connections {
        target: osd.salida?.audio ?? null
        function onVolumeChanged() { osd.mostrarVolumen(); }
        function onMutedChanged() { osd.mostrarVolumen(); }
    }
    Connections {
        target: osd.entrada?.audio ?? null
        function onMutedChanged() {
            if (!osd.listo) return;
            const m = osd.entrada.audio.muted;
            osd.mostrar(osd.g(m ? 0xF036D : 0xF036C), -1, m ? "Micrófono silenciado" : "Micrófono activo", m);
        }
    }

    // ── Brillo (lo avisa el atajo) ──────────────────────────────────────
    Process {
        id: lectorBrillo
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = (parseInt(this.text.split(",")[3]) || 0) / 100;
                osd.mostrar(osd.g(p < 0.34 ? 0xF00DE : p < 0.67 ? 0xF00DF : 0xF00E0), p, "");
            }
        }
    }

    // ── Bloq Mayús en cualquier teclado (lo avisa el atajo al soltar la tecla) ──
    Process {
        id: lectorTeclados
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let activo = false;
                try { activo = JSON.parse(this.text).keyboards.some(k => k.capsLock); } catch (e) {}
                osd.mostrar(osd.g(0xF0632), -1, activo ? "Bloq Mayús activado" : "Bloq Mayús desactivado", !activo);
            }
        }
    }

    // ── Música ──────────────────────────────────────────────────────────
    Timer {   // la canción tarda un poco en actualizarse tras "siguiente"
        id: esperaMedia; interval: 350
        onTriggered: {
            const lista = Mpris.players.values;
            const j = lista.find(p => p.isPlaying) ?? lista[0];
            if (!j) { osd.mostrar(osd.g(0xF075B), -1, "Nada sonando", true); return; }
            const t = j.trackTitle + (j.trackArtist ? " · " + j.trackArtist : "");
            osd.mostrar(osd.g(j.isPlaying ? 0xF040A : 0xF03E4), -1, t || j.identity);
        }
    }

    IpcHandler {
        target: "osd"
        function brillo(): void { lectorBrillo.running = true; }
        function bloqMayus(): void { lectorTeclados.running = true; }
        function media(): void { esperaMedia.restart(); }
        function mensaje(txt: string, icono: string): void {
            osd.mostrar(icono ? osd.g(parseInt(icono, 16)) : "", -1, txt);
        }
    }

    // ── La ventana ──────────────────────────────────────────────────────
    PanelWindow {
        id: ventana
        visible: (osd.activo || animSalida.running) && !Isla.enBarra
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 40
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: pastilla.width + 90      // sitio para la sombra
        implicitHeight: pastilla.height + 80
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        mask: Region {}                       // los clics atraviesan el OSD

        Rectangle {
            id: pastilla
            anchors.centerIn: parent
            width: fila.implicitWidth + 36
            height: 60
            color: "transparent"
            FondoPanel { anchors.fill: parent; radio: 24; acento: osd.tono }

            opacity: osd.activo ? 1 : 0
            scale: osd.activo ? 1 : 0.92
            Behavior on opacity { NumberAnimation { id: animSalida; duration: EstiloPanel.normal } }
            Behavior on scale   { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
            Behavior on width   { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }

            RowLayout {
                id: fila
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: medallon
                    implicitWidth: 40; implicitHeight: 40; radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(osd.apagado ? Paleta.gris : Qt.lighter(osd.tono, 1.15), .38) }
                        GradientStop { position: 1; color: Qt.alpha(osd.tono, .12) }
                    }
                    border { width: 1; color: Qt.alpha(osd.tono, .45) }
                    RectangularShadow {
                        anchors.fill: parent; z: -1
                        visible: EstiloPanel.profundidad && !osd.apagado
                        radius: parent.radius; blur: 16
                        color: Qt.alpha(osd.tono, .25 + .35 * medallon.brillo)
                    }
                    // latido: crece un poco y vuelve con rebote; el halo destella a la vez
                    property real brillo: 0
                    Connections { target: osd; function onLatido() { if (EstiloPanel.movimiento) latidoIcono.restart(); } }
                    ParallelAnimation {
                        id: latidoIcono
                        SequentialAnimation {
                            NumberAnimation { target: medallon; property: "scale"; to: 1.1; duration: 70; easing.type: Easing.OutCubic }
                            NumberAnimation { target: medallon; property: "scale"; to: 1; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
                        }
                        SequentialAnimation {
                            NumberAnimation { target: medallon; property: "brillo"; to: 1; duration: 70 }
                            NumberAnimation { target: medallon; property: "brillo"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutCubic }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: osd.icono
                        color: osd.apagado ? Paleta.gris : Qt.lighter(osd.tono, 1.2)
                        font { family: Paleta.fuente; pixelSize: 20 }
                    }
                }

                // Barra (volumen / brillo)
                Rectangle {
                    visible: osd.valor >= 0
                    implicitWidth: 230
                    implicitHeight: 10
                    radius: height / 2
                    color: EstiloPanel.rellenoActivo
                    border { width: 1; color: EstiloPanel.relleno }
                    RectangularShadow {
                        width: barraOsd.width; height: parent.height
                        visible: EstiloPanel.profundidad && !osd.apagado
                        radius: 4; blur: 14; spread: -1
                        color: Qt.alpha(osd.tono, .45)
                    }
                    Repeater {   // marcas al 25, 50 y 75 %
                        model: [.25, .5, .75]
                        Rectangle {
                            required property real modelData
                            x: parent.width * modelData; y: 3
                            width: 1; height: parent.height - 6
                            color: Qt.alpha(Paleta.texto, .18)
                        }
                    }
                    Rectangle {
                        id: barraOsd
                        height: parent.height
                        radius: 4
                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, osd.valor)))
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha(osd.tono, .55) }
                            GradientStop { position: 1; color: osd.apagado ? Paleta.gris : Qt.lighter(osd.tono, 1.12) }
                        }
                        Behavior on width { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
                    }
                    Item {   // punta luminosa: un punto de luz en el extremo de la barra
                        visible: !osd.apagado
                        width: 14; height: 14
                        x: barraOsd.width - width / 2 - 2
                        anchors.verticalCenter: parent.verticalCenter
                        RectangularShadow {
                            anchors.fill: parent
                            visible: EstiloPanel.profundidad
                            radius: width / 2; blur: 12; spread: 1
                            color: Qt.alpha(osd.tono, .9)
                        }
                        Rectangle {
                            anchors.fill: parent; radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.lighter(osd.tono, 1.6) }
                                GradientStop { position: 1; color: Qt.lighter(osd.tono, 1.15) }
                            }
                            border { width: 1; color: Qt.alpha("white", .5) }
                        }
                    }
                }
                Text {
                    visible: osd.valor >= 0
                    Layout.minimumWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(osd.valor * 100) + "%"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true; features: { "tnum": 1 } }
                }

                // Mensaje (Bloq Mayús, micro, música, avisos)
                Text {
                    visible: osd.valor < 0 && osd.texto !== ""
                    Layout.maximumWidth: 420
                    text: osd.texto
                    elide: Text.ElideRight
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true }
                }
            }
        }
    }
}
