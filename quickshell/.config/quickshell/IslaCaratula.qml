// IslaCaratula: carátula de la canción que suena (Isla.qml), con halo de sus colores; sin carátula, una nota.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: car
    property real lado: 22
    implicitWidth: lado; implicitHeight: lado
    // Halo: del mismo tamaño que la carátula; solo el desenfoque lo asoma (≤ 18 px) para que no se
    // salga de la tarjeta ni de la ventana. En la isla (carátula pequeña) no cabe: se quita.
    MultiEffect {
        anchors.fill: parent
        visible: car.lado >= 40 && EstiloPanel.profundidad && imagen.status === Image.Ready
        source: imagen
        blurEnabled: true; blur: 1; blurMax: 18
        saturation: .4; brightness: .05
        opacity: .55
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: car.lado >= 40 ? EstiloPanel.rControl : car.lado / 2
        color: Qt.alpha(Paleta.acento, .16)
        border { width: 1; color: Qt.alpha(Paleta.acento, .35) }
        Image {
            id: imagen
            anchors.fill: parent
            source: Isla.caratula
            sourceSize { width: car.lado * 2; height: car.lado * 2 }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Glifo {
            anchors.centerIn: parent
            alto: car.lado
            visible: imagen.status !== Image.Ready
            text: String.fromCodePoint(0xF075A)
            color: Paleta.acento
            font { family: Paleta.mono; pixelSize: car.lado >= 40 ? 20 : 12 }
        }
    }
}
