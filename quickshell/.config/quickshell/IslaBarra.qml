// IslaBarra: una "isla" de cristal de la barra superior (cápsula flotante). Es solo el fondo:
// lo que va dentro se declara como hijo y se coloca encima.
//   IslaBarra { implicitWidth: fila.implicitWidth + 16; RowLayout { id: fila; anchors.centerIn: parent … } }
import QtQuick
import QtQuick.Effects

Item {
    id: isla
    property color acento: Paleta.acento
    property real tinte: .035            // cuánto se nota el acento en el degradado
    implicitHeight: 34
    readonly property real solidez: !EstiloPanel.profundidad ? 1 : EstiloPanel.fondoClaro ? .96 : .92

    RectangularShadow {
        anchors.fill: parent
        visible: EstiloPanel.profundidad
        radius: height / 2
        offset.y: 3
        blur: 14
        spread: -3
        color: Qt.alpha("black", .32)
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Qt.tint(EstiloPanel.elevada, Qt.alpha(isla.acento, EstiloPanel.profundidad ? isla.tinte : 0)), isla.solidez) }
            GradientStop { position: 1; color: Qt.alpha(Paleta.fondo, Math.min(1, isla.solidez + .04)) }
        }
        border { width: 1; color: EstiloPanel.bordeFuerte }
    }
    // bisel interior
    Rectangle {
        anchors { fill: parent; margins: 1.5 }
        radius: height / 2
        color: "transparent"
        border { width: 1; color: EstiloPanel.relleno }
    }
    // filo de luz superior
    Rectangle {
        visible: EstiloPanel.profundidad
        x: isla.height * .6; y: 1
        width: Math.max(0, isla.width - isla.height * 1.2); height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(isla.acento, .3)), .38) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
