// TarjetaPanel: una sección dentro de un panel (estilo "bento"). Lo de dentro va en una columna.
//   TarjetaPanel { acento: Paleta.acento2; Text { … } Otra { Layout.fillWidth: true } }
// Con profundidad: luz desde arriba (degradado y filo), un brillo en la esquina superior izquierda
// del color `acento` (neutro por defecto) y una sombra corta que la despega del panel.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: t
    property color acento: Paleta.texto
    property real relleno: 14
    property alias espaciado: interior.spacing
    default property alias contenido: interior.data
    implicitWidth: interior.implicitWidth + relleno * 2
    implicitHeight: interior.implicitHeight + relleno * 2
    radius: EstiloPanel.rTarjeta
    color: EstiloPanel.superficie
    gradient: Gradient {
        GradientStop { position: 0; color: EstiloPanel.profundidad ? Qt.tint(EstiloPanel.superficie, Qt.alpha(Paleta.texto, .025)) : EstiloPanel.superficie }
        GradientStop { position: 1; color: EstiloPanel.superficie }
    }
    border { width: 1; color: EstiloPanel.borde }

    RectangularShadow {
        anchors.fill: parent
        z: -1
        visible: EstiloPanel.profundidad
        radius: t.radius
        offset.y: 4
        blur: 16
        spread: -6
        color: Qt.alpha("black", .30)
    }
    Rectangle {   // brillo en la esquina superior izquierda
        visible: EstiloPanel.profundidad
        anchors { fill: parent; margins: 1 }
        radius: t.radius - 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;   color: Qt.alpha(t.acento, .035) }
            GradientStop { position: .35; color: "transparent" }
        }
    }
    Rectangle {   // filo de luz superior
        visible: EstiloPanel.profundidad
        x: t.radius * .8; y: 1
        width: t.width - t.radius * 1.6; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;  color: "transparent" }
            GradientStop { position: .35; color: Qt.alpha(Paleta.texto, .16) }
            GradientStop { position: 1;  color: "transparent" }
        }
    }
    ColumnLayout {
        id: interior
        anchors { fill: parent; margins: t.relleno }
        spacing: 8
    }
}
