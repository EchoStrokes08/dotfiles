// Tecla: una tecla con relieve, para mostrar atajos.
//   Tecla { texto: "Esc" }        Tecla { texto: "SUPER+Q"; tinte: Paleta.aviso; anchoMax: 120 }
// Como una tecla física: canto inferior oscuro (4 px), cara con luz desde arriba, brillo en el
// borde superior y una sombra corta. El tinte colorea la letra y, muy levemente, la cara.
import QtQuick
import QtQuick.Effects

Item {
    id: t
    property string texto: ""
    property color tinte: Paleta.texto
    property int tam: 10
    property real anchoMax: 0          // > 0: el texto se parte en varias líneas a partir de ese ancho
    readonly property color cara: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .13))
    implicitWidth: Math.max(etiqueta.width + 14, implicitHeight)
    implicitHeight: etiqueta.height + 10

    RectangularShadow {
        anchors.fill: parent
        visible: EstiloPanel.profundidad
        radius: EstiloPanel.rChip; offset.y: 2; blur: 6; spread: -1
        color: Qt.alpha("black", .45)
    }
    Rectangle {   // canto: la parte de la tecla que se ve por debajo
        anchors.fill: parent
        radius: EstiloPanel.rChip
        color: Qt.darker(t.cara, 1.55)
        border { width: 1; color: Qt.alpha("black", .35) }
    }
    Rectangle {   // cara
        anchors { fill: parent; bottomMargin: 4 }
        radius: EstiloPanel.rChip
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(Qt.lighter(t.cara, 1.18), Qt.alpha(t.tinte, .05)) }
            GradientStop { position: 1; color: Qt.tint(t.cara, Qt.alpha(t.tinte, .03)) }
        }
        border { width: 1; color: Qt.alpha(Paleta.texto, .16) }
        Rectangle {   // brillo del borde superior
            x: parent.radius * .6; y: 1
            width: parent.width - parent.radius * 1.2; height: 1
            color: Qt.alpha("white", .22)
        }
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
