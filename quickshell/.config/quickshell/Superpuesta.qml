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
    property real margenPanel: panelCuidado ? 24 : 18
    property bool abierto: false
    property bool mostrar: false
    property string espacio: "superpuesta"     // namespace: quickshell-<espacio> (para el blur)
    property real opacidadTarjeta: 0.92      // el blur de Hyprland es suave: por debajo de ~0.9 se lee el texto de detrás
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

    // Cerrar y DESPUÉS actuar. Mientras el panel está abierto tiene el teclado en exclusiva:
    // si se enfoca otra ventana en ese momento, Hyprland cambia de espacio pero, al soltar el
    // panel el teclado, devuelve el foco a la ventana anterior y deshace el salto.
    property var accionPendiente: null
    function cerrarY(accion) {
        accionPendiente = accion;
        abierto = false;
        soltarTeclado.restart();
    }
    Timer {
        id: soltarTeclado
        interval: 70
        onTriggered: { const f = v.accionPendiente; v.accionPendiente = null; if (f) f(); }
    }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-" + espacio
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        // < 0.3 de opacidad: así el blur de Hyprland (ignore_alpha 0.3) solo actúa bajo la tarjeta
        color: "black"
        opacity: v.abierto ? 0.28 : 0
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada } }
        MouseArea { anchors.fill: parent; onClicked: v.abierto = false }
    }

    Rectangle {
        id: tarjeta
        width: v.anchoTarjeta
        height: Math.min(caja.childrenRect.height + v.margenPanel * 2, v.height - 32)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(12, Math.min(parent.height * v.alturaRelativa, parent.height - height - 16)) + (v.abierto ? 0 : 14)
        opacity: v.abierto ? 1 : 0
        scale: v.abierto ? 1 : 0.965
        Behavior on y       { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada } }
        Behavior on scale   { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
        color: "transparent"
        FondoPanel {
            anchors.fill: parent
            acento: v.acentoPanel
            radio: v.panelCuidado ? 24 : 20
            opacidad: Math.min(v.opacidadTarjeta, .95)
        }
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
