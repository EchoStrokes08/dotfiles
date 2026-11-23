// FondoSeleccion: el fondo de cualquier elemento elegido (pestaña activa, fila actual, botón destacado).
// Superficie neutra y borde del acento. Con profundidad, la selección se ilumina:
//   · halo exterior del acento (luz, no relleno: un tinte fuerte sobre fondo oscuro se vuelve marrón
//     con acentos cálidos, ORION 5.3, docs/diseno.md)
//   · velo de luz desde el borde izquierdo, muy tenue, que acompaña a la marca
//   · marca lateral que brilla
import QtQuick
import QtQuick.Effects

Rectangle {
    id: s
    property bool encima: false
    property bool marca: false        // barra de 3 px a la izquierda (filas de lista)
    property color tinte: Paleta.acento
    radius: EstiloPanel.rControl
    color: encima ? EstiloPanel.seleccionadoEncima : EstiloPanel.seleccionado
    border { width: 1; color: Qt.alpha(s.tinte, .8) }
    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }

    RectangularShadow {
        anchors.fill: parent
        z: -1
        visible: EstiloPanel.profundidad
        radius: s.radius
        blur: 22
        spread: -4
        color: Qt.alpha(s.tinte, s.encima ? .30 : .22)
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    Rectangle {   // velo de luz desde la izquierda
        visible: EstiloPanel.profundidad && s.marca
        anchors { fill: parent; margins: 1 }
        radius: s.radius - 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;   color: Qt.alpha(Qt.lighter(s.tinte, 1.25), .10) }
            GradientStop { position: .45; color: "transparent" }
        }
    }
    Rectangle {   // filo de luz superior, como en los botones
        visible: EstiloPanel.profundidad
        x: s.radius * .7; y: 1
        width: s.width - s.radius * 1.4; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;  color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(Qt.lighter(s.tinte, 1.3), .45) }
            GradientStop { position: 1;  color: "transparent" }
        }
    }
    Item {
        visible: s.marca
        width: 3; height: parent.height - 20
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.profundidad
            radius: width / 2; blur: 8; spread: 0
            color: Qt.alpha(s.tinte, .8)
        }
        Rectangle { anchors.fill: parent; radius: EstiloPanel.rPunto; color: Qt.lighter(s.tinte, 1.08) }
    }
}
