// Tecla: una tecla con relieve (cara clara y canto inferior más grueso), para mostrar atajos.
//   Tecla { texto: "Esc" }        Tecla { texto: "SUPER+Q"; tinte: Paleta.amarillo; anchoMax: 120 }
import QtQuick

Item {
    id: t
    property string texto: ""
    property color tinte: Paleta.texto
    property int tam: 10
    property real anchoMax: 0          // > 0: el texto se parte en varias líneas a partir de ese ancho
    implicitWidth: etiqueta.width + 14
    implicitHeight: etiqueta.height + 9

    Rectangle { anchors.fill: parent; radius: 6; color: Qt.alpha(Paleta.texto, .06) }   // canto
    Rectangle {
        anchors { fill: parent; bottomMargin: 2 }
        radius: 6
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Paleta.texto, .13) }
            GradientStop { position: 1; color: Qt.alpha(Paleta.texto, .07) }
        }
        border { width: 1; color: Qt.alpha(Paleta.texto, .12) }
        Text {
            id: etiqueta
            anchors.centerIn: parent
            width: t.anchoMax > 0 ? Math.min(implicitWidth, t.anchoMax) : implicitWidth
            text: t.texto
            wrapMode: t.anchoMax > 0 ? Text.WordWrap : Text.NoWrap
            horizontalAlignment: Text.AlignHCenter
            color: t.tinte
            font { family: Paleta.mono; pixelSize: t.tam; weight: Font.DemiBold }
        }
    }
}
