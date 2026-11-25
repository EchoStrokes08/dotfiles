// Notificaciones emergentes: brotan de la isla del reloj (arriba al centro, debajo de la barra).
// Al llegar, la isla enseña el icono y el título (Isla.notificar) y la tarjeta cae desde ella con un
// pequeño rebote; al cumplir su tiempo (o al cerrarla) se encoge de vuelta hacia la isla.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ventana
    visible: Notificaciones.emergentes.length > 0
    color: "transparent"
    anchors.top: true                       // solo arriba: el compositor la centra en horizontal
    // margen interior para que quepa la sombra de las tarjetas
    implicitWidth: 400 + 36
    implicitHeight: columna.implicitHeight + 40
    exclusionMode: ExclusionMode.Normal     // respeta la barra (aparece debajo)
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notificaciones"

    // La más nueva va primero: si no la habíamos visto, la isla la anuncia
    property var ultima: null
    Connections {
        target: Notificaciones
        function onEmergentesChanged() {
            const n = Notificaciones.emergentes[0];
            if (!n || n === ventana.ultima) return;
            ventana.ultima = n;
            const app = Notificaciones.nombreApp(n) || "Aviso";
            const titulo = EstadoEscritorio.privacidad ? app : (n.summary || app);
            // el mismo icono que la tarjeta: la imagen del aviso o, si no trae, el de la app (nunca con privacidad)
            Isla.notificar(EstadoEscritorio.privacidad ? "" : (n.image || Notificaciones.icono(n)), titulo);
        }
    }

    Column {
        id: columna
        x: 18; y: 8
        width: parent.width - 36
        spacing: 12
        // cuando una tarjeta se va, las demás suben a su sitio sin saltar
        move: Transition { NumberAnimation { properties: "y"; duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }

        Repeater {
            // ScriptModel compara con la lista anterior y conserva las tarjetas que siguen: si no, cada aviso
            // nuevo o quitado recreaba todas (repetían la entrada, reiniciaban su tiempo y se perdía una salida a medias)
            model: ScriptModel { values: Notificaciones.emergentes }
            NotiTarjeta {
                id: tarj
                required property var modelData
                noti: modelData
                emergente: true
                width: columna.width
                transformOrigin: Item.Top
                // Al terminar, vuelve a la isla y DESPUÉS se quita (si no, desaparecería de golpe)
                onTerminada: if (EstiloPanel.movimiento) salida.start(); else Notificaciones.quitarEmergente(modelData)

                transform: Translate { id: caida }
                Component.onCompleted: {
                    if (!EstiloPanel.movimiento) return;
                    // nace pequeña dentro de la isla (encima de la ventana) y cae a su sitio
                    scale = .3; opacity = 0; caida.y = -(y + 24);
                    entrada.start();
                }
                ParallelAnimation {
                    id: entrada
                    NumberAnimation { target: caida; property: "y"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    NumberAnimation { target: tarj; property: "scale"; to: 1; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    NumberAnimation { target: tarj; property: "opacity"; to: 1; duration: EstiloPanel.normal }
                }
                SequentialAnimation {
                    id: salida
                    ParallelAnimation {
                        NumberAnimation { target: caida; property: "y"; to: -(tarj.y + 24); duration: EstiloPanel.normal; easing.type: Easing.InCubic }
                        NumberAnimation { target: tarj; property: "scale"; to: .3; duration: EstiloPanel.normal; easing.type: Easing.InCubic }
                        NumberAnimation { target: tarj; property: "opacity"; to: 0; duration: EstiloPanel.normal; easing.type: Easing.InCubic }
                    }
                    ScriptAction { script: Notificaciones.quitarEmergente(tarj.modelData) }
                }
            }
        }
    }
}
