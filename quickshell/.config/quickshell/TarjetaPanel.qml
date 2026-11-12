// TarjetaPanel: una sección dentro de un panel (estilo "bento"): fondo translúcido con un leve
// degradado del acento y filo de luz. Lo de dentro va en una columna.
//   TarjetaPanel { acento: Paleta.azul; Text { … } Otra { Layout.fillWidth: true } }
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: t
    property color acento: Paleta.texto
    property real relleno: 14
    property alias espaciado: interior.spacing
    default property alias contenido: interior.data
    implicitWidth: interior.implicitWidth + relleno * 2
    implicitHeight: interior.implicitHeight + relleno * 2
    radius: 16
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(t.acento, .5)), .065) }
        GradientStop { position: 1; color: Qt.alpha(Paleta.texto, .022) }
    }
    border { width: 1; color: Qt.alpha(Paleta.texto, .075) }
    Rectangle {
        x: t.radius; y: 1; width: t.width - t.radius * 2; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(Paleta.texto, .14) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    ColumnLayout {
        id: interior
        anchors { fill: parent; margins: t.relleno }
        spacing: 10
    }
}
