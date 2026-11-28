// Actividades: lo que está EN MARCHA, para la burbuja que se separa de la isla del reloj (IslaActividades.qml).
// Como las «Live Activities»: cada una con icono, color, título, detalle, progreso y una acción.
//   Solas:      grabación de pantalla (grabar.sh) · descargas (.crdownload / .part en ~/Downloads)
//               · paquetes (pacman instalando) · reunión (Reunion.qml)
//               · el próximo evento del calendario: cuenta atrás con anillo desde 10 min antes hasta 5 min
//                 después de empezar; si el lugar trae un enlace (Teams, Meet, Zoom…) el botón «Unirse» lo abre
//   Propias:    temporizador y cronómetro
//     qs ipc call actividades temporizador 300 "Té"     (segundos y nombre opcional)
//     qs ipc call actividades cronometro                (otra vez: lo para)
//   De scripts: qs ipc call actividades poner <id> <icono hex> <título> <detalle> <progreso 0–1 | -1>
//               qs ipc call actividades quitar <id>
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ac
    property real ahora: Date.now()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: ac.ahora = Date.now() }

    // ── Detectadas (un vistazo cada 2 s, barato) ────────────────────────
    property var grabacion: null         // { modo, inicio }
    property var descargas: []           // [{ nombre, bytes, velocidad }]
    property string paquetes: ""         // última línea útil de pacman.log mientras pacman corre
    property var tamanos: ({})           // nombre → bytes del vistazo anterior (para la velocidad)
    Process {
        id: vistazo
        command: ["sh", "-c",
            'r=${XDG_RUNTIME_DIR:-/tmp}; p=$(cat "$r/grabar.pid" 2>/dev/null); ' +
            '[ -n "$p" ] && kill -0 "$p" 2>/dev/null && cat "$r/grabar.estado"; echo "@@"; ' +
            'find "$HOME/Downloads" "$HOME/Descargas" -maxdepth 1 \\( -name "*.crdownload" -o -name "*.part" \\) -printf "%s\\t%f\\n" 2>/dev/null; echo "@@"; ' +
            'pgrep -x pacman >/dev/null && grep -E "\\] (upgraded|installed|removed) " /var/log/pacman.log | tail -n 1; true'];
        stdout: StdioCollector {
            onStreamFinished: {
                const [g, d, pq] = text.split("@@\n");
                const gp = (g ?? "").trim().split(/\s+/);
                ac.grabacion = gp[0] ? { modo: gp[0], inicio: Number(gp[gp.length - 1] || 0) * 1000 || Date.now() } : null;
                const nuevos = {}, lista = [];
                for (const l of (d ?? "").split("\n")) {
                    const i = l.indexOf("\t");
                    if (i < 0) continue;
                    const bytes = Number(l.slice(0, i)), nombre = l.slice(i + 1).replace(/\.(crdownload|part)$/, "");
                    nuevos[nombre] = bytes;
                    lista.push({ nombre: nombre, bytes: bytes, velocidad: Math.max(0, (bytes - (ac.tamanos[nombre] ?? bytes)) / 2) });
                }
                ac.tamanos = nuevos; ac.descargas = lista;
                const m = (pq ?? "").match(/\] (upgraded|installed|removed) (\S+)/);
                ac.paquetes = m ? ({ upgraded: "Actualizando ", installed: "Instalando ", removed: "Quitando " })[m[1]] + m[2]
                                : (pq ?? "").trim() ? "Trabajando…" : "";
            }
        }
    }
    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!vistazo.running) vistazo.running = true }

    // ── Temporizador y cronómetro ───────────────────────────────────────
    property var temporizador: null      // { fin, total, nombre }
    property real cronometro: 0          // inicio (ms) o 0
    function temporizar(segundos, nombre) {
        if (segundos <= 0) { temporizador = null; return; }
        temporizador = { fin: Date.now() + segundos * 1000, total: segundos * 1000, nombre: nombre || "Temporizador" };
        Isla.mostrar(String.fromCodePoint(0xF051B), -1, (nombre || "Temporizador") + " · " + duracion(segundos));
    }
    Timer {
        interval: 250; repeat: true
        running: ac.temporizador !== null
        onTriggered: {
            if (Date.now() < ac.temporizador.fin) return;
            const n = ac.temporizador.nombre;
            ac.temporizador = null;
            Isla.mostrar(String.fromCodePoint(0xF0020), -1, n + ": ¡tiempo!");
            Quickshell.execDetached(["sh", "-c", 'notify-send -u critical -a Temporizador -i alarm-symbolic "$1" "Se acabó el tiempo."; ' +
                '"$HOME/.config/hypr/scripts/sonido.sh" aviso 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null', "sh", n]);
        }
    }
    function alternarCronometro() { cronometro = cronometro ? 0 : Date.now(); }

    // ── De scripts ──────────────────────────────────────────────────────
    property var externas: ({})
    function poner(id, icono, titulo, detalle, progreso) {
        const e = Object.assign({}, externas);
        e[id] = { id: id, icono: parseInt(icono, 16) || 0xF0E1E, color: Paleta.acento2, titulo: titulo, detalle: detalle, progreso: progreso };
        externas = e;
    }
    function quitar(id) { const e = Object.assign({}, externas); delete e[id]; externas = e; }

    // ── La lista, la más importante primero ─────────────────────────────
    function duracion(s) {
        s = Math.max(0, Math.round(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(x).padStart(2, "0");
    }
    function bytes(b) { return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? (b / 1e6).toFixed(0) + " MB" : Math.round(b / 1e3) + " KB"; }
    // el evento (con hora) que empieza en ≤ 10 min o empezó hace < 5 min; con privacidad no se enseña
    function proximoEvento(t) {
        if (EstadoEscritorio.privacidad) return null;
        return Eventos.lista.find(e => !e.todoDia && e.inicio.getTime() - t <= 600000 && t - e.inicio.getTime() < 300000 && e.fin.getTime() > t) ?? null;
    }
    readonly property var lista: {
        const l = [], t = ahora;
        if (grabacion) l.push({ id: "grabacion", icono: 0xF044A, color: Paleta.peligro, titulo: grabacion.modo === "gif" ? "Grabando GIF" : "Grabando",
            detalle: duracion((t - grabacion.inicio) / 1000), corto: duracion((t - grabacion.inicio) / 1000), progreso: -1, late: true,
            accion: { icono: 0xF04DB, texto: "Parar", cmd: ["sh", "-c", "$HOME/.config/hypr/scripts/grabar.sh parar"] } });
        if (Reunion.activa) l.push({ id: "reunion", icono: 0xF036C, color: Paleta.acento2, titulo: "Reunión", detalle: "quedan " + Reunion.cuenta,
            corto: Reunion.cuenta, progreso: -1 });
        const ev = proximoEvento(t);
        if (ev) {
            const falta = (ev.inicio.getTime() - t) / 1000, url = (ev.lugar || "").match(/https?:\/\/\S+/);
            l.push({ id: "evento", icono: 0xF00ED, color: Paleta.acento, titulo: ev.titulo,
                detalle: falta > 0 ? "empieza en " + duracion(falta) : "empezó hace " + Math.max(1, Math.round(-falta / 60)) + " min",
                corto: falta > 0 ? duracion(falta) : "Ahora", progreso: falta > 0 ? 1 - falta / 600 : 1, late: falta <= 60,
                accion: url ? { icono: 0xF0567, texto: "Unirse", cmd: ["xdg-open", url[0]] } : undefined });
        }
        if (temporizador) {
            const q = Math.max(0, (temporizador.fin - t) / 1000);
            l.push({ id: "temporizador", icono: 0xF051B, color: Paleta.aviso, titulo: temporizador.nombre, detalle: "quedan " + duracion(q),
                corto: duracion(q), progreso: 1 - q * 1000 / temporizador.total,
                accion: { icono: 0xF0156, texto: "Cancelar", fn: () => ac.temporizar(0) } });
        }
        if (cronometro) l.push({ id: "cronometro", icono: 0xF13AB, color: Paleta.exito, titulo: "Cronómetro", detalle: duracion((t - cronometro) / 1000),
            corto: duracion((t - cronometro) / 1000), progreso: -1, accion: { icono: 0xF04DB, texto: "Parar", fn: () => ac.alternarCronometro() } });
        for (const d of descargas) l.push({ id: "descarga-" + d.nombre, icono: 0xF01DA, color: Paleta.acento, titulo: d.nombre,
            detalle: bytes(d.bytes) + (d.velocidad > 0 ? " · " + bytes(d.velocidad) + "/s" : ""), corto: bytes(d.bytes), progreso: -1 });
        if (paquetes) l.push({ id: "paquetes", icono: 0xF03D6, color: Paleta.acento, titulo: "Paquetes", detalle: paquetes, corto: "", progreso: -1 });
        for (const e of Object.values(externas)) l.push(Object.assign({ corto: e.progreso >= 0 ? Math.round(e.progreso * 100) + " %" : "" }, e));
        return l;
    }
}
