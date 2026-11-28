// EsquinasPantalla: la pantalla con las esquinas redondeadas, como un móvil o un Mac.
// Cuatro cuartos de círculo negros en las esquinas (radio EstiloPanel.rTarjeta, el mismo marco que
// recorre CapaEnergia.qml). Se apartan con una ventana a pantalla completa en esta pantalla (juegos, vídeo).
// Los clics atraviesan la capa. Una por pantalla (shell.qml). Interruptor: PreferenciasUI.esquinas.
// Esquina activa: llevar el puntero a la esquina de arriba a la izquierda abre la vista general (como
// en macOS); la esquina se ilumina al llegar. Para repetir hay que salir de ella. PreferenciasUI.esquinaActiva.
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
    contentItem.visible: (PreferenciasUI.esquinas || PreferenciasUI.esquinaActiva) && !completa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-esquinas"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: PreferenciasUI.esquinaActiva && e.contentItem.visible ? zona : nada }
    Item { id: nada; width: 0; height: 0 }

    // ── Esquina activa ──
    Item {
        id: zona
        width: 3; height: 3
        HoverHandler {
            id: llegar
            onHoveredChanged: if (hovered) espera.restart(); else espera.stop()
        }
    }
    Timer {
        id: espera
        interval: 90                      // un instante: que no salte al pasar de largo
        onTriggered: {
            Quickshell.execDetached(["qs", "ipc", "call", "vista", "toggle"]);
            if (EstiloPanel.movimiento) onda.restart();
        }
    }
    // la esquina se ilumina: un cuarto de círculo del acento que crece y se apaga
    Rectangle {
        id: luz
        property real k: 0
        width: 2 * (24 + 90 * k); height: width; radius: width / 2
        x: -width / 2; y: -height / 2
        color: "transparent"
        border { width: 2; color: Paleta.acento }
        opacity: (1 - k) * .9
        visible: k > 0 && k < 1
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * .6; height: width; radius: width / 2
            color: Qt.alpha(Paleta.acento, .35 * (1 - luz.k))
        }
    }
    NumberAnimation { id: onda; target: luz; property: "k"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }

    Repeater {
        model: 4
        Shape {
            required property int index
            visible: PreferenciasUI.esquinas
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
