pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: nav
    property var opciones: []
    property int actual: 0
    property bool vertical: false
    property color tinte: Paleta.naranja
    signal elegir(int indice)
    Layout.fillWidth: true
    implicitHeight: vertical ? opciones.length * 50 + 8 : 46
    radius: 12
    color: Qt.alpha(Paleta.texto, .025)
    border { width: 1; color: Qt.alpha(Paleta.texto, .05) }
    Rectangle {
        x: nav.vertical ? 4 : 4 + nav.actual * ((nav.width - 8) / Math.max(1, nav.opciones.length))
        y: nav.vertical ? 4 + nav.actual * 50 : 4
        width: nav.vertical ? nav.width - 8 : (nav.width - 8) / Math.max(1, nav.opciones.length)
        height: nav.vertical ? 48 : nav.height - 8
        radius: 9
        color: Qt.alpha(nav.tinte, .14)
        border { width: 1; color: Qt.alpha(nav.tinte, .24) }
        Behavior on x { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: EstiloPanel.entrada; easing.type: Easing.OutCubic } }
    }
    Repeater {
        model: nav.opciones
        BotonPanel {
            required property var modelData
            required property int index
            x: nav.vertical ? 4 : 4 + index * ((nav.width - 8) / Math.max(1, nav.opciones.length))
            y: nav.vertical ? 4 + index * 50 : 4
            width: nav.vertical ? nav.width - 8 : (nav.width - 8) / Math.max(1, nav.opciones.length)
            height: nav.vertical ? 48 : nav.height - 8
            text: modelData.texto
            simbolo: modelData.icono || ""
            tinte: nav.tinte
            destacado: nav.actual === index
            background: Rectangle { radius: 9; color: parent.hovered ? Qt.alpha(Paleta.texto, .045) : "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: nav.tinte }
            onClicked: nav.elegir(index)
        }
    }
}
