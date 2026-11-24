// FondoBoton: el fondo común de los botones de los paneles (BotonPanel y los «Boton» de Brújula,
// Móvil y Agente). Superficie neutra y filo de luz arriba; destacado = selección neutra con borde del tinte.
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
    // alerta: el botón pide confirmar algo irreversible. Halo de peligro que late (lento, InOutSine)
    // hasta que se decide; sin movimiento, el halo queda fijo.
    property bool alerta: false
    property real latido: .5
    SequentialAnimation on latido {
        running: f.alerta && f.visible && EstiloPanel.movimiento
        loops: Animation.Infinite
        onRunningChanged: if (!running) f.latido = .5
        NumberAnimation { to: 1;  duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: .3; duration: 700; easing.type: Easing.InOutSine }
    }
    RectangularShadow {
        anchors.fill: parent
        visible: f.alerta
        radius: f.radio
        blur: 18
        spread: -2
        color: Qt.alpha(Paleta.peligro, .2 + .3 * f.latido)
    }

    implicitWidth: 80
    implicitHeight: 38

    RectangularShadow {
        anchors.fill: parent
        visible: EstiloPanel.profundidad && f.destacado
        radius: f.radio
        offset.y: 5
        blur: 20
        spread: -7
        color: Qt.alpha("black", f.encima ? .40 : .28)
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    Rectangle {
        anchors.fill: parent
        radius: f.radio
        color: f.destacado ? (f.pulsado || f.encima ? EstiloPanel.seleccionadoEncima : EstiloPanel.seleccionado)
            : f.encima ? EstiloPanel.rellenoActivo : EstiloPanel.superficie
        border.width: f.foco ? 2 : 1
        border.color: f.foco ? f.tinte
            : f.destacado ? Qt.alpha(f.tinte, f.encima ? .95 : .8)
            : Qt.alpha(f.encima ? f.tinte : Paleta.texto, f.encima ? .38 : .085)
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
    }
    // Un filo solo en cristal; las superficies sólidas ya tienen jerarquía tonal.
    Rectangle {
        visible: EstiloPanel.profundidad
        x: f.radio * .7; y: 1
        width: parent.width - f.radio * 1.4; height: 1
        opacity: f.destacado ? .9 : f.encima ? .7 : .45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;  color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(Paleta.texto, .32) }
            GradientStop { position: 1;  color: "transparent" }
        }
    }
}
