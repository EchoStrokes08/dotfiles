// Interruptor: el conmutador sí/no de los paneles (Brújula, Móvil, Centro de control).
//   Interruptor { activo: …; acento: Paleta.verde; onAlternado: … }
import QtQuick
import QtQuick.Effects

Item {
    id: sw
    property bool activo: false
    property color acento: Paleta.verde
    signal alternado()
    implicitWidth: 42; implicitHeight: 24
    Accessible.role: Accessible.CheckBox
    Accessible.checked: activo

    RectangularShadow {
        anchors.fill: pista
        visible: EstiloPanel.efectos && sw.activo
        radius: pista.radius
        blur: 14; spread: -4
        color: Qt.alpha(sw.acento, .45)
    }
    Rectangle {
        id: pista
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: sw.activo ? Qt.alpha(sw.acento, .55) : Qt.alpha(Paleta.texto, .10); Behavior on color { ColorAnimation { duration: 180 } } }
            GradientStop { position: 1; color: sw.activo ? Qt.alpha(Qt.lighter(sw.acento, 1.2), .85) : Qt.alpha(Paleta.texto, .14); Behavior on color { ColorAnimation { duration: 180 } } }
        }
        border { width: 1; color: sw.activo ? Qt.alpha(sw.acento, .8) : Qt.alpha(Paleta.texto, .12) }
    }
    Rectangle {
        id: perilla
        width: sw.height - 6; height: width; radius: width / 2
        y: 3
        x: sw.activo ? sw.width - width - 3 : 3
        color: sw.activo ? "white" : Qt.tint(Paleta.gris, Qt.alpha(Paleta.texto, .3))
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        Behavior on color { ColorAnimation { duration: 180 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.alternado() }
}
