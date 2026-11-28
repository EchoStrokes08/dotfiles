// CapaCaptura: las capturas vuelan. Al hacer una captura (capturas.sh → qs ipc call captura mostrar),
// lo capturado destella en su sitio, se despega de la pantalla y vuela encogiéndose hasta una tarjeta
// abajo a la derecha (como en macOS), mientras la isla avisa de que está copiada.
//   · clic en la tarjeta → anotar (satty) · arrastrarla → suelta el archivo en cualquier app
//   · con el ratón encima no se va; botones para abrir, ver la carpeta, borrar o cerrar
//   · se va sola a los 7 s deslizándose hacia la derecha
// capturas.sh llama antes a «captura preparar»: la tarjeta se esconde al instante para no salir en la foto.
// Sin movimiento (perfil mínimo, reducir movimiento) la tarjeta aparece sin vuelo.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    property string ruta: ""
    property rect desde: Qt.rect(0, 0, 0, 0)     // dónde estaba lo capturado (coordenadas de esta pantalla)
    property rect hacia: Qt.rect(0, 0, 0, 0)     // la tarjeta
    property real p: 0                           // 0 = en su sitio · 1 = tarjeta
    property real velo: 0                        // opacidad de todo
    property real fuera: 0                       // 0 = en su sitio · 1 = salió por la derecha
    property real destello: 0
    property real resta: 1                       // tiempo que le queda (la línea de abajo)
    property bool lista: false                   // ya es tarjeta: recibe el ratón
    readonly property bool encima: raton.containsMouse || zonaBotones.encima

    visible: velo > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-captura"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: c.lista ? tarjeta : nada }
    Item { id: nada; width: 0; height: 0 }

    IpcHandler {
        target: "captura"
        // archivo: la captura ya guardada · geo: «x,y WxH» lógica de grim/slurp ("" = pantalla completa)
        function mostrar(archivo: string, geo: string): void { c.mostrar(archivo, geo); }
        function preparar(): void { c.esconder(); }
        function cerrar(): void { c.irse(); }
    }

    function esconder() {
        vuelo.stop(); salida.stop(); cuenta.stop();
        c.lista = false; c.velo = 0; c.p = 0; c.fuera = 0;
    }

    function mostrar(archivo, geo) {
        esconder();
        const m = /^\s*(-?\d+),(-?\d+)\s+(\d+)x(\d+)/.exec(geo ?? "");
        const gx = m ? +m[1] : null, gy = m ? +m[2] : null;
        // la pantalla donde se hizo: la que contiene la región, o la enfocada
        const s = (m ? Quickshell.screens.find(x => gx >= x.x && gx < x.x + x.width && gy >= x.y && gy < x.y + x.height) : null)
                  ?? Quickshell.screens.find(x => x.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        if (s) c.screen = s;
        const W = s?.width ?? 1920, H = s?.height ?? 1080;
        c.desde = m ? Qt.rect(gx - s.x, gy - s.y, Math.max(1, +m[3]), Math.max(1, +m[4])) : Qt.rect(0, 0, W, H);

        // la tarjeta: ~280 de ancho, nunca más de 200 de alto, abajo a la derecha del área útil
        const a = c.desde.width / c.desde.height;
        let tw = 280, th = tw / a;
        if (th > 200) { th = 200; tw = th * a; }
        if (tw < 96) { tw = 96; th = Math.min(200, tw / a); }
        const mon = Hyprland.monitors.values.find(x => x.name === s?.name);
        const r = mon?.lastIpcObject?.reserved ?? [0, 0, 0, 0];
        c.hacia = Qt.rect(W - r[2] - EstiloPanel.e5 - tw, H - r[3] - EstiloPanel.e5 - th, tw, th);

        c.ruta = archivo;
        foto.source = "";
        foto.source = "file://" + archivo;
        c.resta = 1;
        Isla.mostrar(String.fromCodePoint(0xF0100), -1, "Captura copiada");
        if (EstiloPanel.movimiento) {
            c.velo = 1; c.destello = .7;
            vuelo.restart();
        } else {
            c.p = 1; c.lista = true; aparecer.restart(); cuenta.restart();
        }
    }

    function irse() { if (c.velo > 0 && !salida.running) { vuelo.stop(); cuenta.stop(); salida.restart(); } }

    function ejecutar(orden) { Quickshell.execDetached(["sh", "-c", orden]); }
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    function q(t) { return "'" + String(t).replace(/'/g, "'\\''") + "'"; }

    // ── El vuelo ────────────────────────────────────────────────────────
    SequentialAnimation {
        id: vuelo
        NumberAnimation { target: c; property: "destello"; to: 0; duration: 90; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 60 }
        NumberAnimation { target: c; property: "p"; from: 0; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: .9 }
        ScriptAction { script: { c.lista = true; cuenta.restart(); } }
    }
    NumberAnimation { id: aparecer; target: c; property: "velo"; from: 0; to: 1; duration: EstiloPanel.normal }
    NumberAnimation {
        id: cuenta
        target: c; property: "resta"; from: 1; to: 0; duration: 7000
        paused: running && (c.encima || arrastre.active)
        onFinished: c.irse()
    }
    SequentialAnimation {
        id: salida
        ScriptAction { script: c.lista = false }
        ParallelAnimation {
            NumberAnimation { target: c; property: "fuera"; to: 1; duration: EstiloPanel.movimiento ? 520 : 0; easing.type: Easing.InCubic }
            NumberAnimation { target: c; property: "velo"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.InCubic }
        }
        ScriptAction { script: c.esconder() }
    }

    // posición entre el sitio original y la tarjeta (p puede pasarse un poco de 1 con el rebote)
    readonly property real cx: desde.x + (hacia.x - desde.x) * p + fuera * (hacia.width + EstiloPanel.e6)
    readonly property real cy: desde.y + (hacia.y - desde.y) * p
    readonly property real cw: Math.max(1, desde.width + (hacia.width - desde.width) * Math.min(p, 1.04))
    readonly property real ch: Math.max(1, desde.height + (hacia.height - desde.height) * Math.min(p, 1.04))
    readonly property real pc: Math.max(0, Math.min(1, p))

    Item {
        id: tarjeta
        x: c.cx; y: c.cy; width: c.cw; height: c.ch
        opacity: c.velo * (arrastre.active ? .45 : 1)
        scale: raton.pressed && !arrastre.active ? .97 : 1
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }

        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.profundidad
            radius: marco.radius; blur: 36; offset.y: 12; spread: -4
            color: Qt.alpha("black", .5 * c.pc)
        }
        ClippingRectangle {
            id: marco
            anchors.fill: parent
            radius: EstiloPanel.rTarjeta * c.pc
            color: EstiloPanel.elevada
            border { width: c.pc > .5 ? 1 : 0; color: EstiloPanel.bordeFuerte }

            Image {
                id: foto
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1280
                asynchronous: false
                cache: false
                smooth: true
                mipmap: true
            }
            // destello: lo capturado se ilumina un instante, como el obturador
            Rectangle { anchors.fill: parent; color: "white"; opacity: c.destello }

            // con el ratón encima: velo abajo y las acciones
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 56
                opacity: c.encima && c.lista ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.fondo, .85) }
                }
            }
            // el tiempo que le queda
            Rectangle {
                anchors { left: parent.left; bottom: parent.bottom }
                height: 2
                width: parent.width * c.resta
                color: Paleta.acento
                opacity: c.lista && !c.encima ? .9 : 0
                Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
            }
        }

        MouseArea {
            id: raton
            anchors.fill: parent
            enabled: c.lista
            hoverEnabled: true
            cursorShape: arrastre.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: fantasma
            drag.threshold: 8
            onPressed: fantasma.x = 0, fantasma.y = 0
            onClicked: { if (!arrastre.active) { c.ejecutar(c.scripts + "capturas.sh editar " + c.q(c.ruta)); c.irse(); } }
        }
        // lo que se arrastra a otra app: el archivo (text/uri-list)
        Item {
            id: fantasma
            width: 1; height: 1
            Drag.active: raton.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(c.ruta) + "\r\n", "text/plain": c.ruta })
            Drag.onDragFinished: dropAction => { if (dropAction === Qt.CopyAction) c.irse(); }
        }
        QtObject { id: arrastre; readonly property bool active: raton.drag.active }

        Row {
            id: zonaBotones
            property bool encima: b1.encima || b2.encima || b3.encima || b4.encima
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: EstiloPanel.e2 }
            spacing: EstiloPanel.e1
            visible: c.lista
            opacity: c.encima ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
            BotonCaptura { id: b1; glifo: 0xF03CC; ayuda: "Abrir"; onPulsado: { c.ejecutar("xdg-open " + c.q(c.ruta)); c.irse(); } }
            BotonCaptura { id: b2; glifo: 0xF024B; ayuda: "Ver carpeta"; onPulsado: { c.ejecutar("thunar " + c.q(c.ruta.replace(/\/[^/]*$/, ""))); c.irse(); } }
            BotonCaptura { id: b3; glifo: 0xF0A7A; ayuda: "Borrar"; peligro: true
                onPulsado: { c.ejecutar("gio trash " + c.q(c.ruta) + "; wl-copy --clear"); Isla.mostrar(String.fromCodePoint(0xF0A7A), -1, "Captura en la papelera"); c.irse(); } }
            BotonCaptura { id: b4; glifo: 0xF0156; ayuda: "Cerrar"; onPulsado: c.irse() }
        }
    }

    component BotonCaptura: Rectangle {
        id: bc
        property int glifo
        property string ayuda
        property bool peligro: false
        readonly property bool encima: m.containsMouse
        signal pulsado()
        width: 30; height: 30; radius: height / 2
        color: m.containsMouse ? (peligro ? Qt.alpha(Paleta.peligro, .85) : Qt.alpha(Paleta.texto, .22)) : Qt.alpha(Paleta.fondo, .7)
        border { width: 1; color: EstiloPanel.borde }
        scale: m.pressed ? .9 : 1
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
        Accessible.name: ayuda
        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(bc.glifo)
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 14 }
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bc.pulsado() }
    }
}
