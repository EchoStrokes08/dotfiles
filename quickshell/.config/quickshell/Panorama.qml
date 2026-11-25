// Panorama: el wallpaper como un paisaje ancho y cada espacio de trabajo, un tramo de él. Al cambiar de
// espacio la cámara se desliza por el paisaje (más despacio que las ventanas: profundidad). Del 1 al 10 de
// izquierda a derecha, así el 2 (navegador) y el 9 (chats) siempre tienen «su» vista.
// awww sigue pintando el fondo debajo; esta capa (Background, justo encima) tiene la misma imagen con un poco
// de zoom: el adaptativo que la imagen aguanta sin verse borrosa (1,12× con fondos de 1920 px, hasta 1,5× con 4K).
// Al cambiar de wallpaper se aparta durante la transición de awww y luego la cámara entra hasta su sitio.
// Preferencia: PreferenciasUI.panorama. Fuera con el perfil rendimiento o jugando; sin movimiento, sin deslizar.
// Una por pantalla (shell.qml).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: pa
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int espacio: monitor?.activeWorkspace?.id ?? 1
    readonly property bool permitido: PreferenciasUI.panorama && EstadoEscritorio.perfil !== "rendimiento"
        && EstadoEscritorio.datos.juego_activo !== "true"
    readonly property real dpr: screen?.devicePixelRatio ?? 1

    visible: permitido && ruta !== ""
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-panorama"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}                              // los clics llegan al escritorio

    // ── El wallpaper y su tamaño natural ────────────────────────────────
    property string ruta: ""
    property real anchoNatural: 0
    property real altoNatural: 0
    Process {
        id: leer
        running: true
        command: ["sh", "-c",
            'r=$(readlink -f "$HOME/.local/state/tema/wallpaper") || exit 0; printf "%s\\n" "$r"; ' +
            'python3 -I -c "import sys; from PIL import Image; print(*Image.open(sys.argv[1]).size)" "$r" 2>/dev/null'];
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                const [w, h] = (l[1] ?? "").split(" ").map(Number);
                if (!l[0] || !(w > 0 && h > 0)) return;
                if (l[0] === pa.ruta && w === pa.anchoNatural) return;
                pa.nuevo = { ruta: l[0], w: w, h: h };
                if (pa.ruta === "") pa.aplicarNuevo(); else apartar.restart();
            }
        }
    }
    // El enlace ~/.local/state/tema/wallpaper cambia con cada fondo nuevo (scripts/wallpaper.sh)
    Process {
        running: pa.permitido
        command: ["inotifywait", "-m", "-q", "-e", "create,moved_to", "--format", "%f", Quickshell.env("HOME") + "/.local/state/tema"]
        stdout: SplitParser { onRead: (f) => { if (f === "wallpaper") leer.running = true; } }
    }
    onPermitidoChanged: if (permitido) leer.running = true

    // ── Geometría ───────────────────────────────────────────────────────
    // base: la imagen «a tapar» la pantalla, como awww · zoom: lo que aguanta sin perder nitidez
    readonly property real escalaBase: anchoNatural > 0 && altoNatural > 0 ? Math.max(width * dpr / anchoNatural, height * dpr / altoNatural) : 1
    readonly property real anchoBase: anchoNatural * escalaBase / dpr
    readonly property real altoBase: altoNatural * escalaBase / dpr
    readonly property real zoom: Math.max(1.12, Math.min(1.5, 1 / Math.max(.01, escalaBase)))
    // t: 0 = exactamente como awww (centrado, sin zoom) · 1 = en el panorama
    property real t: 0
    // f: posición en el paisaje (0 = espacio 1 · 1 = espacio 10), anima al cambiar de espacio.
    // Con 3 dedos a los lados (Gestos.qml) la cámara sigue a los dedos mientras Hyprland arrastra las
    // ventanas; al soltar va hasta el espacio en el que acabes (o vuelve si cancelas).
    readonly property real fEspacio: (Math.max(1, Math.min(10, espacio)) - 1) / 9
    readonly property bool siguiendo: Gestos.activo && Gestos.dedos === 3 && Gestos.eje === "h"
    readonly property real distancia: 300        // como workspace_swipe_distance de Hyprland (por defecto)
    property real arrastre: 0                    // en espacios: -1 … 1 (dedos a la izquierda = siguiente)
    property real f: Math.max(0, Math.min(1, fEspacio + arrastre / 9))
    Behavior on f {
        enabled: pa.t >= 1 && !pa.siguiendo
        NumberAnimation { duration: EstiloPanel.movimiento ? 1100 : 0; easing.type: Easing.OutCubic }
    }
    Connections {
        target: Gestos
        function onDxChanged() { if (pa.siguiendo) pa.arrastre = Math.max(-1, Math.min(1, -Gestos.dx / pa.distancia)); }
        function onTermino() { if (pa.arrastre !== 0) soltar.restart(); }
    }
    // Al soltar se espera un momento al cambio de espacio de Hyprland: así va directa al destino
    Timer { id: soltar; interval: 300; onTriggered: pa.arrastre = 0 }
    onEspacioChanged: if (arrastre !== 0) { soltar.stop(); arrastre = 0; }
    readonly property real zoomActual: 1 + (zoom - 1) * t
    readonly property real xNeutro: (width - anchoBase) / 2
    readonly property real xObjetivo: -f * (anchoBase * zoom - width)

    Item {
        id: lienzo
        anchors.fill: parent
        Image {
            id: imagen
            x: pa.xNeutro * (1 - pa.t) + pa.xObjetivo * pa.t
            y: (pa.height - height) / 2
            width: pa.anchoBase * pa.zoomActual
            height: pa.altoBase * pa.zoomActual
            source: pa.ruta ? "file://" + pa.ruta : ""
            sourceSize: Qt.size(Math.min(pa.anchoNatural, Math.ceil(pa.anchoBase * pa.zoom * pa.dpr)),
                                Math.min(pa.altoNatural, Math.ceil(pa.altoBase * pa.zoom * pa.dpr)))
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
            mipmap: true
            cache: false
            onStatusChanged: if (status === Image.Ready && pa.esperandoImagen) { pa.esperandoImagen = false; lienzo.opacity = 1; entrar.restart(); }
        }
    }

    // ── Cambio de wallpaper: apartarse, dejar que awww haga su transición y entrar ──
    property var nuevo: null
    property bool esperandoImagen: false
    function aplicarNuevo() {
        if (!nuevo) return;
        entrar.stop();
        t = 0;                                   // igual que awww: el cambio de capa no se nota
        altoNatural = nuevo.h; anchoNatural = nuevo.w;     // el alto antes: escalaBase solo mira si hay ancho
        esperandoImagen = true;
        ruta = nuevo.ruta;
        nuevo = null;
        if (imagen.status === Image.Ready && imagen.source.toString() === "file://" + ruta) { esperandoImagen = false; lienzo.opacity = 1; entrar.restart(); }
    }
    SequentialAnimation {
        id: apartar
        ScriptAction { script: entrar.stop() }
        NumberAnimation { target: lienzo; property: "opacity"; to: 0; duration: EstiloPanel.movimiento ? 90 : 0 }
        PauseAnimation { duration: 1600 }        // la transición de awww dura hasta 1,4 s
        ScriptAction { script: pa.aplicarNuevo() }
    }
    // La cámara entra hasta el sitio de este espacio
    SequentialAnimation {
        id: entrar
        PauseAnimation { duration: EstiloPanel.movimiento ? 600 : 0 }
        NumberAnimation { target: pa; property: "t"; to: 1; duration: EstiloPanel.movimiento ? 1800 : 0; easing.type: Easing.InOutCubic }
    }
}
