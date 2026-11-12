import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

TextField {
    id: campo
    property color tinte: Paleta.naranja
    Layout.fillWidth: true
    implicitHeight: 40
    leftPadding: 14
    rightPadding: 14
    Accessible.name: placeholderText
    color: Paleta.texto
    placeholderTextColor: EstiloPanel.tenue
    selectionColor: Qt.alpha(tinte, .35)
    selectedTextColor: Paleta.texto
    font { family: EstiloPanel.fuente; pixelSize: 13 }
    background: Item {
        // anillo de foco que "brilla" alrededor del campo
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.efectos
            opacity: campo.activeFocus ? 1 : 0
            radius: 12
            blur: 16; spread: -3
            color: Qt.alpha(campo.tinte, .35)
            Behavior on opacity { NumberAnimation { duration: EstiloPanel.breve } }
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            // hundido: más oscuro arriba, como un hueco en el cristal
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, campo.activeFocus ? .55 : .42) }
                GradientStop { position: 1; color: Qt.alpha(Paleta.texto, campo.activeFocus ? .06 : .035) }
            }
            border.width: campo.activeFocus ? 1.5 : 1
            border.color: campo.activeFocus ? Qt.alpha(campo.tinte, .85) : campo.hovered ? Qt.alpha(Paleta.texto, .18) : EstiloPanel.borde
            Behavior on border.color { ColorAnimation { duration: EstiloPanel.breve } }
        }
    }
}
