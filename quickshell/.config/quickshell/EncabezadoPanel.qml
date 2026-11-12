import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

RowLayout {
    id: cabecera
    property string seccion: ""
    property string titulo: ""
    property string simbolo: ""
    property color tinte: Paleta.naranja
    signal cerrar()
    Layout.fillWidth: true
    implicitHeight: 64
    spacing: 16

    // Medalla del panel: degradado del tinte, filo de luz y resplandor
    Item {
        implicitWidth: 52; implicitHeight: 52
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.efectos
            radius: 17
            offset.y: 6; blur: 24; spread: -6
            color: Qt.alpha(cabecera.tinte, .45)
        }
        Rectangle {
            anchors.fill: parent
            radius: 17
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Qt.alpha(Qt.lighter(cabecera.tinte, 1.15), .42) }
                GradientStop { position: 1; color: Qt.alpha(cabecera.tinte, .14) }
            }
            border { width: 1; color: Qt.alpha(cabecera.tinte, .55) }
        }
        Rectangle {   // brillo de la esquina
            x: 6; y: 3; width: parent.width - 12; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: .5; color: Qt.alpha("white", .45) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Text {
            anchors.centerIn: parent
            text: cabecera.simbolo
            color: Qt.lighter(cabecera.tinte, 1.25)
            font { family: Paleta.fuente; pixelSize: 25 }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            spacing: 7
            Rectangle { width: 6; height: 6; radius: 3; color: cabecera.tinte }
            Text { Layout.fillWidth: true; text: cabecera.seccion.toUpperCase(); elide: Text.ElideRight; color: cabecera.tinte; font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 2.2 } }
        }
        Text {
            Layout.fillWidth: true
            text: cabecera.titulo
            elide: Text.ElideRight
            color: Paleta.texto
            font { family: EstiloPanel.fuente; pixelSize: 26; weight: Font.DemiBold; letterSpacing: -.3 }
        }
    }
    // Cerrar: botón redondo con la tecla debajo
    Button {
        id: cerrar
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 38; implicitHeight: 38
        hoverEnabled: true
        Accessible.name: "Cerrar panel"
        ToolTip.visible: hovered
        ToolTip.text: "Cerrar · Esc"
        ToolTip.delay: 500
        scale: down ? .92 : 1
        Behavior on scale { NumberAnimation { duration: EstiloPanel.breve } }
        background: Rectangle {
            radius: width / 2
            color: cerrar.hovered ? Qt.alpha(Paleta.rojo, .20) : Qt.alpha(Paleta.texto, .06)
            border { width: cerrar.activeFocus ? 2 : 1; color: cerrar.activeFocus ? cabecera.tinte : cerrar.hovered ? Qt.alpha(Paleta.rojo, .55) : Qt.alpha(Paleta.texto, .10) }
            Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
        }
        contentItem: Text {
            text: "󰅖"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: cerrar.hovered ? Paleta.rojo : EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 17 }
        }
        onClicked: cabecera.cerrar()
    }
}
