pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: nav
    property var opciones: []
    property int actual: 0
    property bool vertical: false
    property color tinte: Paleta.naranja
    signal elegir(int indice)
    readonly property real paso: vertical ? 50 : (width - 10) / Math.max(1, opciones.length)
    Layout.fillWidth: true
    implicitHeight: vertical ? opciones.length * 50 + 10 : 48
    radius: 15
    // carril hundido
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, .45) }
        GradientStop { position: 1; color: Qt.alpha(Paleta.texto, .03) }
    }
    border { width: 1; color: Qt.alpha(Paleta.texto, .07) }

    // Píldora que se desliza hasta la opción elegida
    Item {
        id: pildora
        x: nav.vertical ? 5 : 5 + nav.actual * nav.paso
        y: nav.vertical ? 5 + nav.actual * 50 : 5
        width: nav.vertical ? nav.width - 10 : nav.paso
        height: nav.vertical ? 48 : nav.height - 10
        Behavior on x { NumberAnimation { duration: EstiloPanel.entrada + 40; easing.type: Easing.OutBack; easing.overshoot: .8 } }
        Behavior on y { NumberAnimation { duration: EstiloPanel.entrada + 40; easing.type: Easing.OutBack; easing.overshoot: .8 } }
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.efectos
            radius: 11
            offset.y: 4; blur: 16; spread: -6
            color: Qt.alpha(nav.tinte, .38)
        }
        Rectangle {
            anchors.fill: parent
            radius: 11
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(Qt.lighter(nav.tinte, 1.1), .40)) }
                GradientStop { position: 1; color: Qt.tint(Paleta.fondo, Qt.alpha(nav.tinte, .20)) }
            }
            border { width: 1; color: Qt.alpha(nav.tinte, .55) }
        }
        Rectangle {
            x: 8; y: 1; width: parent.width - 16; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: .5; color: Qt.alpha("white", .35) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Repeater {
        model: nav.opciones
        BotonPanel {
            required property var modelData
            required property int index
            x: nav.vertical ? 5 : 5 + index * nav.paso
            y: nav.vertical ? 5 + index * 50 : 5
            width: nav.vertical ? nav.width - 10 : nav.paso
            height: nav.vertical ? 48 : nav.height - 10
            text: modelData.texto
            simbolo: modelData.icono || ""
            tinte: nav.tinte
            destacado: nav.actual === index
            background: Rectangle { radius: 11; color: parent.hovered && !parent.destacado ? Qt.alpha(Paleta.texto, .05) : "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: nav.tinte }
            onClicked: nav.elegir(index)
        }
    }
}
