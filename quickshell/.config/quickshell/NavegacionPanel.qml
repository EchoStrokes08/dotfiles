pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: nav
    property var opciones: []
    property int actual: 0
    property bool vertical: false
    property color tinte: Paleta.acento
    signal elegir(int indice)
    Accessible.role: Accessible.PageTabList
    Accessible.name: "Secciones"
    Accessible.description: (opciones[actual]?.texto ?? "") + " seleccionada"
    readonly property real paso: vertical ? 50 : (width - 10) / Math.max(1, opciones.length)
    Layout.fillWidth: true
    implicitHeight: vertical ? opciones.length * 50 + 10 : 48
    radius: 16
    // carril hundido
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, .45) }
        GradientStop { position: 1; color: EstiloPanel.relleno }
    }
    border { width: 1; color: EstiloPanel.borde }

    // Píldora que se desliza hasta la opción elegida
    Item {
        id: pildora
        x: nav.vertical ? 5 : 5 + nav.actual * nav.paso
        y: nav.vertical ? 5 + nav.actual * 50 : 5
        width: nav.vertical ? nav.width - 10 : nav.paso
        height: nav.vertical ? 48 : nav.height - 10
        Behavior on x { NumberAnimation { duration: EstiloPanel.normal + 40; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: EstiloPanel.normal + 40; easing.type: Easing.OutCubic } }
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.efectos
            radius: 12
            offset.y: 4; blur: 16; spread: -6
            color: Qt.alpha("black", .28)
        }
        FondoSeleccion { anchors.fill: parent; tinte: nav.tinte }
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
            background: Rectangle { radius: 12; color: parent.hovered && !parent.destacado ? EstiloPanel.relleno : "transparent"; border.width: parent.activeFocus ? 2 : 0; border.color: nav.tinte }
            onClicked: nav.elegir(index)
        }
    }
}
