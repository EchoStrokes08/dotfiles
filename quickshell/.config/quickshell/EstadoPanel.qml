import QtQuick
import QtQuick.Layouts

Rectangle {
    id: estado
    property string mensaje: ""
    property string error: ""
    property bool ocupado: false
    readonly property color tinte: error ? Paleta.peligro : ocupado ? Paleta.acento2 : Paleta.exito
    Layout.fillWidth: true
    implicitHeight: 44
    radius: 16
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Qt.alpha(estado.tinte, .13) }
        GradientStop { position: .45; color: Qt.alpha(estado.tinte, .04) }
        GradientStop { position: 1; color: EstiloPanel.relleno }
    }
    border { width: 1; color: Qt.alpha(estado.tinte, .20) }
    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 12 }
        spacing: 12
        // Punto con halo: late mientras trabaja
        Item {
            implicitWidth: 26; implicitHeight: 26
            Rectangle {
                id: halo
                anchors.centerIn: parent
                width: 26; height: 26; radius: height / 2
                color: Qt.alpha(estado.tinte, .16)
                SequentialAnimation on scale {
                    running: estado.ocupado && EstiloPanel.movimiento
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { from: .7; to: 1.1; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.1; to: .7; duration: 650; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.centerIn: parent
                text: estado.error ? "󰀦" : estado.ocupado ? "󰔟" : "󰄬"
                color: estado.tinte
                font { family: Paleta.fuente; pixelSize: 14 }
            }
        }
        Text { Layout.fillWidth: true; text: estado.error || estado.mensaje; color: estado.error ? Paleta.peligro : Qt.tint(EstiloPanel.tenue, EstiloPanel.velo); elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; font { family: EstiloPanel.fuente; pixelSize: 12; weight: Font.Medium } }
    }
}
