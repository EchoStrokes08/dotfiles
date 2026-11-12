// IslaBarra: una "isla" de cristal de la barra superior (cápsula flotante). Es solo el fondo:
// lo que va dentro se declara como hijo y se coloca encima.
//   IslaBarra { implicitWidth: fila.implicitWidth + 16; RowLayout { id: fila; anchors.centerIn: parent … } }
import QtQuick
import QtQuick.Effects

Item {
    id: isla
    property color acento: Paleta.naranja
    property real tinte: .06            // cuánto se nota el acento en el degradado
    implicitHeight: 34

    RectangularShadow {
        anchors.fill: parent
        visible: EstiloPanel.efectos
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
            GradientStop { position: 0; color: Qt.alpha(Qt.tint(Paleta.fondo, Qt.alpha(isla.acento, isla.tinte * 1.6)), .82) }
            GradientStop { position: 1; color: Qt.alpha(Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .02)), .88) }
        }
        border { width: 1; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(isla.acento, .4)), .12) }
    }
    // filo de luz superior
    Rectangle {
        x: isla.height * .6; y: 1
        width: Math.max(0, isla.width - isla.height * 1.2); height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: .5; color: Qt.alpha(Paleta.texto, .16) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
