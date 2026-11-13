// Interruptor: el conmutador sí/no de los paneles (Brújula, Móvil, Centro de control).
//   Interruptor { activo: …; acento: Paleta.exito; onAlternado: … }
import QtQuick
import QtQuick.Effects

Item {
    id: sw
    property bool activo: false
    property color acento: Paleta.exito
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
            GradientStop { position: 0; color: sw.activo ? Qt.alpha(sw.acento, .55) : EstiloPanel.rellenoActivo; Behavior on color { ColorAnimation { duration: EstiloPanel.normal } } }
            GradientStop { position: 1; color: sw.activo ? Qt.alpha(Qt.lighter(sw.acento, 1.2), .85) : EstiloPanel.bordeFuerte; Behavior on color { ColorAnimation { duration: EstiloPanel.normal } } }
        }
        border { width: 1; color: sw.activo ? Qt.alpha(sw.acento, .8) : EstiloPanel.bordeFuerte }
    }
    Rectangle {
        id: perilla
        width: sw.height - 6; height: width; radius: width / 2
        y: 3
        x: sw.activo ? sw.width - width - 3 : 3
        color: sw.activo ? "white" : Qt.tint(Paleta.gris, EstiloPanel.velo)
        Behavior on x { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: EstiloPanel.normal } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.alternado() }
}
