import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TextField {
    id: campo
    Layout.fillWidth: true
    implicitHeight: 38
    leftPadding: 12
    rightPadding: 12
    Accessible.name: placeholderText
    color: Paleta.texto
    placeholderTextColor: EstiloPanel.tenue
    selectionColor: Qt.alpha(Paleta.naranja, .35)
    selectedTextColor: Paleta.texto
    font { family: EstiloPanel.fuente; pixelSize: 13 }
    background: Rectangle {
        radius: 10
        color: campo.activeFocus ? EstiloPanel.elevada : EstiloPanel.superficie
        border.width: campo.activeFocus ? 2 : 1
        border.color: campo.activeFocus ? Qt.alpha(Paleta.naranja, .8) : EstiloPanel.borde
        Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
    }
}
