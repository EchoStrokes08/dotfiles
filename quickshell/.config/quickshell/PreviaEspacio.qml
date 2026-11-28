// PreviaEspacio: al dejar el ratón sobre el número de un espacio en la barra, se despliega debajo una
// miniatura de ese espacio: el fondo y cada ventana en su sitio y a su tamaño (una foto de cada una con
// ScreencopyView, no en vivo: en vivo trababa el ratón), con el nombre del espacio y cuántas ventanas tiene.
// Solo sale con el ratón QUIETO encima (1,5 s sin moverse; rozar la barra no la abre). Abierta, pasar a
// otro número la cambia tras un instante quieto.
// No sale para el espacio activo (ya lo ves) ni para los vacíos (ahí queda la ayuda de siempre).
// Con privacidad, solo los iconos de las apps. BarraEspacios.qml la abre; una por barra (Barra.qml).
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PopupWindow {
    id: pv
    property var ventana: null           // la PanelWindow de la barra
    property var monitor: null           // HyprlandMonitor de esa barra
    property var espacio: null           // HyprlandWorkspace que se enseña
    property real centroX: 0
    property bool abierta: false
    readonly property bool privado: EstadoEscritorio.privacidad

    // BarraEspacios la llama al entrar y en cada movimiento: la espera vuelve a empezar mientras te mueves
    property var pendiente: null
    property real pendienteX: 0
    function mostrar(item, ws) {
        pendienteX = item.mapToItem(null, item.width / 2, 0).x;
        pendiente = ws;
        espera.interval = abierta ? 180 : 1500;
        espera.restart();
    }
    function ocultar() {
        espera.stop();
        pendiente = null;
        abierta = false;
    }
    Timer {
        id: espera
        onTriggered: {
            if (!pv.pendiente) return;
            pv.centroX = pv.pendienteX;
            if (pv.espacio !== pv.pendiente) { pv.espacio = pv.pendiente; Hyprland.refreshToplevels(); }
            if (!pv.fondo) leerFondo.running = true;
            pv.abierta = true;
            pv.visible = true;
        }
    }

    // ── tamaño: el de la pantalla, a escala ──
    readonly property real anchoMon: monitor ? monitor.width / (monitor.lastIpcObject?.scale ?? 1) : 1920
    readonly property real altoMon: monitor ? monitor.height / (monitor.lastIpcObject?.scale ?? 1) : 1080
    readonly property real anchoMapa: 288
    readonly property real escala: anchoMapa / Math.max(1, anchoMon)
    readonly property real altoMapa: Math.round(altoMon * escala)

    anchor.window: ventana
    anchor.rect.x: Math.max(4, Math.min(centroX - implicitWidth / 2, (ventana?.width ?? 0) - implicitWidth - 4))
    anchor.rect.y: (ventana?.height ?? 34) + 6
    implicitWidth: anchoMapa + 16
    implicitHeight: altoMapa + 52
    color: "transparent"
    visible: false

    property string fondo: ""
    Process {
        id: leerFondo
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/tema/wallpaper"]
        stdout: StdioCollector { onStreamFinished: pv.fondo = text.trim() }
    }
    // el fondo puede cambiar mientras tanto: se relee cada vez que se cierra
    onAbiertaChanged: if (!abierta) leerFondo.running = true

    // aparecer: crece desde el número; desaparecer: se recoge y luego se desmapea
    property real p: 0
    Behavior on p { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.normal : 0; easing.type: Easing.OutCubic } }
    Binding { target: pv; property: "p"; value: pv.abierta ? 1 : 0 }
    onPChanged: if (p === 0 && !abierta) visible = false

    Rectangle {
        id: tarjeta
        anchors.fill: parent
        radius: EstiloPanel.rTarjeta
        opacity: pv.p
        scale: .94 + .06 * pv.p
        transformOrigin: Item.Top
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.acento, .08)) }
            GradientStop { position: 1; color: Paleta.fondo }
        }
        border { width: 1; color: Qt.alpha(Paleta.acento, .35) }

        // cabecera: número, nombre y ventanas
        Row {
            id: cabecera
            x: 12; y: 10
            spacing: 8
            Rectangle {
                width: 20; height: 20; radius: height / 2
                color: Qt.alpha(Paleta.acento, .18)
                Text {
                    anchors.centerIn: parent
                    text: pv.espacio?.id ?? ""
                    color: Paleta.acento
                    font { family: Paleta.fuente; pixelSize: 11; bold: true }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                readonly property string nombre: pv.espacio?.name && pv.espacio.name !== String(pv.espacio.id) ? pv.espacio.name : "Espacio " + (pv.espacio?.id ?? "")
                text: nombre
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                readonly property int n: pv.espacio?.toplevels.values.length ?? 0
                text: n + (n === 1 ? " ventana" : " ventanas")
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }

        // el mapa: la pantalla en pequeño
        Rectangle {
            id: mapa
            x: 8; y: 40
            width: pv.anchoMapa; height: pv.altoMapa
            radius: EstiloPanel.rControl
            color: Paleta.cieloNoche
            clip: true
            layer.enabled: true          // recorta las miniaturas con el radio

            Image {
                anchors.fill: parent
                source: pv.fondo ? "file://" + pv.fondo : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(pv.anchoMapa * 2, pv.altoMapa * 2)
                asynchronous: true
                opacity: .75
            }

            Repeater {
                model: pv.visible ? (pv.espacio?.toplevels.values ?? []) : []
                Item {
                    id: ventanita
                    required property var modelData
                    readonly property var ipc: modelData.lastIpcObject ?? ({})
                    readonly property var en: ipc.at ?? [0, 0]
                    readonly property var tam: ipc.size ?? [pv.anchoMon, pv.altoMon]
                    readonly property real mx: (pv.monitor?.lastIpcObject?.x ?? 0)
                    readonly property real my: (pv.monitor?.lastIpcObject?.y ?? 0)
                    x: (en[0] - mx) * pv.escala
                    y: (en[1] - my) * pv.escala
                    width: Math.max(8, tam[0] * pv.escala)
                    height: Math.max(8, tam[1] * pv.escala)
                    z: ipc.floating ? 2 : 1

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: EstiloPanel.elevada
                        border { width: 1; color: Qt.alpha(Paleta.texto, .14) }
                    }
                    ScreencopyView {
                        id: vivo
                        anchors.fill: parent
                        anchors.margins: 1
                        captureSource: pv.visible && !pv.privado ? (ventanita.modelData.wayland ?? null) : null
                        live: false                   // una foto al abrir
                    }
                    IconoApp {
                        anchors.centerIn: parent
                        visible: pv.privado || !vivo.hasContent
                        app: ({ clase: ventanita.ipc.class ?? "", nombre: ventanita.ipc.class ?? "" })
                        lado: Math.max(12, Math.min(28, Math.min(parent.width, parent.height) * .4))
                    }
                }
            }
        }
    }
}
