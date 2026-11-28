// CapaCursor: sacude el dedo en el touchpad y el puntero se señala solo (Gestos.sacudida).
// Un halo suave del acento aparece grande alrededor del puntero y se encoge sobre él con un pequeño
// rebote, con un anillo fino detrás; al final una onda se abre y se desvanece (1,1 s). La pantalla no se
// oscurece y el puntero se sigue 10 veces por segundo, suavizado: es ligero. Los clics atraviesan la capa.
//   qs ipc call cursor buscar   para verlo sin sacudir
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: c
    property real px: 0                 // puntero en coordenadas de esta pantalla
    property real py: 0
    property real t: 0                  // 0 → 1 a lo largo del efecto
    readonly property real velo: Math.min(1, t * 6) * Math.min(1, (1 - t) * 3)

    visible: anim.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-cursor"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections { target: Gestos; function onSacudida() { c.buscar(); } }
    IpcHandler { target: "cursor"; function buscar(): void { c.buscar(); } }

    function buscar() {
        if (anim.running) { anim.restart(); return; }
        posicion.running = true;
    }
    // dónde está: hyprctl cursorpos (lógicas, globales); mientras dura, se repite para seguirlo
    Process {
        id: posicion
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p; try { p = JSON.parse(text); } catch (e) { return; }
                if (!anim.running) {
                    const s = Quickshell.screens.find(x => p.x >= x.x && p.x < x.x + x.width && p.y >= x.y && p.y < x.y + x.height);
                    if (s) c.screen = s;
                    c.px = p.x - (c.screen?.x ?? 0); c.py = p.y - (c.screen?.y ?? 0);
                    anim.restart();
                } else {
                    c.px = p.x - (c.screen?.x ?? 0); c.py = p.y - (c.screen?.y ?? 0);
                }
            }
        }
    }
    Timer { interval: 100; repeat: true; running: anim.running; onTriggered: if (!posicion.running) posicion.running = true }
    NumberAnimation { id: anim; target: c; property: "t"; from: 0; to: 1; duration: 1100; easing.type: Easing.Linear }

    Behavior on px { enabled: anim.running; SmoothedAnimation { velocity: 2500 } }
    Behavior on py { enabled: anim.running; SmoothedAnimation { velocity: 2500 } }

    // encogerse: de grande a su sitio con un rebote (OutBack a mano, sin animaciones anidadas)
    function rebote(k) { const s = 1.6; k = Math.min(1, Math.max(0, k)) - 1; return k * k * ((s + 1) * k + s) + 1; }
    readonly property real cierre: rebote(c.t / .6)              // 0 → 1 en el primer 60 %

    // el halo: un círculo difuminado que pasa de 200 a 52 px
    RectangularShadow {
        readonly property real lado: 200 - 148 * c.cierre
        x: c.px - lado / 2; y: c.py - lado / 2
        width: lado; height: lado
        radius: lado / 2
        blur: 28; spread: -4
        color: Qt.alpha(Paleta.acento, .55)
        opacity: c.velo * .9
    }
    // anillo fino que llega un poco después
    Rectangle {
        readonly property real lado: 240 - 196 * c.rebote((c.t - .08) / .6)
        x: c.px - lado / 2; y: c.py - lado / 2
        width: lado; height: lado; radius: lado / 2
        color: "transparent"
        border { width: 2; color: Qt.alpha(Paleta.acento2, .9) }
        opacity: c.velo * Math.min(1, c.t * 8)
    }
    // la onda final: se abre desde el puntero y se apaga
    Rectangle {
        readonly property real k: Math.max(0, (c.t - .55) / .45)
        readonly property real lado: 44 + 70 * Math.sqrt(k)
        x: c.px - lado / 2; y: c.py - lado / 2
        width: lado; height: lado; radius: lado / 2
        color: "transparent"
        border { width: 2; color: Paleta.acento }
        opacity: k > 0 ? (1 - k) * .8 : 0
    }
}
