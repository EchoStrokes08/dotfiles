// Eventos de Google Calendar (scripts/eventos.py, cada 15 min). El dashboard marca los días con
// eventos en el calendario y enseña los próximos; 10 min antes de cada evento con hora, avisa.
// La dirección del calendario está en ~/.config/calendario/url (privada, fuera del repo).
// Crear eventos/tareas y ver las tareas pendientes va por scripts/gcal.py (API de Google, necesita
// ~/.config/calendario/cliente.json y haber hecho «gcal.py conectar» una vez).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ev
    property var lista: []            // [{ inicio: Date, fin: Date, titulo, lugar, todoDia }]
    property var avisados: ({})       // eventos ya avisados (inicio+título), para no repetir
    property var tareas: []           // [{ id, titulo, fecha: Date|null }] pendientes de Google Tasks
    property bool conectado: false    // ¿hay sesión de Google para escribir?
    property bool hayCliente: false   // ¿existe cliente.json?
    property bool ocupado: false      // guardando algo
    readonly property string gcal: Quickshell.env("HOME") + "/.config/hypr/scripts/gcal.py"

    Process {
        id: leer
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/hypr/scripts/eventos.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    ev.lista = JSON.parse(this.text).map(e => ({ inicio: new Date(e.inicio), fin: new Date(e.fin),
                        titulo: e.titulo, lugar: e.lugar, todoDia: e.todoDia }));
                } catch (e) { }
            }
        }
    }
    Timer { interval: 15 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: leer.running = true }
    function actualizar() { leer.running = true; if (conectado) leerTareas.running = true; }

    // ── Escribir en Google (gcal.py) ──
    Process {
        id: verEstado
        running: true
        command: ["python3", "-I", ev.gcal, "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const e = JSON.parse(this.text); ev.hayCliente = e.cliente; ev.conectado = e.conectado; } catch (x) { }
                if (ev.conectado) leerTareas.running = true;
            }
        }
    }
    Process {
        id: leerTareas
        command: ["python3", "-I", ev.gcal, "tareas"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const l = JSON.parse(this.text);
                    if (Array.isArray(l)) ev.tareas = l.map(t => ({ id: t.id, titulo: t.titulo,
                        fecha: t.fecha ? new Date(+t.fecha.slice(0, 4), +t.fecha.slice(5, 7) - 1, +t.fecha.slice(8, 10)) : null }));
                } catch (x) { }
            }
        }
    }
    Timer { interval: 15 * 60000; running: ev.conectado; repeat: true; onTriggered: leerTareas.running = true }

    // Cola de órdenes a gcal.py (una a la vez); al terminar, avisa y refresca
    property var cola: []
    Process {
        id: escribir
        property string que: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {};
                try { r = JSON.parse(this.text); } catch (x) { r = { ok: false, error: "gcal.py no respondió" }; }
                if (r.ok === false)
                    Quickshell.execDetached(["notify-send", "-a", "Calendario", "-i", "dialog-error", "No se pudo guardar", r.error]);
                else if (escribir.que)
                    Quickshell.execDetached(["notify-send", "-a", "Calendario", "-u", "low", "-i", "x-office-calendar", escribir.que]);
            }
        }
        onExited: { ev.ocupado = false; ev.actualizar(); ev.siguiente(); }
    }
    function siguiente() {
        if (escribir.running || cola.length === 0) return;
        const [orden, aviso] = cola[0]; cola = cola.slice(1);
        ocupado = true; escribir.que = aviso;
        escribir.command = ["python3", "-I", gcal, ...orden];
        escribir.running = true;
    }
    function encolar(orden, aviso) { cola = [...cola, [orden, aviso]]; siguiente(); }

    function iso(f) { return `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, "0")}-${String(f.getDate()).padStart(2, "0")}`; }
    function diaTexto(f) {
        const hoy = new Date(), man = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() + 1);
        return f.toDateString() === hoy.toDateString() ? "hoy" : f.toDateString() === man.toDateString() ? "mañana"
             : f.toLocaleDateString(Qt.locale("es_ES"), "dddd d MMM");
    }
    // fecha: Date · hora: "HH:MM" o "" (todo el día) · minutos: duración
    function crearEvento(titulo, fecha, hora, minutos) {
        encolar(["evento", titulo, iso(fecha), hora || "", String(minutos || 60)],
                `Evento: ${titulo} · ${diaTexto(fecha)}${hora ? " " + hora : " (todo el día)"}`);
    }
    function crearTarea(titulo, fecha) {
        encolar(["tarea", titulo, fecha ? iso(fecha) : ""], `Tarea: ${titulo}`);
    }
    function completar(id) {
        tareas = tareas.filter(t => t.id !== id);          // se quita ya; si falla, vuelve al refrescar
        encolar(["hecha", id], "");
    }
    function conectar() {
        Quickshell.execDetached(["sh", "-c", `python3 -I "$1" conectar >/dev/null; notify-send -a Calendario -i x-office-calendar ` +
            `"$(python3 -I "$1" estado | grep -q '"conectado": true' && echo 'Google Calendar conectado' || echo 'No se pudo conectar')"`, "_", gcal]);
        reintento.restart();
    }
    Timer { id: reintento; interval: 5000; repeat: true; property int veces: 0
            onTriggered: { verEstado.running = true; if (ev.conectado || ++veces > 60) { stop(); veces = 0; } } }

    // «mañana 15:00 dentista» · «viernes 9am clase» · «14/11 entregar informe» · «dentista» (hoy)
    // → { fecha: Date, hora: "HH:MM" | "", titulo } o null
    function interpretar(s) {
        s = s.trim();
        const hoy = new Date(); let f = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate()), m;
        const dias = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
        const sinTilde = x => x.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
        if ((m = s.match(/^(hoy|pasado\s+mañana|mañana)\s+/i))) {
            f.setDate(f.getDate() + (/^hoy/i.test(m[1]) ? 0 : /^pasado/i.test(m[1]) ? 2 : 1)); s = s.slice(m[0].length);
        } else if ((m = s.match(/^(?:el\s+)?(\S+)\s+/)) && dias.map(sinTilde).includes(sinTilde(m[1]))) {
            const d = dias.map(sinTilde).indexOf(sinTilde(m[1]));
            f.setDate(f.getDate() + ((d - f.getDay() + 7) % 7 || 7)); s = s.slice(m[0].length);
        } else if ((m = s.match(/^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\s+/))) {
            const a = m[3] ? (+m[3] < 100 ? 2000 + +m[3] : +m[3]) : hoy.getFullYear();
            f = new Date(a, +m[2] - 1, +m[1]);
            if (!m[3] && f < new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())) f.setFullYear(a + 1);
            if (f.getDate() !== +m[1]) return null;
            s = s.slice(m[0].length);
        }
        let hora = "";
        s = s.replace(/^a\s+las?\s+/i, "");
        if ((m = s.match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?=\s|$)/i)) && (m[2] || m[3])) {
            let h = +m[1]; const mi = +(m[2] || 0), ap = (m[3] || "").toLowerCase();
            if (ap === "pm" && h < 12) h += 12;
            if (ap === "am" && h === 12) h = 0;
            if (h > 23 || mi > 59) return null;
            hora = `${String(h).padStart(2, "0")}:${String(mi).padStart(2, "0")}`;
            s = s.slice(m[0].length);
        }
        const titulo = s.trim();
        return titulo ? { fecha: f, hora: hora, titulo: titulo } : null;
    }

    // ¿Hay eventos ese día? (para el puntito del calendario)
    function hayEn(fecha) {
        const d0 = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate()), d1 = new Date(d0.getTime() + 86400000);
        return lista.some(e => e.inicio < d1 && e.fin > d0);
    }
    // Los próximos n (los de todo el día de hoy incluidos)
    function proximos(n) {
        const ahora = new Date(), hoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
        return lista.filter(e => e.todoDia ? e.fin > hoy : e.fin > ahora).slice(0, n);
    }
    function cuando(e) {
        const hoy = new Date(), man = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() + 1);
        const dia = e.inicio.toDateString() === hoy.toDateString() ? "Hoy"
                  : e.inicio.toDateString() === man.toDateString() ? "Mañana"
                  : e.inicio.toLocaleDateString(Qt.locale("es_ES"), "ddd d");
        return e.todoDia ? dia : `${dia} ${Qt.formatTime(e.inicio, "HH:mm")}`;
    }

    // Aviso 10 min antes
    Timer {
        interval: 30000; running: true; repeat: true
        onTriggered: {
            const ahora = Date.now();
            for (const e of ev.lista) {
                if (e.todoDia) continue;
                const falta = e.inicio.getTime() - ahora, clave = e.inicio.getTime() + e.titulo;
                if (falta > 0 && falta <= 10 * 60000 && !ev.avisados[clave]) {
                    const a = Object.assign({}, ev.avisados); a[clave] = true; ev.avisados = a;
                    Quickshell.execDetached(["notify-send", "-a", "Calendario", "-i", "x-office-calendar",
                        `En ${Math.round(falta / 60000)} min: ${e.titulo}`, `${Qt.formatTime(e.inicio, "HH:mm")}${e.lugar ? " · " + e.lugar : ""}`]);
                }
            }
        }
    }
}
