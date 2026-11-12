// Superpuesta: el esqueleto común de las ventanas flotantes (wallpapers, portapapeles, menús):
// velo oscuro, tarjeta de cristal con animación de entrada, Esc o clic fuera para cerrar.
//   Superpuesta { espacio: "wallpapers"; anchoTarjeta: 900
//       ColumnLayout { … lo que va dentro … } }
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: v
    property bool panelCuidado: false
    property color acentoPanel: Paleta.naranja
    property real margenPanel: panelCuidado ? 22 : 14
    property bool abierto: false
    property bool mostrar: false
    property string espacio: "superpuesta"     // namespace: quickshell-<espacio> (para el blur)
    property real opacidadTarjeta: 0.90
    property real anchoTarjeta: 560
    property real alturaRelativa: 0.14         // dónde empieza la tarjeta (fracción del alto)
    default property alias contenido: caja.data
    readonly property real altoPanel: tarjeta.height
    readonly property real posicionPanel: tarjeta.y
    signal abriendose()

    onAbiertoChanged: {
        if (abierto) { cierre.stop(); mostrar = true; abriendose(); }
        else cierre.restart();
    }
    Timer { id: cierre; interval: EstiloPanel.entrada; onTriggered: v.mostrar = false }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-" + espacio
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: v.abierto ? (v.panelCuidado ? 0.48 : 0.25) : 0
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada } }
        MouseArea { anchors.fill: parent; onClicked: v.abierto = false }
    }

    Rectangle {
        id: tarjeta
        width: v.anchoTarjeta
        height: Math.min(caja.childrenRect.height + v.margenPanel * 2, v.height - 32)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(12, Math.min(parent.height * v.alturaRelativa, parent.height - height - 16)) + (v.abierto ? 0 : 10)
        opacity: v.abierto ? 1 : 0
        scale: v.abierto ? 1 : 0.98
        Behavior on y       { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada } }
        Behavior on scale   { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
        radius: v.panelCuidado ? 22 : 16
        color: Qt.alpha(Paleta.fondo, v.opacidadTarjeta)
        gradient: v.panelCuidado ? fondoPanel : null
        Gradient {
            id: fondoPanel
            GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(v.acentoPanel, .055)) }
            GradientStop { position: .48; color: Paleta.fondo }
            GradientStop { position: 1; color: EstiloPanel.superficie }
        }
        border { width: 1; color: v.panelCuidado ? Qt.alpha(v.acentoPanel, .25) : Qt.alpha(Paleta.naranja, .35) }
        MouseArea { anchors.fill: parent }

        Flickable {
            id: desplazamiento
            anchors { fill: parent; margins: v.margenPanel }
            contentWidth: width
            contentHeight: caja.childrenRect.height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            FocusScope {
                id: caja
                width: desplazamiento.width
                height: childrenRect.height
                focus: true
                Keys.onEscapePressed: v.abierto = false
                // Mantiene visible el control al navegar con Tab en pantallas bajas.
                Connections {
                    target: caja.Window.window
                    function onActiveFocusItemChanged() {
                        const item = caja.Window.window?.activeFocusItem;
                        if (!item || !desplazamiento.interactive) return;
                        const pos = item.mapToItem(caja, 0, 0);
                        if (pos.y < desplazamiento.contentY) desplazamiento.contentY = Math.max(0, pos.y - 8);
                        else if (pos.y + item.height > desplazamiento.contentY + desplazamiento.height)
                            desplazamiento.contentY = Math.min(desplazamiento.contentHeight - desplazamiento.height, pos.y + item.height - desplazamiento.height + 8);
                    }
                }
            }
        }
    }
}
