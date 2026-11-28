// Isla: el estado compartido de la «isla viva» (la isla del reloj, RelojBarra.qml).
//   · avisos breves: volumen, micro, brillo, Bloq Mayús, canción, carga… (los manda OSD.qml).
//     Si la barra del monitor enfocado se ve, el aviso sale en la isla; si no (juego, pantalla
//     completa, sin barra), OSD.qml sigue mostrando su pastilla de siempre abajo al centro.
//   · música: el reproductor que suena y las ondas de cava (un solo proceso para todas las barras).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris

Singleton {
    id: isla

    // ── Aviso breve ─────────────────────────────────────────────────────
    property string icono: ""
    property string texto: ""
    property real valor: -1          // 0..1 (o más, volumen > 100 %) = barra; -1 = sin barra
    property bool apagado: false
    property bool aviso: false       // ¿se está mostrando?
    property int numero: 0           // sube con cada aviso: la isla late aunque el texto no cambie
    readonly property color tono: apagado ? Paleta.gris : valor > 1.001 ? Paleta.aviso : Paleta.acento

    property string imagen: ""       // icono de app (ruta o URL): en las notificaciones, en vez del glifo

    function mostrar(ic, val, txt, off, ms) {   // ms: cuánto se queda (1,6 s si no se dice)
        icono = ic; imagen = ""; valor = val; texto = txt ?? ""; apagado = off ?? false;
        aviso = true; numero++;
        fin.interval = ms ?? 1600; fin.restart();
    }
    // Una notificación nueva: la isla enseña el icono de la app y el título mientras la tarjeta cae debajo
    function notificar(img, txt) {
        icono = img ? "" : String.fromCodePoint(0xF009A); imagen = img ?? ""; valor = -1; texto = txt ?? ""; apagado = false;
        aviso = true; numero++;
        fin.interval = 2200; fin.restart();
    }
    Timer { id: fin; interval: 1600; onTriggered: isla.aviso = false }

    // ── Bienvenida: una vez por sesión (Bienvenida.qml e IslaBarra.qml la animan) ──
    // La marca vive en $XDG_RUNTIME_DIR, que se vacía al cerrar sesión: reiniciar Quickshell no la repite.
    FileView {
        id: marca
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/orion-bienvenida"
        blockLoading: true
        printErrors: false
    }
    property bool bienvenida: false
    Component.onCompleted: {
        bienvenida = !marca.loaded && EstiloPanel.movimiento;
        if (!marca.loaded) marca.setText(String(Date.now()));
    }
    function saludar() {
        const h = new Date().getHours();
        const saludo = h >= 5 && h < 12 ? "Buenos días" : h >= 12 && h < 20 ? "Buenas tardes" : h < 5 ? "Ya es tarde" : "Buenas noches";
        const u = Quickshell.env("USER") || "";
        mostrar(String.fromCodePoint(h >= 6 && h < 19 ? 0xF0599 : 0xF0594), -1, saludo + (u ? ", " + u.charAt(0).toUpperCase() + u.slice(1) : ""));
        fin.interval = 3200; fin.restart();
    }
    Timer { running: isla.bienvenida; interval: 1300; onTriggered: isla.saludar() }
    Timer { running: isla.bienvenida; interval: 4000; onTriggered: isla.bienvenida = false }   // lo que se cree después, ya sin bienvenida

    // ── ¿Hay una isla a la vista? ───────────────────────────────────────
    // Cada barra avisa si se ve (Barra.qml → registrar). El aviso va a la isla del monitor enfocado,
    // salvo con una ventana a pantalla completa (tapa la barra).
    property var barras: ({})
    function registrar(monitor, visible) {
        if (!monitor || barras[monitor] === visible) return;
        const b = Object.assign({}, barras); b[monitor] = visible; barras = b;
    }
    readonly property string enfocado: Hyprland.focusedMonitor?.name ?? ""
    readonly property bool pantallaCompleta: ToplevelManager.activeToplevel?.fullscreen ?? false
    readonly property bool enBarra: barras[enfocado] === true && !pantallaCompleta

    // ── Música ──────────────────────────────────────────────────────────
    readonly property var jugador: {
        const lista = Mpris.players.values;
        return lista.find(p => p.isPlaying) ?? null;
    }
    readonly property bool suena: jugador !== null
    readonly property string titulo: jugador?.trackTitle || jugador?.identity || ""
    readonly property string artista: jugador?.trackArtist ?? ""
    readonly property string caratula: jugador?.trackArtUrl ?? ""

    // Ondas: cava solo corre mientras suena algo y alguna barra se ve (y nunca con privacidad)
    readonly property bool quiereOndas: !EstadoEscritorio.privacidad && Object.values(barras).some(v => v)
    property var ondas: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    Process {
        running: isla.suena && isla.quiereOndas
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/cava.conf"]
        stdout: SplitParser {
            onRead: (linea) => {
                const v = linea.split(";").filter(x => x !== "").map(Number);
                if (v.length === 10) isla.ondas = v;
            }
        }
        onRunningChanged: if (!running) isla.ondas = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }
}
