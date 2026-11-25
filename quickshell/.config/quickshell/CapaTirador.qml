// CapaTirador: al bajar 3 dedos (Brújula), una cápsula sale de la isla del reloj y crece siguiendo a los
// dedos: la brújula gira, aparece «Brújula» y, pasado el punto, «Suelta para abrir» con el borde encendido.
// Al soltar, Brújula nace justo de la cápsula (Origen.qml) y la cápsula se funde en ella; si no llegas,
// vuelve a la isla con un rebote. Lo abre Hyprland (entrada.lua), esto solo lo acompaña.
// Necesita Gestos.disponible (instalar/gestos.sh). No recibe clics. Una por pantalla, solo en la del foco.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: c
    property bool brujulaAbierta: false
    readonly property bool enfocada: Hyprland.focusedMonitor?.name === (screen?.name ?? "")
    readonly property bool siguiendo: Gestos.activo && Gestos.dedos === 3 && Gestos.eje === "v"
        && enfocada && !brujulaAbierta
    property real p: 0                   // 0 = la isla · 1 = listo para abrir (pasa un poco con resistencia)
    readonly property real e: p <= 1 ? 1 - Math.pow(1 - p, 3) : 1 + (p - 1) * .25

    visible: Gestos.disponible && (siguiendo || p > .001 || soltar.running)
    color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: 280
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tirador"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: Gestos
        function onDyChanged() { if (c.siguiendo) c.p = Math.max(0, Math.min(1.4, Gestos.dy / 220)); }
        function onEmpezo() { volver.stop(); soltar.stop(); capsula.opacity = 1; capsula.scale = 1; }
        function onTermino() {
            if (c.p <= .001) return;
            if (!Gestos.cancelado && c.p >= .35) {
                const centro = capsula.mapToItem(null, capsula.width / 2, capsula.height / 2);
                Origen.marcarPunto(centro.x, centro.y, c.screen?.name ?? "");
                soltar.restart();
            } else volver.restart();
        }
    }
    // Brújula nace de aquí: la cápsula se hincha un poco y se funde
    SequentialAnimation {
        id: soltar
        ParallelAnimation {
            NumberAnimation { target: capsula; property: "opacity"; to: 0; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
            NumberAnimation { target: capsula; property: "scale"; to: 1.08; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: { c.p = 0; capsula.opacity = 1; capsula.scale = 1; } }
    }
    // No llegó: vuelve a la isla
    NumberAnimation { id: volver; target: c; property: "p"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

    // Halo debajo, que crece con el tirón
    Bruma {
        anchors.horizontalCenter: parent.horizontalCenter
        y: capsula.y + capsula.height * .5 - height / 2
        width: 320 + 260 * c.e; height: 160 + 120 * c.e
        tono: Paleta.acento
        fuerza: .22 * Math.min(1, c.p) * capsula.opacity
    }

    IslaBarra {
        id: capsula
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        width: 132 + 168 * c.e
        height: 34 + 96 * c.e
        tinte: .06 + .1 * Math.min(1, c.p)
        acento: Paleta.acento
        // borde que se enciende al pasar el punto
        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, 24)
            color: "transparent"
            border { width: 1.5; color: Qt.alpha(Paleta.acento, c.p >= 1 ? .9 : .25 * c.p) }
            Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
        }
        Column {
            anchors.centerIn: parent
            spacing: 4
            Glifo {
                anchors.horizontalCenter: parent.horizontalCenter
                alto: 20 + 32 * c.e
                text: String.fromCodePoint(0xF018B)
                color: c.p >= 1 ? Paleta.acento : Paleta.texto
                rotation: -90 + 90 * Math.min(1, c.p)
                font { family: Paleta.mono; pixelSize: c.p > .5 ? 44 : 20 }
                scale: .7 + .3 * Math.min(1, c.e)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: Math.max(0, Math.min(1, (c.p - .3) * 3))
                text: c.p >= 1 ? "Suelta para abrir" : "Brújula"
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; bold: true }
            }
        }
    }
}
