// OSD: el indicador flotante de volumen, micro, brillo, Bloq Mayús, música y avisos.
// Sustituye a swayosd. Aparece abajo al centro y se va solo tras 1,5 s.
//
// Volumen y micro: se muestran SOLOS al cambiar (escucha PipeWire), venga de donde venga.
// El resto lo avisan los atajos después de hacer el cambio (así las teclas funcionan aunque qs no esté):
//   qs ipc call osd brillo                      lee el brillo y lo muestra
//   qs ipc call osd bloqMayus                   lee Bloq Mayús de todos los teclados
//   qs ipc call osd media                       muestra la canción actual
//   qs ipc call osd mensaje "Texto" "icono"     aviso libre (icono = código Nerd Font en hex, p. ej. f0297)
import QtQuick
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

    function mostrar(ic, val, txt, off) {
        icono = ic; valor = val; texto = txt ?? ""; apagado = off ?? false;
        activo = true;
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
        visible: osd.activo || animSalida.running
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 70
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: pastilla.width + 20
        implicitHeight: pastilla.height + 20
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        mask: Region {}                       // los clics atraviesan el OSD

        Rectangle {
            id: pastilla
            anchors.centerIn: parent
            width: fila.implicitWidth + 40
            height: 56
            radius: 16
            color: Qt.alpha(Paleta.fondo, 0.88)
            border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }

            opacity: osd.activo ? 1 : 0
            scale: osd.activo ? 1 : 0.92
            Behavior on opacity { NumberAnimation { id: animSalida; duration: 180 } }
            Behavior on scale   { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on width   { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                id: fila
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: osd.icono
                    color: osd.apagado ? Paleta.gris : Paleta.naranja
                    font { family: Paleta.fuente; pixelSize: 22 }
                }

                // Barra (volumen / brillo)
                Rectangle {
                    visible: osd.valor >= 0
                    implicitWidth: 220
                    implicitHeight: 8
                    radius: 4
                    color: Qt.alpha(Paleta.texto, 0.12)
                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: parent.width * Math.max(0, Math.min(1, osd.valor))
                        color: osd.apagado ? Paleta.gris : Paleta.naranja
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    visible: osd.valor >= 0
                    Layout.minimumWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(osd.valor * 100) + "%"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true }
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
