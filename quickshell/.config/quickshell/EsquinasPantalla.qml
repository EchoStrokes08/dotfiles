// EsquinasPantalla: la pantalla con las esquinas redondeadas, como un móvil o un Mac.
// Cuatro cuartos de círculo negros en las esquinas (radio EstiloPanel.rTarjeta, el mismo marco que
// recorre CapaEnergia.qml). Se apartan con una ventana a pantalla completa en esta pantalla (juegos, vídeo).
// Los clics atraviesan la capa. Una por pantalla (shell.qml). Interruptor: PreferenciasUI.esquinas.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: e
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool completa: (monitor?.activeWorkspace?.toplevels.values ?? []).some(t => t.lastIpcObject?.fullscreen > 0)
    readonly property real r: EstiloPanel.rTarjeta
    // Siempre mapeada (ver Barra.qml): se apaga solo el contenido
    contentItem.visible: PreferenciasUI.esquinas && !completa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-esquinas"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Repeater {
        model: 4
        Shape {
            required property int index
            width: e.r; height: e.r
            x: index % 2 === 0 ? 0 : e.width - e.r
            y: index < 2 ? 0 : e.height - e.r
            rotation: [0, 90, 270, 180][index]
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillColor: "black"
                startX: 0; startY: 0
                PathLine { x: e.r; y: 0 }
                PathArc { x: 0; y: e.r; radiusX: e.r; radiusY: e.r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
