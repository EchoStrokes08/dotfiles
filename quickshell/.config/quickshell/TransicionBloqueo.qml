// TransicionBloqueo: el bloqueo «cinematográfico». Va encima de la pantalla de bloqueo (PantallaBloqueo.qml).
//   Al bloquear:     la captura del escritorio (Bloqueo.qml la hace justo antes de bloquear) se aleja,
//                    se redondea, se desenfoca y se desvanece mientras aparece el bloqueo.
//   Al desbloquear:  (solo tras una contraseña correcta) vuelve hacia ti hasta llenar la pantalla y
//                    entonces se suelta el bloqueo: el escritorio real aparece en su sitio.
// En reposo no se ve nunca: con la pantalla bloqueada, el escritorio no queda a la vista.
// Sin captura (privacidad, sin movimiento, fallo de grim) no hace nada y el bloqueo entra como siempre.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: t
    required property var estado
    property string pantalla: ""
    readonly property string ruta: estado.capturas[pantalla] ?? ""

    // 0 = escritorio a pantalla completa y nítido · 1 = lejos, desenfocado y desvanecido
    property real lejos: 0
    property real opacidad: 0
    visible: opacidad > 0 && captura.status === Image.Ready

    Image {
        id: captura
        anchors.fill: parent
        visible: false                                   // se dibuja a través del efecto
        source: t.ruta ? "file://" + t.ruta + "?n=" + t.estado.numeroCaptura : ""
        cache: false
        asynchronous: false                              // lista en el primer fotograma
        fillMode: Image.Stretch
    }

    RectangularShadow {
        anchors.fill: marco
        visible: t.visible && EstiloPanel.profundidad
        scale: marco.scale
        radius: EstiloPanel.rPanel; blur: 60; offset.y: 20
        color: Qt.alpha("black", .5 * t.lejos * t.opacidad)
    }
    Item {
        id: marco
        anchors.fill: parent
        scale: 1 - .14 * t.lejos
        opacity: t.opacidad
        ClippingRectangle {
            anchors.fill: parent
            radius: EstiloPanel.rPanel * 2 * t.lejos
            color: "transparent"
            MultiEffect {
                anchors.fill: parent
                source: captura
                blurEnabled: EstiloPanel.profundidad
                blur: t.lejos
                blurMax: 48
                brightness: -.12 * t.lejos
            }
        }
    }

    // ── Entrada: el escritorio se aleja ──
    Component.onCompleted: if (ruta !== "") { lejos = 0; opacidad = 1; entrada.start(); }
    SequentialAnimation {
        id: entrada
        NumberAnimation { target: t; property: "lejos"; to: .55; duration: EstiloPanel.lento; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: t; property: "lejos"; to: 1; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: t; property: "opacidad"; to: 0; duration: 520; easing.type: Easing.InOutSine }
        }
    }

    // ── Salida: el escritorio vuelve hacia ti (Bloqueo.qml suelta el bloqueo al terminar) ──
    Connections {
        target: t.estado
        function onSalidaPedida() {
            if (t.ruta === "" || captura.status !== Image.Ready) return;
            entrada.stop();
            t.lejos = 1; t.opacidad = 0;
            salida.start();
        }
    }
    ParallelAnimation {
        id: salida
        NumberAnimation { target: t; property: "lejos"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutCubic }
        NumberAnimation { target: t; property: "opacidad"; to: 1; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
    }
}
