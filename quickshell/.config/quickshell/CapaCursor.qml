// CapaCursor: sacude el dedo en el touchpad y el puntero se señala solo (Gestos.sacudida).
// La pantalla se apaga un poco salvo un foco alrededor del puntero y dos anillos del acento se cierran
// hacia él; el foco lo sigue mientras dura (1,4 s). Los clics atraviesan la capa.
//   qs ipc call cursor buscar   para verlo sin sacudir
import QtQuick
import QtQuick.Shapes
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
    Timer { interval: 33; repeat: true; running: anim.running; onTriggered: if (!posicion.running) posicion.running = true }
    NumberAnimation { id: anim; target: c; property: "t"; from: 0; to: 1; duration: 1400; easing.type: Easing.Linear }

    Behavior on px { enabled: anim.running; SmoothedAnimation { velocity: 4000; duration: 60 } }
    Behavior on py { enabled: anim.running; SmoothedAnimation { velocity: 4000; duration: 60 } }

    // el foco: todo se oscurece menos un círculo alrededor del puntero (degradado radial)
    readonly property real radio: 110 + 260 * Math.pow(1 - Math.min(1, c.t * 2.2), 3)
    Shape {
        anchors.fill: parent
        opacity: c.velo
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: c.px; centerY: c.py; centerRadius: c.radio * 2.4
                focalX: c.px; focalY: c.py
                GradientStop { position: 0;   color: "transparent" }
                GradientStop { position: .38; color: "transparent" }
                GradientStop { position: .55; color: Qt.alpha(Paleta.fondo, .48) }
                GradientStop { position: 1;   color: Qt.alpha(Paleta.fondo, .62) }
            }
            startX: 0; startY: 0
            PathLine { x: c.width; y: 0 }
            PathLine { x: c.width; y: c.height }
            PathLine { x: 0; y: c.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // dos anillos que se cierran hacia el puntero, uno tras otro
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real k: Math.max(0, Math.min(1, (c.t - index * .14) / .55))   // 0 → 1 su recorrido
            readonly property real r: 14 + 150 * Math.pow(1 - k, 2)
            x: c.px - r; y: c.py - r
            width: r * 2; height: width; radius: width / 2
            color: "transparent"
            border { width: 3 - index; color: index === 0 ? Paleta.acento : Paleta.acento2 }
            opacity: c.velo * (k > 0 && k < 1 ? Math.min(1, k * 4) * (1 - k * .6) : 0)
        }
    }
    // al final, un punto que late justo encima del puntero
    Rectangle {
        readonly property real k: Math.max(0, (c.t - .55) / .45)
        width: 26 + 18 * Math.sin(k * Math.PI); height: width; radius: width / 2
        x: c.px - width / 2; y: c.py - height / 2
        color: "transparent"
        border { width: 2; color: Paleta.acento }
        opacity: c.velo * (k > 0 ? .8 : 0)
    }
}
