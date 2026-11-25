// OndaTema: al cambiar el tema, el color nuevo se propaga por la barra como una onda desde el cursor.
// Paleta.preparar → foto de la barra con los colores viejos · Paleta.ondaLista → ya están los nuevos debajo:
// la foto se borra en un círculo que crece desde el cursor (borde suave) y un frente de luz del acento nuevo
// recorre la barra. Si el cursor está en otra pantalla, la onda sale del centro.
// Va como último hijo de la ventana (Barra.qml):  OndaTema { anchors.fill: parent; pantalla: barra.screen }
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

Item {
    id: o
    property var pantalla: null
    property real cx: width / 2
    property real cy: 0
    property real r: 0                   // radio del frente
    readonly property real rMax: Math.hypot(Math.max(cx, width - cx), height) + 160
    property bool activa: false
    z: 1000

    // La foto con los colores viejos (incluye todo lo de la ventana; esta capa aún no se ve)
    // Un ShaderEffectSource de 1 px fuera de la vista: está en la escena (así se actualiza al pedírselo)
    // pero no se dibuja encima; la textura es de la barra entera (grabToImage no sirve en la raíz de la ventana)
    ShaderEffectSource {
        id: foto
        x: -2; y: -2; width: 1; height: 1
        sourceItem: o.parent
        textureSize: Qt.size(Math.ceil(o.width * (o.pantalla?.devicePixelRatio ?? 1)), Math.ceil(o.height * (o.pantalla?.devicePixelRatio ?? 1)))
        live: false
        recursive: true
        hideSource: false
    }
    // Máscara: opaca fuera del círculo, transparente dentro, con borde suave
    Item {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: o.cx; centerY: o.cy; centerRadius: Math.max(1, o.r)
                    focalX: o.cx; focalY: o.cy
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: .8; color: "transparent" }
                    GradientStop { position: 1; color: "black" }
                }
                startX: 0; startY: 0
                PathLine { x: o.width; y: 0 }
                PathLine { x: o.width; y: o.height }
                PathLine { x: 0; y: o.height }
                PathLine { x: 0; y: 0 }
            }
        }
        // fuera del radio el degradado se queda en su último color (negro): todo opaco
    }
    MultiEffect {
        anchors.fill: parent
        visible: o.activa
        source: foto
        maskEnabled: true
        maskSource: mascara
        maskThresholdMin: .5
        maskSpreadAtMin: 1
    }
    // El frente de la onda: un anillo de luz del acento nuevo
    Shape {
        anchors.fill: parent
        visible: o.activa
        preferredRendererType: Shape.CurveRenderer
        opacity: 1 - Math.pow(o.r / Math.max(1, o.rMax), 2)
        ShapePath {
            strokeWidth: 0; strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: o.cx; centerY: o.cy; centerRadius: Math.max(1, o.r)
                focalX: o.cx; focalY: o.cy
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: .7; color: "transparent" }
                GradientStop { position: .9; color: Qt.alpha(Paleta.acento, .55) }
                GradientStop { position: .97; color: Qt.alpha(Qt.lighter(Paleta.acento, 1.3), .7) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: o.width; y: 0 }
            PathLine { x: o.width; y: o.height }
            PathLine { x: 0; y: o.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // Dónde está el cursor (en esta pantalla)
    Process {
        id: cursor
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [x, y] = text.trim().split(",").map(n => Number(n));
                const px = x - (o.pantalla?.x ?? 0), py = y - (o.pantalla?.y ?? 0);
                const dentro = px >= 0 && px <= o.width && py >= 0 && py <= (o.pantalla?.height ?? 1080);
                o.cx = dentro ? px : o.width / 2;
                o.cy = dentro ? Math.min(py, o.height) : 0;
            }
        }
    }
    Connections {
        target: Paleta
        function onPreparar() {
            onda.stop(); o.activa = false; o.r = 0;
            foto.scheduleUpdate();
            cursor.running = true;
        }
        function onOndaLista() { o.r = 0; o.activa = true; onda.restart(); }
    }
    SequentialAnimation {
        id: onda
        NumberAnimation { target: o; property: "r"; from: 0; to: o.rMax; duration: 1100; easing.type: Easing.InOutCubic }
        ScriptAction { script: o.activa = false }
    }
}
