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
    property string errorTareas: ""
    property string enlaceTareas: ""   // p. ej. la página de Google Cloud para activar la API
    property string codigoTareas: ""   // código de gcal.py: sin_permiso (sesión caducada), sin_conectar…
    readonly property bool reconectando: conectarProc.running
    // La sesión de Google caducó o nunca se conectó: hay que volver a dar permiso en el navegador
    readonly property bool necesitaConectar: hayCliente && (!conectado || codigoTareas === "sin_permiso" || codigoTareas === "sin_conectar")
    property bool ocupado: false      // guardando algo
    property string estadoAgenda: "cargando"
    property string errorAgenda: ""
    property real sincronizadoEn: 0
    readonly property bool leyendo: leer.running
    readonly property string gcal: Quickshell.env("HOME") + "/.config/hypr/scripts/gcal.py"

    Process {
        id: leer
        property bool respondio: false
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/hypr/scripts/eventos.py", "--estado"]
        onRunningChanged: if (running) respondio = false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    if (!Array.isArray(r.eventos) || !["actualizado", "desactualizado", "sin_configurar", "error"].includes(r.estado))
                        throw new Error("Respuesta no válida");
                    const datos = r.eventos.map(e => ({ inicio: new Date(e.inicio), fin: new Date(e.fin),
                        titulo: e.titulo, lugar: e.lugar, todoDia: e.todoDia, uid: e.uid, calendario:e.calendario || "", serie:e.serie || "", ocurrencia:e.ocurrencia || e.inicio, repeticion:e.repeticion || "", excepcion:!!e.excepcion }));
                    if (datos.some(e => isNaN(e.inicio.getTime()) || isNaN(e.fin.getTime()))) throw new Error("Fecha no válida");
                    // Un fallo sin caché no borra una agenda válida que aún vive en memoria.
                    if (r.estado !== "error" || !ev.lista.length) ev.lista = datos;
                    ev.estadoAgenda = r.estado;
                    ev.errorAgenda = r.error || "";
                    if (r.actualizado) ev.sincronizadoEn = r.actualizado;
                    else if (r.estado === "sin_configurar") ev.sincronizadoEn = 0;
                    leer.respondio = true;
                } catch (e) { ev.falloLectura(); }
            }
        }
        onExited: (codigo, estadoSalida) => { if (codigo !== 0 || estadoSalida !== 0 || !respondio) ev.falloLectura(); }
    }
    function falloLectura() {
        estadoAgenda = sincronizadoEn ? "desactualizado" : "error";
        errorAgenda = "No se pudo leer la agenda. Reintenta la sincronización.";
    }
    Timer { interval: 15 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!leer.running) leer.running = true }
    function actualizar() { if (!leer.running) leer.running = true; if (conectado && !leerTareas.running) leerTareas.running = true; }

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
                    if (!Array.isArray(l)) {
                        // gcal.py explica el fallo: causa, qué hacer y, si existe, dónde hacerlo
                        // sesión caducada o sin conectar: el botón «Reconectar Google» lo resuelve (no hace falta la terminal)
                        const ayuda = ["sin_permiso", "sin_conectar"].includes(l?.codigo) ? "Pulsa «Reconectar Google»." : (l?.ayuda || "").replace(/([^.])$/, "$1.");
                        ev.errorTareas = (l?.error || "Las tareas no se pudieron actualizar") + "."
                            + (ayuda ? " " + ayuda : "") + " Se conservan los últimos datos.";
                        ev.enlaceTareas = l?.enlace || "";
                        ev.codigoTareas = l?.codigo || "";
                        return;
                    }
                    ev.errorTareas=""; ev.enlaceTareas=""; ev.codigoTareas="";
                    ev.tareas = l.map(t => ({ id: t.id, titulo: t.titulo,
                        fecha: t.fecha ? new Date(+t.fecha.slice(0, 4), +t.fecha.slice(5, 7) - 1, +t.fecha.slice(8, 10)) : null }));
                } catch (x) { ev.errorTareas="Las tareas no se pudieron actualizar. Se conservan los últimos datos."; }
            }
        }
    }
    Timer { interval: 15 * 60000; running: ev.conectado; repeat: true; onTriggered: leerTareas.running = true }

    // Volver a iniciar sesión: gcal.py conectar abre el navegador y espera el permiso (hasta 5 min)
    Process {
        id: conectarProc
        command: ["python3", "-I", ev.gcal, "conectar"]
        property var respuesta: null
        stdout: StdioCollector { onStreamFinished: { try { conectarProc.respuesta = JSON.parse(text); } catch (x) { conectarProc.respuesta = null; } } }
        onExited: (codigo, estado) => {
            const r = respuesta;
            if (codigo === 0 && estado === 0 && r?.ok === true) {
                Quickshell.execDetached(["notify-send", "-a", "Calendario", "Cuenta de Google conectada", "Las tareas y el calendario vuelven a sincronizarse."]);
                ev.codigoTareas = ""; ev.errorTareas = "";
                verEstado.running = true;
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Calendario", "No se pudo conectar Google", r?.error || "Vuelve a intentarlo."]);
            }
        }
    }
    function conectar() {
        if (conectarProc.running) return;
        conectarProc.respuesta = null;
        conectarProc.running = true;
    }

    // Cola de órdenes a gcal.py (una a la vez); al terminar, avisa y refresca
    property var cola: []
    Process {
        id: escribir
        property string que: ""
        property var respuesta: null
        stdout: StdioCollector { onStreamFinished: { try { escribir.respuesta=JSON.parse(text); } catch(x) { escribir.respuesta=null; } } }
        onExited: (codigo,estado) => {
            const r=respuesta;
            if (codigo!==0 || estado!==0 || r?.ok !== true) Quickshell.execDetached(["notify-send","-a","Calendario","No se pudo guardar",r?.error || "No se pudo confirmar la operación. Reintenta."]);
            else if (que) Quickshell.execDetached(["notify-send","-a","Calendario",que]);
            ev.ocupado=false;ev.actualizar();Qt.callLater(ev.siguiente);
        }
    }
    function siguiente() {
        if (escribir.running || cola.length === 0) return;
        const [orden, aviso] = cola[0]; cola = cola.slice(1);
        ocupado = true; escribir.respuesta=null; escribir.que = aviso;
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
        encolar(["hecha", id], "");
    }
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
    // Punto del calendario: algo distinto de la rutina diaria ese día
    function marcaEn(fecha) {
        const d0 = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate()), d1 = new Date(d0.getTime() + 86400000);
        return lista.some(e => e.inicio < d1 && e.fin > d0 && e.repeticion !== "diario")
            || tareas.some(t => t.fecha && t.fecha.getTime() === d0.getTime());
    }
    // Qué hay ese día, por separado: { eventos, tareas } (el calendario pinta un punto de cada color)
    function marcasEn(fecha) {
        const d0 = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate()), d1 = new Date(d0.getTime() + 86400000);
        return { eventos: lista.some(e => e.inicio < d1 && e.fin > d0 && e.repeticion !== "diario"),
                 tareas: tareas.some(t => t.fecha && t.fecha.getTime() === d0.getTime()) };
    }
    // Los próximos n (los de todo el día de hoy incluidos)
    function proximos(n) {
        const ahora = new Date(), hoy = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
        const vistos = new Set();
        return lista.filter(e => e.todoDia ? e.fin > hoy : e.fin > ahora).filter(e => {
            const clave=e.serie && !e.excepcion ? e.serie : [e.calendario,e.uid,e.ocurrencia].join(":");
            if (!e.uid && !e.serie) return true;
            if (vistos.has(clave)) return false;
            vistos.add(clave); return true;
        }).slice(0,n);
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
                const falta = e.inicio.getTime() - ahora, clave = [e.calendario,e.uid,e.ocurrencia,e.inicio.getTime()].join(":");
                if (falta > 0 && falta <= 10 * 60000 && !ev.avisados[clave]) {
                    const a = Object.assign({}, ev.avisados); a[clave] = true; ev.avisados = a;
                    Quickshell.execDetached(["notify-send", "-a", "Calendario", "-i", "x-office-calendar",
                        `En ${Math.round(falta / 60000)} min: ${e.titulo}`, `${Qt.formatTime(e.inicio, "HH:mm")}${e.lugar ? " · " + e.lugar : ""}`]);
                }
            }
        }
    }
}
