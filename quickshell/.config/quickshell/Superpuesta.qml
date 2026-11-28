// Superpuesta: el esqueleto común de las ventanas flotantes (wallpapers, portapapeles, menús):
// velo oscuro, tarjeta de cristal con animación de entrada, Esc o clic fuera para cerrar.
//   Superpuesta { espacio: "wallpapers"; anchoTarjeta: 900
//       ColumnLayout { … lo que va dentro … } }
import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: v
    property bool panelCuidado: false
    property color acentoPanel: Paleta.acento
    property real margenPanel: panelCuidado ? 24 : 18
    property bool abierto: false
    property bool mostrar: false
    property string espacio: "superpuesta"     // namespace: quickshell-<espacio> (para el blur)
    property real opacidadTarjeta: EstiloPanel.opacidadPanel   // un panel puede pedir más (1 = opaco), nunca menos
    property real anchoTarjeta: 560
    property real alturaRelativa: 0.14         // dónde empieza la tarjeta (fracción del alto)
    default property alias contenido: caja.data
    property alias encima: capaEncima.data      // capa a pantalla completa por encima de la tarjeta (ZoomVista)
    readonly property real altoPanel: tarjeta.height
    readonly property real posicionPanel: tarjeta.y
    signal abriendose()

    Connections {
        target: EstadoEscritorio
        function onCapturaPrivadaChanged() { if (EstadoEscritorio.capturaPrivada) v.abierto=false; }
    }

    // Si se abrió desde algo de la barra (Origen.qml), la tarjeta nace de ese punto y vuelve a él al cerrarse
    property var nace: null
    onAbiertoChanged: {
        if (abierto) {
            cierre.stop(); encoger.stop();
            nace = EstiloPanel.movimiento ? Origen.tomar(screen?.name ?? "") : null;
            mostrar = true; abriendose();
            if (nace) crecer.restart(); else { crecer.stop(); escalaNacer.xScale = 1; escalaNacer.yScale = 1; }
        } else {
            if (nace && EstiloPanel.movimiento) encoger.restart();
            cierre.restart();
        }
    }
    Timer {
        id: cierre; interval: EstiloPanel.normal
        onTriggered: { v.mostrar = false; v.nace = null; escalaNacer.xScale = 1; escalaNacer.yScale = 1; }
    }

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
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
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
        transform: Scale {
            id: escalaNacer
            origin.x: v.nace ? v.nace.x - tarjeta.x : tarjeta.width / 2
            origin.y: v.nace ? v.nace.y - tarjeta.y : 0
        }
        NumberAnimation {
            id: crecer
            target: escalaNacer; properties: "xScale,yScale"; from: .06; to: 1
            duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: .9
        }
        NumberAnimation {
            id: encoger
            target: escalaNacer; properties: "xScale,yScale"; to: .06
            duration: EstiloPanel.normal; easing.type: Easing.InCubic
        }
        Behavior on y       { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
        Behavior on scale   { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        color: "transparent"
        FondoPanel {
            anchors.fill: parent
            acento: v.acentoPanel
            radio: EstiloPanel.rPanel
            opacidad: Math.max(v.opacidadTarjeta, EstiloPanel.opacidadPanel)
        }
        MouseArea { anchors.fill: parent }

        // Destello al abrir: una luz recorre una vez el filo superior de la tarjeta, como un reflejo en el cristal
        Item {
            id: destello
            property real avance: 0
            visible: EstiloPanel.profundidad && barrido.running
            x: EstiloPanel.rPanel * .8
            y: 1
            width: Math.max(0, tarjeta.width - 2 * x)
            height: 3
            clip: true

            Rectangle {
                width: Math.min(150, destello.width * .38)
                height: 2
                x: (destello.width + width) * destello.avance - width
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: .5; color: Qt.alpha(Qt.lighter(v.acentoPanel, 1.35), .85) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            SequentialAnimation {
                id: barrido
                PropertyAction { target: destello; property: "avance"; value: 0 }
                PauseAnimation { duration: 90 }
                NumberAnimation { target: destello; property: "avance"; to: 1; duration: 760 }
            }
        }
        Connections {
            target: v
            function onAbriendose() { if (EstiloPanel.movimiento && EstiloPanel.profundidad) barrido.restart(); }
        }

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

    Item { id: capaEncima; anchors.fill: parent; z: 50 }
}
