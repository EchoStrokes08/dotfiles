// CapaEnergia: la energía recorre los bordes de la pantalla al enchufar el cargador.
//   enchufar     dos haces de luz verde salen del centro de abajo, suben por los lados y se juntan arriba
//                en la isla (que dice «Cargando · 79 %»); el marco entero late una vez y se apaga
//   desenchufar  el marco se enciende en ámbar y se recoge hacia abajo, como si se vaciara
// Sigue el borde redondeado de la pantalla (EsquinasPantalla.qml). Sin movimiento (perfil mínimo, reducir movimiento) no sale.
// Los clics atraviesan la capa. Una por pantalla (shell.qml).
//   qs ipc call energia probar ac | bat   (solo el efecto, sin tocar el perfil de energía)
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: c
    property real p: 0                    // cuánto marco está encendido (0 → 1, de abajo arriba)
    property real brillo: 0               // opacidad global
    property real latido: 0               // pulso final del marco completo
    property color tono: Paleta.exito
    readonly property real grosor: 3
    readonly property real radio: EstiloPanel.rTarjeta   // el mismo que EsquinasPantalla.qml
    readonly property real largo: width / 2 + height + width / 2 - 4 * radio + Math.PI * radio   // de abajo-centro a arriba-centro

    visible: brillo > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-energia"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    function enchufar() {
        if (!EstiloPanel.movimiento) return;
        vaciar.stop(); c.tono = Paleta.exito; c.p = 0; c.latido = 0; c.brillo = 1;
        llenar.restart();
    }
    function desenchufar() {
        if (!EstiloPanel.movimiento) return;
        llenar.stop(); c.tono = Paleta.aviso; c.p = 1; c.latido = 0; c.brillo = 1;
        vaciar.restart();
    }
    Connections {
        target: Cargador
        function onConBateriaChanged() { Cargador.conBateria ? c.desenchufar() : c.enchufar(); }
    }
    Connections {
        target: Cargador
        function onProbar(ac) { ac ? c.enchufar() : c.desenchufar(); }
    }

    SequentialAnimation {
        id: llenar
        NumberAnimation { target: c; property: "p"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutCubic }
        NumberAnimation { target: c; property: "latido"; from: 0; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: c; property: "latido"; to: 0; duration: 700; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "brillo"; to: 0; duration: 600; easing.type: Easing.InCubic }
    }
    SequentialAnimation {
        id: vaciar
        NumberAnimation { target: c; property: "latido"; from: 0; to: .6; duration: 90 }
        NumberAnimation { target: c; property: "p"; from: 1; to: 0; duration: 750; easing.type: Easing.InCubic }
        ScriptAction { script: { c.brillo = 0; c.latido = 0; } }
    }

    // Medio marco: de abajo-centro a arriba-centro por un lado (lado = 1 derecha, -1 izquierda)
    component Mitad: ShapePath {
        id: m
        property real lado: 1
        property real ancho: c.grosor
        readonly property real i: ancho / 2
        readonly property real cx: c.width / 2
        readonly property real borde: lado > 0 ? c.width - i : i
        readonly property real hacia: lado > 0 ? -1 : 1         // del borde hacia dentro
        fillColor: "transparent"
        strokeColor: c.tono
        strokeWidth: ancho
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        strokeStyle: ShapePath.DashLine
        // recorte: un solo trazo de largo p·L (en unidades de grosor) seguido de un hueco enorme
        dashPattern: [Math.max(.001, c.p * c.largo / ancho), 4 * c.largo / ancho]
        startX: m.cx; startY: c.height - m.i
        PathLine { x: m.borde + m.hacia * c.radio; y: c.height - m.i }
        PathArc { x: m.borde; y: c.height - m.i - c.radio; radiusX: c.radio; radiusY: c.radio; direction: m.lado > 0 ? PathArc.Counterclockwise : PathArc.Clockwise }
        PathLine { x: m.borde; y: m.i + c.radio }
        PathArc { x: m.borde + m.hacia * c.radio; y: m.i; radiusX: c.radio; radiusY: c.radio; direction: m.lado > 0 ? PathArc.Counterclockwise : PathArc.Clockwise }
        PathLine { x: m.cx; y: m.i }
    }

    Item {
        anchors.fill: parent
        opacity: c.brillo
        // resplandor: el mismo marco, ancho y desenfocado
        Item {
            id: halo
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Shape {
                anchors.fill: parent
                Mitad { lado: 1; ancho: 14 }
                Mitad { lado: -1; ancho: 14 }
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: halo
            blurEnabled: true; blur: 1; blurMax: 48
            opacity: .75 + .25 * c.latido
            brightness: .2 * c.latido
        }
        // el hilo de luz nítido
        Shape {
            anchors.fill: parent
            layer.enabled: true; layer.samples: 4
            opacity: .9
            Mitad { lado: 1 }
            Mitad { lado: -1 }
        }
    }
}
