// CapaDespedida: lo que se ve al apagar, reiniciar o cerrar sesión (estado en Despedida.qml).
// La captura de la pantalla se aleja, se desenfoca y se funde a negro; en el sitio de la isla del reloj
// aparece una isla que se despide. Por encima de todo y sin dejar pasar clics. Una por pantalla.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: c
    readonly property string ruta: Despedida.capturas[screen?.name ?? ""] ?? ""
    property real p: 0                   // 0 = la pantalla tal cual · 1 = negro
    visible: Despedida.activa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-despedida"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive   // nada se escribe mientras se apaga

    onVisibleChanged: if (visible) { p = 0; isla.opacity = 0; isla.scale = .6; irse.restart(); }

    Rectangle { anchors.fill: parent; color: "black"; opacity: c.ruta ? 1 : c.p }
    Item {
        anchors.fill: parent
        visible: c.ruta !== ""
        scale: 1 - .1 * c.p
        opacity: 1 - c.p
        Image {
            id: captura
            anchors.fill: parent
            visible: false
            source: c.ruta ? "file://" + c.ruta + "?n=" + Despedida.numero : ""
            cache: false
            asynchronous: false
        }
        MultiEffect {
            anchors.fill: parent
            source: captura
            blurEnabled: true; blur: c.p; blurMax: 48
            brightness: -.3 * c.p
        }
    }

    // La isla que se despide, donde está la del reloj. Se crea solo al despedirse: creada al arrancar,
    // recibía la caída de la bienvenida en una ventana oculta (ahí no avanzan) y se quedaba fuera de la pantalla.
    Loader {
        id: isla
        active: c.visible
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        sourceComponent: IslaBarra {
            implicitWidth: fila.implicitWidth + 32
            tinte: .1
            Row {
                id: fila
                anchors.centerIn: parent
                spacing: 8
                Glifo {
                    text: String.fromCodePoint(Despedida.tipo === "reiniciar" ? 0xF0453 : 0xF0594)
                    color: Paleta.acento
                    font { family: Paleta.mono; pixelSize: 14 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Despedida.mensaje
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 13; bold: true }
                }
            }
        }
    }

    SequentialAnimation {
        id: irse
        ParallelAnimation {
            NumberAnimation { target: isla; property: "opacity"; to: 1; duration: EstiloPanel.normal }
            NumberAnimation { target: isla; property: "scale"; to: 1; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: c; property: "p"; to: 1; duration: 1100; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: EstiloPanel.normal }
        NumberAnimation { target: isla; property: "opacity"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.InCubic }
    }
}
