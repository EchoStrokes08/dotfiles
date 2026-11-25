// CapaLanzamiento: la app se abre desde su icono (estado en Lanzamiento.qml).
// El icono del lanzador crece y se convierte en una tarjeta con los colores de la app que se expande
// hasta donde aparecerá la ventana: en un espacio vacío, toda el área útil; si hay una ventana enfocada
// en mosaico, la mitad de ella por donde se partirá. Si la app tarda, el icono late (como en macOS);
// cuando Hyprland abre la ventana («openwindow»), la tarjeta se funde con ella. Máximo 4 s.
// Los clics atraviesan la capa.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    property var desde: null          // rectángulo del icono
    property rect hacia: Qt.rect(0, 0, 0, 0)
    property string icono: ""
    property real p: 0                // 0 = en el icono · 1 = donde irá la ventana
    property real velo: 0             // opacidad de toda la tarjeta
    visible: velo > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-lanzamiento"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: Lanzamiento
        function onNumeroChanged() {
            const q = Lanzamiento.peticion;
            if (!q) return;
            const s = Quickshell.screens.find(x => x.name === q.pantalla) ?? Quickshell.screens.find(x => x.name === Hyprland.focusedMonitor?.name);
            if (s) c.screen = s;
            c.desde = q; c.icono = q.icono; c.hacia = c.destino();
            fundir.stop(); espera.stop();
            c.p = 0; c.velo = 1;
            crecer.restart();
            limite.restart();
        }
    }
    // Dónde aparecerá la ventana (coordenadas lógicas de esta pantalla)
    function destino() {
        const m = Hyprland.focusedMonitor, ipc = m?.lastIpcObject;
        const esc = m?.scale ?? 1;
        const W = (m?.width ?? 1920) / esc, H = (m?.height ?? 1080) / esc;
        const r = ipc?.reserved ?? [0, 0, 0, 0];
        const area = Qt.rect(r[0], r[1], W - r[0] - r[2], H - r[1] - r[3]);
        const a = Hyprland.activeToplevel?.lastIpcObject;
        const mismoEspacio = a && a.workspace?.id === m?.activeWorkspace?.id;
        if (!mismoEspacio || a.floating || a.fullscreen || !a.size) return area;
        const x = a.at[0] - (m?.x ?? 0), y = a.at[1] - (m?.y ?? 0), w = a.size[0], h = a.size[1];
        // dwindle parte la ventana enfocada por su lado largo; la nueva va a la derecha o abajo
        return w >= h ? Qt.rect(x + w / 2, y, w / 2, h) : Qt.rect(x, y + h / 2, w, h / 2);
    }

    // Se abre la ventana: la tarjeta se funde con ella
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "openwindow" && c.velo > 0 && !fundir.running) c.terminar(); }
    }
    function terminar() { crecer.stop(); espera.stop(); limite.stop(); fundir.restart(); }
    Timer { id: limite; interval: 4000; onTriggered: c.terminar() }

    readonly property real cx: !desde ? 0 : desde.x + (hacia.x - desde.x) * p
    readonly property real cy: !desde ? 0 : desde.y + (hacia.y - desde.y) * p
    readonly property real cw: !desde ? 0 : desde.ancho + (hacia.width - desde.ancho) * p
    readonly property real ch: !desde ? 0 : desde.alto + (hacia.height - desde.alto) * p

    Item {
        id: tarjeta
        x: c.cx; y: c.cy; width: c.cw; height: c.ch
        opacity: c.velo

        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.profundidad
            radius: fondo.radius; blur: 40; offset.y: 14; spread: -4
            color: Qt.alpha("black", .45 * c.p)
        }
        ClippingRectangle {
            id: fondo
            anchors.fill: parent
            radius: 12 + 2 * c.p                          // de la baldosa (12) al de las ventanas (14)
            color: EstiloPanel.elevada
            border { width: 1; color: EstiloPanel.bordeFuerte }
            // los colores de la app: el propio icono, enorme y muy desenfocado
            MultiEffect {
                anchors.centerIn: parent
                width: Math.max(parent.width, parent.height) * 1.2; height: width
                source: imagen
                visible: imagen.status === Image.Ready
                blurEnabled: true; blur: 1; blurMax: 64
                saturation: .35; brightness: -.15
                opacity: .9 * c.p
            }
            Rectangle { anchors.fill: parent; color: Qt.alpha(Paleta.fondo, .35 * c.p) }
        }
        IconImage {
            id: imagen
            anchors.centerIn: parent
            implicitSize: 28 + 52 * c.p
            source: c.icono
            asynchronous: false
        }
    }

    // Crece hasta su sitio; luego, si la app aún no ha abierto, el icono late
    NumberAnimation {
        id: crecer
        target: c; property: "p"; from: 0; to: 1
        duration: 520; easing.type: Easing.OutCubic
        onFinished: espera.start()
    }
    SequentialAnimation {
        id: espera
        loops: Animation.Infinite
        NumberAnimation { target: imagen; property: "scale"; to: 1.08; duration: 600; easing.type: Easing.InOutSine }
        NumberAnimation { target: imagen; property: "scale"; to: 1; duration: 600; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: fundir
        NumberAnimation { target: c; property: "velo"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.InCubic }
        ScriptAction { script: { imagen.scale = 1; c.p = 0; } }
    }
}
