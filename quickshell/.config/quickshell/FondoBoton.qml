// FondoBoton: el fondo común de los botones de los paneles (BotonPanel y los «Boton» de Brújula,
// Móvil y Agente). Degradado suave, filo de luz arriba y, si está destacado, un resplandor del tinte.
//   background: FondoBoton { tinte: …; destacado: …; encima: control.hovered; foco: control.activeFocus }
import QtQuick
import QtQuick.Effects

Item {
    id: f
    property color tinte: Paleta.acento
    property bool destacado: false
    property bool encima: false
    property bool pulsado: false
    property bool foco: false
    property real radio: 12

    implicitWidth: 80
    implicitHeight: 38

    RectangularShadow {
        anchors.fill: parent
        visible: EstiloPanel.efectos && f.destacado
        radius: f.radio
        offset.y: 5
        blur: 20
        spread: -7
        color: Qt.alpha(f.tinte, f.encima ? .55 : .34)
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    Rectangle {
        anchors.fill: parent
        radius: f.radio
        color: f.destacado ? Qt.tint(Paleta.fondo,Qt.alpha(f.tinte,f.pulsado ? .24 : f.encima ? .22 : .16))
            : f.encima ? EstiloPanel.rellenoActivo : EstiloPanel.superficie
        border.width: f.foco ? 2 : 1
        border.color: f.foco ? f.tinte
            : f.destacado ? Qt.alpha(f.tinte, f.encima ? .75 : .55)
            : Qt.alpha(f.encima ? f.tinte : Paleta.texto, f.encima ? .38 : .085)
        Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    // Un filo solo en cristal; las superficies sólidas ya tienen jerarquía tonal.
    Rectangle {
        visible: EstiloPanel.efectos
        x: f.radio * .7; y: 1
        width: parent.width - f.radio * 1.4; height: 1
        opacity: f.destacado ? .9 : f.encima ? .7 : .45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;  color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(f.destacado ? Qt.lighter(f.tinte, 1.3) : Paleta.texto, .32) }
            GradientStop { position: 1;  color: "transparent" }
        }
    }
}
