// FlechaMes: botón redondo de ‹ › para cambiar de mes en el calendario; se ilumina al pasar el ratón.
import QtQuick

Rectangle {
    id: fl
    property string glifo: ""
    signal pulsada()
    implicitWidth: 24; implicitHeight: 24; radius: height / 2
    color: zonaFl.containsMouse ? EstiloPanel.rellenoActivo : "transparent"
    border { width: 1; color: zonaFl.containsMouse ? EstiloPanel.bordeFuerte : "transparent" }
    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    Accessible.role: Accessible.Button
    Text {
        anchors.centerIn: parent
        text: fl.glifo; color: zonaFl.containsMouse ? Paleta.texto : Paleta.gris
        font { family: Paleta.mono; pixelSize: 12 }
    }
    MouseArea { id: zonaFl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fl.pulsada() }
}
