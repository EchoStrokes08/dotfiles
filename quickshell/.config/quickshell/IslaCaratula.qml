// IslaCaratula: carátula de la canción que suena (Isla.qml), con halo de sus colores; sin carátula, una nota.
// Al cambiar de canción gira como una carta (eje vertical): media vuelta con la portada vieja, cambio
// de cara cuando la nueva ya está cargada y vuelta con un pequeño rebote. Sin movimiento, cambia sin más.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: car
    property real lado: 22
    implicitWidth: lado; implicitHeight: lado

    // la portada que se ve: va un paso por detrás de Isla.caratula mientras la carta gira
    property string mostrada: ""          // sin enlace (si siguiera a Isla.caratula no habría giro)
    Component.onCompleted: mostrada = Isla.caratula
    property real giro: 0                 // grados alrededor del eje vertical
    Image {   // precarga la nueva: la carta no gira hasta tenerla, así no asoma la nota a mitad
        id: precarga
        visible: false
        source: Isla.caratula
        sourceSize { width: car.lado * 2; height: car.lado * 2 }
        asynchronous: true
        onStatusChanged: car.cambiar()
        onSourceChanged: car.cambiar()
    }
    function cambiar() {
        const nueva = String(Isla.caratula);
        if (nueva === mostrada || vuelta.running) return;
        if (!nueva || !mostrada || !EstiloPanel.movimiento) { mostrada = nueva; return; }
        if (precarga.status === Image.Loading) return;      // ya avisará al terminar
        vuelta.restart();
    }
    SequentialAnimation {
        id: vuelta
        NumberAnimation { target: car; property: "giro"; from: 0; to: 90; duration: EstiloPanel.normal; easing.type: Easing.InCubic }
        ScriptAction { script: car.mostrada = Isla.caratula }
        NumberAnimation { target: car; property: "giro"; from: -90; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        ScriptAction { script: car.cambiar() }               // por si cambió otra vez a mitad
    }
    transform: Rotation {
        origin { x: car.width / 2; y: car.height / 2 }
        axis { x: 0; y: 1; z: 0 }
        angle: car.giro
    }
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
            source: car.mostrada
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
