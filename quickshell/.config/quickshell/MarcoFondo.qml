// Redondea el fondo con el recorte de Quickshell y conserva la imagen con renderizado por software.
import QtQuick
import Quickshell.Widgets

Item {
    id: marco
    default property alias contenido: imagen.data
    property real radio: EstiloPanel.rControl

    Loader {
        id: recorte
        anchors.fill: parent
        active: GraphicsInfo.api !== GraphicsInfo.Software
        sourceComponent: ClippingRectangle { radius: marco.radio; color: "transparent" }
    }
    Item {
        id: imagen
        parent: recorte.item?.contentItem ?? marco
        anchors.fill: parent
        clip: !recorte.active
    }
}
