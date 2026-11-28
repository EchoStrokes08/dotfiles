// CapaBateria: los avisos de batería se ven en los bordes de la pantalla (Cargador.alerta).
//   20 %     un resplandor ámbar entra desde los bordes y late dos veces
//   10 %     lo mismo en rojo, tres veces
//   ≤ 5 %    un resplandor rojo respira despacio en los bordes hasta que enchufas (también jugando)
//   cargada  un marco verde suave se enciende y se apaga una vez
// La isla dice el porcentaje y el tiempo que queda (Cargador.avisar). Es un aviso, no un adorno:
// sale también en el perfil mínimo. Los clics atraviesan la capa. Una por pantalla (shell.qml).
//   qs ipc call bateria probar 20 | 10 | 5 | llena
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: c
    property real brillo: 0               // aviso puntual (0 → 1)
    property real respiro: 0              // batería crítica: sube y baja mientras dure
    property color tono: Paleta.aviso
    readonly property real fuerza: Math.max(brillo, respiro)

    visible: brillo > 0 || Cargador.critica
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bateria"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: Cargador
        function onAlerta(nivel) {
            c.tono = nivel === 0 ? Paleta.exito : nivel <= 10 ? Paleta.peligro : Paleta.aviso;
            latidos.veces = nivel === 0 ? 1 : nivel <= 10 ? 3 : 2;
            latidos.alto = nivel === 0 ? .7 : 1;
            latidos.restart();
        }
    }
    SequentialAnimation {
        id: latidos
        property int veces: 2
        property real alto: 1
        NumberAnimation { target: c; property: "brillo"; from: 0; to: latidos.alto; duration: 700; easing.type: Easing.OutCubic }
        SequentialAnimation {
            loops: Math.max(1, latidos.veces - 1)
            NumberAnimation { target: c; property: "brillo"; to: latidos.alto * .35; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { target: c; property: "brillo"; to: latidos.alto; duration: 650; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 600 }
        NumberAnimation { target: c; property: "brillo"; to: 0; duration: 1400; easing.type: Easing.InOutCubic }
    }
    SequentialAnimation {
        running: Cargador.critica
        loops: Animation.Infinite
        onRunningChanged: if (!running) c.respiro = 0
        NumberAnimation { target: c; property: "respiro"; to: .6; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { target: c; property: "respiro"; to: .15; duration: 1600; easing.type: Easing.InOutSine }
    }
    readonly property color color2: Cargador.critica && brillo < respiro ? Paleta.peligro : tono

    // El resplandor: cuatro degradados que entran desde los bordes, más un filo brillante que sigue el
    // borde redondeado de la pantalla (el mismo radio que EsquinasPantalla.qml)
    Item {
        anchors.fill: parent
        opacity: c.fuerza
        readonly property real hondo: Math.min(c.width, c.height) * .14

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: parent.hondo
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(c.color2, .55) }
                GradientStop { position: 1; color: Qt.alpha(c.color2, 0) }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.hondo
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(c.color2, 0) }
                GradientStop { position: 1; color: Qt.alpha(c.color2, .55) }
            }
        }
        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: parent.hondo
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(c.color2, .55) }
                GradientStop { position: 1; color: Qt.alpha(c.color2, 0) }
            }
        }
        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: parent.hondo
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha(c.color2, 0) }
                GradientStop { position: 1; color: Qt.alpha(c.color2, .55) }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: EstiloPanel.rTarjeta
            color: "transparent"
            border { width: 3; color: Qt.lighter(c.color2, 1.15) }
        }
    }
}
