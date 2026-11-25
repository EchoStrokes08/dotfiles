// Letras: la letra en modo cine (CapaLetras.qml la dibuja). Lo que suena por MPRIS, a pantalla completa,
// con la letra sincronizada de lrclib.net (gratis, sin cuenta) que se va encendiendo mientras se canta.
//   Letras.alternar()   · qs ipc call letras toggle · SUPER+SHIFT+Y · lanzador «Letras en modo cine»
// Caché en ~/.cache/quickshell/letras/ (una vez por canción, también sin conexión después).
// Sin letra sincronizada usa la normal (avanza con la canción); sin ninguna, solo la carátula.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Singleton {
    id: le
    property bool activa: false
    property bool saliendo: false
    property string pantalla: ""

    readonly property bool cine: !Paleta.reducirMovimiento && EstadoEscritorio.datos.juego_activo !== "true"
    readonly property int corto: cine ? 180 : 0
    readonly property int medio: cine ? 420 : 0
    readonly property int largo: cine ? 700 : 0

    // El que suena; si ninguno, el primero que haya
    readonly property var jugador: {
        const l = Mpris.players.values;
        return l.find(p => p.isPlaying) ?? l[0] ?? null;
    }
    readonly property bool suena: jugador?.isPlaying ?? false
    readonly property string titulo: jugador?.trackTitle || ""
    readonly property string artista: jugador?.trackArtist || ""
    readonly property string caratula: jugador?.trackArtUrl || ""
    readonly property real duracion: jugador?.length > 0 ? jugador.length : 0

    // ── Posición precisa: MPRIS solo la da cuando se le pregunta; entre medias se interpola ──
    property real base: 0
    property real baseHora: 0
    property real posicion: 0
    function muestrear() {
        if (!jugador) return;
        jugador.positionChanged();
        base = jugador.position; baseHora = Date.now();
    }
    Timer {   // corrige la deriva (y nota los saltos que hagas desde otro sitio)
        interval: 500; repeat: true; triggeredOnStart: true
        running: le.activa && le.jugador !== null
        onTriggered: le.muestrear()
    }
    Timer {   // ~30 fps para que el barrido de la línea sea suave
        interval: 33; repeat: true
        running: le.activa && le.suena
        onTriggered: le.posicion = le.base + (Date.now() - le.baseHora) / 1000
    }
    onSuenaChanged: { muestrear(); posicion = base; }
    function buscar(t) {
        if (!jugador?.canSeek) return;
        jugador.position = Math.max(0, t);
        base = t; baseHora = Date.now(); posicion = t;
    }

    // ── La letra ────────────────────────────────────────────────────────
    property var lineas: []              // [{ t, txt }] sincronizada
    property var texto: []               // líneas sin tiempos (si no hay sincronizada)
    property string estadoLetra: ""      // "" · "buscando" · "lista" · "ninguna"
    readonly property string clave: jugador && titulo ? artista + "|" + titulo : ""
    onClaveChanged: if (activa) cargar()
    onActivaChanged: if (activa) cargar()
    function cargar() {
        lineas = []; texto = [];
        if (!clave) { estadoLetra = ""; return; }
        estadoLetra = "buscando";
        pedir.clave = clave;
        pedir.command = ["sh", "-c",
            'd="$HOME/.cache/quickshell/letras"; f="$d/$1.json"; mkdir -p "$d"; ' +
            '[ -s "$f" ] && exec cat "$f"; shift; curl -sf --max-time 15 "$@" > "$f.tmp" && mv "$f.tmp" "$f" && cat "$f"; rm -f "$f.tmp"',
            "sh", Qt.md5(clave),
            "-A", "dashboard-quickshell (github.com/EchoStrokes08/dotfiles)", "-G", "https://lrclib.net/api/get",
            "--data-urlencode", "artist_name=" + artista, "--data-urlencode", "track_name=" + titulo,
            ...(duracion > 0 ? ["--data-urlencode", "duration=" + Math.round(duracion)] : [])];
        pedir.running = true;
    }
    Process {
        id: pedir
        property string clave: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (pedir.clave !== le.clave) return;
                let sinc = [], llano = [];
                try {
                    const j = JSON.parse(text);
                    for (const linea of (j.syncedLyrics ?? "").split("\n")) {
                        const m = linea.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
                        if (m) sinc.push({ t: +m[1] * 60 + +m[2], txt: m[3].trim() });
                    }
                    llano = (j.plainLyrics ?? "").split("\n").map(x => x.trim());
                } catch (e) {}
                le.lineas = sinc;
                le.texto = sinc.length ? [] : llano.filter((x, i, a) => x !== "" || (i > 0 && a[i - 1] !== ""));
                le.estadoLetra = sinc.length || le.texto.length ? "lista" : "ninguna";
            }
        }
    }
    // La línea que suena (la última cuyo tiempo ya pasó) y cuánto lleva de ella (0–1)
    readonly property int actual: {
        let i = -1;
        for (let k = 0; k < lineas.length; k++) { if (lineas[k].t <= posicion + .15) i = k; else break; }
        return i;
    }
    readonly property real avance: {
        if (actual < 0) return 0;
        const ini = lineas[actual].t;
        const fin = actual + 1 < lineas.length ? lineas[actual + 1].t : Math.max(ini + 4, duracion);
        return Math.max(0, Math.min(1, (posicion - ini) / Math.max(.5, Math.min(fin - ini, 8))));
    }
    // ¿Un hueco instrumental? (línea vacía, o la primera aún no ha llegado)
    readonly property bool pausaMusical: lineas.length > 0 && (actual < 0 ? posicion < lineas[0].t - 1 : lineas[actual].txt === "")

    function alternar() {
        if (activa) { cerrar(); return; }
        pantalla = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        saliendo = false;
        activa = true;
        muestrear(); posicion = base;
    }
    function cerrar() { if (activa) saliendo = true; }
    function terminar() { activa = false; saliendo = false; }
}
