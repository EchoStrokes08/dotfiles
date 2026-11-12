// Notificaciones emergentes: arriba a la derecha, debajo de la barra. Entran deslizándose.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ventana
    visible: Notificaciones.emergentes.length > 0
    color: "transparent"
    anchors { top: true; right: true }
    // margen interior para que quepa la sombra de las tarjetas
    implicitWidth: 400 + 36
    implicitHeight: columna.implicitHeight + 40
    exclusionMode: ExclusionMode.Normal     // respeta la barra (aparece debajo)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notificaciones"

    Column {
        id: columna
        x: 18; y: 8
        width: parent.width - 36
        spacing: 12

        Repeater {
            model: Notificaciones.emergentes
            NotiTarjeta {
                id: tarj
                required property var modelData
                noti: modelData
                emergente: true
                width: columna.width
                onTerminada: Notificaciones.quitarEmergente(modelData)

                // Entrada: desde la derecha
                x: 0
                opacity: 1
                Component.onCompleted: { x = 40; opacity = 0; entrada.start(); }
                ParallelAnimation {
                    id: entrada
                    NumberAnimation { target: tarj; property: "x"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    NumberAnimation { target: tarj; property: "opacity"; to: 1; duration: 200 }
                }
            }
        }
    }
}
