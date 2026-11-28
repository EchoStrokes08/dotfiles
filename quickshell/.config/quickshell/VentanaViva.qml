// VentanaViva: cualquier ventana, en vivo y flotando encima de todo (como un Picture-in-Picture universal).
// SUPER+ALT+V fija la ventana activa: se encoge y vuela desde su sitio hasta una esquina. Desde ahí:
//   · arrastrar → se mueve y, al soltar, se pega a la esquina más cercana
//   · rueda → más grande o más pequeña · doble clic o ↗ → ir a la ventana · ✕ (o SUPER+ALT+V otra vez) → soltarla
//   · cuando estás en el espacio de la ventana original, se aparta (no hace falta verla dos veces)
//   · si la ventana se cierra, se va sola. Con la privacidad activa, solo el icono.
//   qs ipc call ventanaviva alternar | soltar | estado
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    property string dir: ""                              // dirección de la ventana fijada (sin 0x)
    readonly property var ventana: dir ? Hyprland.toplevels.values.find(t => t.address === dir) ?? null : null
    readonly property var ipc: ventana?.lastIpcObject ?? null
    readonly property bool privado: EstadoEscritorio.privacidad
    readonly property bool enSuEspacio: !!ventana && ventana.workspace?.id === Hyprland.focusedMonitor?.activeWorkspace?.id
    readonly property bool mostrar: !!ventana && !enSuEspacio

    property int esquina: 1                              // 0 ↖ · 1 ↗ · 2 ↙ · 3 ↘
    property real ancho: 384
    readonly property real aspecto: {
        const s = ipc?.size;
        return s && s[1] > 0 ? Math.max(.4, Math.min(3, s[0] / s[1])) : 16 / 9;
    }
    readonly property real alto: ancho / aspecto
    readonly property var reservado: Hyprland.monitorFor(screen)?.lastIpcObject?.reserved ?? [0, 0, 0, 0]
    readonly property real margen: EstiloPanel.e5
    readonly property real ex: esquina % 2 === 0 ? reservado[0] + margen : width - reservado[2] - margen - ancho
    readonly property real ey: esquina < 2 ? reservado[1] + margen : height - reservado[3] - margen - alto

    // el vuelo de entrada: desde la ventana real hasta la esquina
    property rect desde: Qt.rect(0, 0, 0, 0)
    property real p: 1
    property real velo: 0                                 // 0 = apartada · 1 = a la vista

    visible: dir !== "" && (velo > 0 || p < 1)
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-ventanaviva"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: c.velo > .5 && c.p >= 1 ? tarjeta : nada }
    Item { id: nada; width: 0; height: 0 }

    onMostrarChanged: velo = mostrar ? 1 : 0
    Behavior on velo { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
    onVentanaChanged: if (!ventana && dir !== "") soltar()

    IpcHandler {
        target: "ventanaviva"
        function alternar(): void { c.alternar(); }
        function soltar(): void { c.soltar(); }
        // fija una ventana por su dirección (hyprctl clients), sin enfocarla
        function fijar(direccion: string): void { c.fijarDir(direccion.replace(/^0x/, "")); }
        function estado(): string { return JSON.stringify({ fijada: c.dir, clase: c.ipc?.class ?? "", visible: c.mostrar }); }
    }

    function alternar() {
        const a = Hyprland.activeToplevel;
        if (dir !== "" && (!a || a.address === dir)) { soltar(); return; }
        if (a) fijarDir(a.address);
    }
    function fijarDir(d) {
        const a = Hyprland.toplevels.values.find(t => t.address === d);
        if (!a) return;
        salida.stop();
        const s = Quickshell.screens.find(x => x.name === Hyprland.focusedMonitor?.name);
        if (s) c.screen = s;
        const o = a.lastIpcObject, m = Hyprland.focusedMonitor;
        desde = o?.at ? Qt.rect(o.at[0] - (m?.x ?? 0), o.at[1] - (m?.y ?? 0), o.size[0], o.size[1]) : Qt.rect(ex, ey, ancho, alto);
        dir = a.address;
        Isla.mostrar(String.fromCodePoint(0xF0403), -1, "Ventana viva: " + (o?.class ?? "ventana"));
        if (EstiloPanel.movimiento) { p = 0; vuelo.restart(); } else p = 1;
        velo = mostrar ? 1 : 0;
    }
    function soltar() { vuelo.stop(); velo = 0; salida.restart(); }
    Timer { id: salida; interval: EstiloPanel.normal + 20; onTriggered: { c.dir = ""; c.p = 1; } }
    function irAVentana() {
        if (dir) Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${dir}" })`);
    }
    NumberAnimation { id: vuelo; target: c; property: "p"; from: 0; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: .8 }

    // ── La tarjeta ──
    property bool arrastrando: false
    property real ax: 0
    property real ay: 0
    readonly property real tx: arrastrando ? ax : ex
    readonly property real ty: arrastrando ? ay : ey
    property real sx: tx
    property real sy: ty
    Behavior on sx { enabled: !c.arrastrando && c.p >= 1; SpringAnimation { spring: 3.2; damping: .32; epsilon: .3 } }
    Behavior on sy { enabled: !c.arrastrando && c.p >= 1; SpringAnimation { spring: 3.2; damping: .32; epsilon: .3 } }
    Behavior on ancho { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }

    Item {
        id: tarjeta
        readonly property real k: Math.min(1, c.p)
        x: c.desde.x + (c.sx - c.desde.x) * c.p
        y: c.desde.y + (c.sy - c.desde.y) * c.p
        width: c.desde.width + (c.ancho - c.desde.width) * k
        height: c.desde.height + (c.alto - c.desde.height) * k
        opacity: c.velo
        scale: (.92 + .08 * c.velo) * (c.arrastrando ? 1.03 : 1)
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }

        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.profundidad
            radius: marco.radius; blur: c.arrastrando ? 48 : 32; offset.y: c.arrastrando ? 18 : 10; spread: -4
            color: Qt.alpha("black", .5)
        }
        ClippingRectangle {
            id: marco
            anchors.fill: parent
            radius: EstiloPanel.rTarjeta
            color: EstiloPanel.elevada
            border { width: 1; color: encima.hovered ? EstiloPanel.bordeSeleccion : EstiloPanel.bordeFuerte }
            Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }

            ScreencopyView {
                anchors.fill: parent
                captureSource: !c.privado && c.ventana ? (c.ventana.wayland ?? null) : null
                live: c.visible && (c.velo > 0 || c.p < 1)
            }
            IconoApp {
                anchors.centerIn: parent
                visible: c.privado
                app: ({ clase: c.ipc?.class ?? "", nombre: c.ipc?.class ?? "" })
                lado: 56
            }
            // con el ratón encima: el título y las acciones arriba
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 52
                opacity: encima.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, .9) }
                    GradientStop { position: 1; color: "transparent" }
                }
                Text {
                    anchors { left: parent.left; right: acciones.left; top: parent.top; margins: EstiloPanel.e3 }
                    text: c.ipc?.title || c.ipc?.class || ""
                    color: Paleta.texto
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                    layer.enabled: c.privado
                    layer.effect: MultiEffect { blurEnabled: true; blur: .6 }
                }
                Row {
                    id: acciones
                    anchors { right: parent.right; top: parent.top; margins: EstiloPanel.e2 }
                    spacing: EstiloPanel.e1
                    BotonViva { glifo: 0xF03CC; onPulsado: c.irAVentana() }
                    BotonViva { glifo: 0xF0156; onPulsado: c.soltar() }
                }
            }
        }

        HoverHandler { id: encima }
        DragHandler {
            id: mover
            target: null
            enabled: c.p >= 1
            cursorShape: Qt.ClosedHandCursor
            property real x0: 0
            property real y0: 0
            onActiveChanged: {
                if (active) { x0 = c.sx; y0 = c.sy; c.ax = x0; c.ay = y0; c.arrastrando = true; }
                else {
                    // se pega a la esquina más cercana a su centro
                    const mx = c.ax + c.ancho / 2, my = c.ay + c.alto / 2;
                    c.esquina = (mx < c.width / 2 ? 0 : 1) + (my < c.height / 2 ? 0 : 2);
                    c.arrastrando = false;
                }
            }
            onTranslationChanged: if (active) { c.ax = x0 + translation.x; c.ay = y0 + translation.y; }
        }
        TapHandler { onDoubleTapped: c.irAVentana() }
        WheelHandler {
            onWheel: ev => { c.ancho = Math.max(240, Math.min(c.width * .5, c.ancho * (ev.angleDelta.y > 0 ? 1.1 : 1 / 1.1))); }
        }
    }

    component BotonViva: Rectangle {
        id: bv
        property int glifo
        signal pulsado()
        width: 28; height: 28; radius: height / 2
        color: m.containsMouse ? Qt.alpha(Paleta.texto, .2) : Qt.alpha(Paleta.fondo, .6)
        border { width: 1; color: EstiloPanel.borde }
        scale: m.pressed ? .9 : 1
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(bv.glifo)
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 13 }
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bv.pulsado() }
    }
}
