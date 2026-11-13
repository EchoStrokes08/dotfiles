import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

RowLayout {
    id: cabecera
    property string seccion: ""
    property string titulo: ""
    property string simbolo: ""
    property color tinte: Paleta.acento
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
            radius: 16
            offset.y: 6; blur: 24; spread: -6
            color: Qt.alpha(cabecera.tinte, .45)
        }
        Rectangle {
            anchors.fill: parent
            radius: 16
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
            font { family: Paleta.fuente; pixelSize: 26 }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            spacing: 8
            Rectangle { width: 6; height: 6; radius: height / 2; color: cabecera.tinte }
            Text { Layout.fillWidth: true; text: cabecera.seccion.toUpperCase(); elide: Text.ElideRight; color: cabecera.tinte; font { family: EstiloPanel.fuente; pixelSize: 11; weight: Font.Bold; letterSpacing: 1.4 } }
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
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
        background: Rectangle {
            radius: width / 2
            color: cerrar.hovered ? Qt.alpha(Paleta.peligro, .20) : EstiloPanel.rellenoActivo
            border { width: cerrar.activeFocus ? 2 : 1; color: cerrar.activeFocus ? cabecera.tinte : cerrar.hovered ? Qt.alpha(Paleta.peligro, .55) : EstiloPanel.borde }
            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        }
        contentItem: Text {
            text: "󰅖"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: cerrar.hovered ? Paleta.peligro : EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 16 }
        }
        onClicked: cabecera.cerrar()
    }
}
