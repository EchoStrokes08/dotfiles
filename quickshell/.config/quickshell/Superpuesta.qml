// Superpuesta: el esqueleto común de las ventanas flotantes (wallpapers, portapapeles, menús):
// velo oscuro, tarjeta de cristal con animación de entrada, Esc o clic fuera para cerrar.
//   Superpuesta { espacio: "wallpapers"; anchoTarjeta: 900
//       ColumnLayout { … lo que va dentro … } }
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: v
    property bool abierto: false
    property bool mostrar: false
    property string espacio: "superpuesta"     // namespace: quickshell-<espacio> (para el blur)
    property real opacidadTarjeta: 0.90
    property real anchoTarjeta: 560
    property real alturaRelativa: 0.14         // dónde empieza la tarjeta (fracción del alto)
    default property alias contenido: caja.data
    signal abriendose()

    onAbiertoChanged: {
        if (abierto) { cierre.stop(); mostrar = true; abriendose(); }
        else cierre.restart();
    }
    Timer { id: cierre; interval: 220; onTriggered: v.mostrar = false }

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
        opacity: v.abierto ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: v.abierto = false }
    }

    Rectangle {
        id: tarjeta
        width: v.anchoTarjeta
        height: caja.childrenRect.height + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * v.alturaRelativa + (v.abierto ? 0 : -12)
        opacity: v.abierto ? 1 : 0
        scale: v.abierto ? 1 : 0.98
        Behavior on y       { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        radius: 16
        color: Qt.alpha(Paleta.fondo, v.opacidadTarjeta)
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }
        MouseArea { anchors.fill: parent }

        FocusScope {
            id: caja
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            height: childrenRect.height
            focus: true
            Keys.onEscapePressed: v.abierto = false
        }
    }
}
