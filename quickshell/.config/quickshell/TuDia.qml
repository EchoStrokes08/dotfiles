// TuDia: «Tu día», el resumen cinematográfico del día en tarjetas (CapaTuDia.qml lo dibuja).
//   TuDia.mostrar()            captura la pantalla, lee scripts/tudia.py y empieza
//   qs ipc call tudia mostrar  · también al cerrar la jornada (Brújula) y desde el lanzador
// Los datos salen de la línea de tiempo de Brújula; la música la apunta este archivo cada 30 s en
// ~/.local/state/quickshell/musica/AAAA-MM-DD.jsonl (nunca con la privacidad activa). Todo local.
// Se ve también en el perfil mínimo (lo abres tú, como un vídeo); sin animaciones solo con
// «reducir movimiento» o con un juego abierto.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: td
    property bool activa: false          // la capa está en pantalla
    property bool saliendo: false        // la capa se está yendo (CapaTuDia anima y llama a terminar())
    property var datos: null
    property int pagina: 0
    property string pantalla: ""
    property string captura: ""
    property int numero: 0
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"

    // ── Movimiento propio: es un «vídeo» que se abre a propósito ─────────
    readonly property bool cine: !Paleta.reducirMovimiento && EstadoEscritorio.datos.juego_activo !== "true"
    readonly property int corto: cine ? 180 : 0
    readonly property int medio: cine ? 420 : 0
    readonly property int largo: cine ? 900 : 0
    readonly property int muyLargo: cine ? 1400 : 0
    readonly property int porTarjeta: 7000          // ms que dura cada tarjeta antes de pasar sola

    // Las tarjetas que tienen algo que contar
    readonly property var paginas: {
        const d = datos;
        if (!d) return [];
        if (d.total < 60) return ["vacio"];
        const p = ["portada", "pantalla", "apps", "ritmo"];
        if (d.racha && d.racha.segundos >= 600) p.push("racha");
        if (d.musica) p.push("musica");
        p.push("hiciste", "cierre");
        return p;
    }
    readonly property string actual: paginas[pagina] ?? ""
    // Cada tarjeta tiñe el fondo con su color
    readonly property color tono: ({
        portada: Paleta.acento, pantalla: Paleta.acento2, apps: Paleta.serie[0], ritmo: Paleta.acento2,
        racha: Paleta.exito, musica: Paleta.serie[4], hiciste: Paleta.aviso, cierre: Paleta.acento, vacio: Paleta.acento2
    })[actual] ?? Paleta.acento

    function mostrar() {
        if (activa || cargador.running) return;
        pantalla = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        const ruta = cine && dir && pantalla ? dir + "/tudia-" + pantalla + ".ppm" : "";
        cargador.ruta = ruta;
        cargador.command = ["sh", "-c",
            'umask 077; [ -n "$1" ] && { grim -o "$2" -t ppm "$1" 2>/dev/null || rm -f "$1"; }; exec python3 "$3/tudia.py"',
            "sh", ruta, pantalla, scripts];
        cargador.running = true;
    }
    function ir(n) {
        if (n < 0 || n >= paginas.length || n === pagina) return;
        pagina = n;
    }
    function siguiente() { if (pagina < paginas.length - 1) pagina++; }
    function anterior() { if (pagina > 0) pagina--; }
    function cerrar() { if (activa) saliendo = true; }
    // Al cerrar la jornada (Brújula avisa con «notificaciones motivo jornada true»): una vez, no si acabas de verlo
    property real visto: 0
    function alCerrarJornada() { if (Date.now() - visto > 600000) mostrar(); }
    // CapaTuDia la llama cuando termina de irse
    function terminar() {
        activa = false; saliendo = false; datos = null; pagina = 0; visto = Date.now();
        if (captura) Quickshell.execDetached(["rm", "-f", captura]);
        captura = "";
    }
    function cerrarJornada() {
        Quickshell.execDetached([scripts + "/brujula.py", "jornada", "cerrar"]);
        cerrar();
    }

    Process {
        id: cargador
        property string ruta: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try { td.datos = JSON.parse(text); } catch (e) { td.datos = null; }
                if (!td.datos) { console.warn("TuDia: tudia.py no devolvió datos"); return; }
                td.captura = cargador.ruta;
                td.numero++;
                td.pagina = 0;
                td.saliendo = false;
                td.activa = true;
            }
        }
    }

    // ── La música del día: cada 30 s que algo suena, una línea ───────────
    Timer {
        interval: 30000; repeat: true
        running: Isla.suena && !EstadoEscritorio.privacidad
        onTriggered: {
            const j = Isla.jugador;
            if (!j || !j.trackTitle) return;
            const hoy = Qt.formatDate(new Date(), "yyyy-MM-dd");
            const linea = JSON.stringify({ t: Math.floor(Date.now() / 1000), s: 30, ti: j.trackTitle,
                                           ar: j.trackArtist ?? "", art: j.trackArtUrl ?? "" });
            Quickshell.execDetached(["sh", "-c",
                'd="$HOME/.local/state/quickshell/musica"; mkdir -p "$d" && printf "%s\\n" "$1" >> "$d/$2.jsonl"',
                "sh", linea, hoy]);
        }
    }
}
