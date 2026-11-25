// IslaBoton: botón redondo del minirreproductor de la isla (anterior · reproducir · siguiente).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: bm
    property string glifo: ""
    property bool principal: false
    signal pulsado()
    implicitWidth: principal ? 36 : 32; implicitHeight: implicitWidth
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: bm.principal ? (zonaBm.containsMouse ? Qt.lighter(Paleta.acento, 1.1) : Paleta.acento)
             : zonaBm.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
        border { width: bm.principal ? 0 : 1; color: EstiloPanel.borde }
        scale: zonaBm.pressed ? .9 : 1
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    Glifo {
        anchors.centerIn: parent
        alto: bm.height
        text: bm.glifo
        color: bm.principal ? Paleta.sobreAcento : Paleta.texto
        font { family: Paleta.mono; pixelSize: 16 }
    }
    MouseArea {
        id: zonaBm
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bm.pulsado()
    }
}
