// Recordatorios: «recordar 20m entregar el taller» en el lanzador (SUPER+R).
// Se guardan en ~/.local/state/quickshell/recordatorios.json (sobreviven a reinicios: si el equipo
// estaba apagado a la hora, avisa al encender). Aviso = notificación crítica + sonido.
// Los próximos se ven en el dashboard (clic en uno = borrarlo).
//   qs ipc call recordatorios agregar "20m beber agua" · lista · borrar <id>
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: r
    property var lista: []            // [{ id, cuando (ms), texto }] ordenada por hora

    // OJO: un FileView de un singleton que apunta a un archivo que NO existe deja la carga pendiente y
    // bloquea TODO el IPC de Quickshell ("Not ready to accept queries yet"). Por eso primero se crea el
    // archivo (si falta) y solo después se le da la ruta al FileView.
    readonly property string ruta: Quickshell.env("HOME") + "/.local/state/quickshell/recordatorios.json"
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")"; [ -s "$1" ] || echo "[]" > "$1"', "_", r.ruta]
        onExited: archivo.path = r.ruta
    }
    FileView {
        id: archivo
        onLoaded: { try { r.lista = JSON.parse(text()); } catch (e) { r.lista = []; } }
    }
    function guardar(l) {
        lista = l.slice().sort((a, b) => a.cuando - b.cuando);
        archivo.setText(JSON.stringify(lista, null, 1));
    }

    function agregar(cuando, texto) {
        guardar([...lista, { id: String(Date.now()), cuando: cuando, texto: texto }]);
    }
    function borrar(id) { guardar(lista.filter(x => x.id !== id)); }

    // Avisar los que ya tocan (cada 15 s; también al arrancar, por si estaba apagado)
    Timer {
        interval: 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const ahora = Date.now(), vencidos = r.lista.filter(x => x.cuando <= ahora);
            if (vencidos.length === 0) return;
            for (const x of vencidos) {
                const tarde = ahora - x.cuando > 120000 ? ` (era a las ${r.hora(x.cuando)})` : "";
                Quickshell.execDetached(["sh", "-c",
                    `notify-send -u critical -a Recordatorio -i alarm-symbolic "⏰ Recordatorio" "$1${tarde}"; ` +
                    "paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null " +
                    "|| paplay /usr/share/sounds/freedesktop/stereo/complete.oga", "_", x.texto]);
            }
            r.guardar(r.lista.filter(x => x.cuando > ahora));
        }
    }

    function hora(ms) { const d = new Date(ms); return `${d.getHours()}:${String(d.getMinutes()).padStart(2, "0")}`; }
    function cuandoTexto(ms) {
        const d = new Date(ms), hoy = new Date(), min = Math.round((ms - Date.now()) / 60000);
        const manana = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() + 1);
        const dia = d.toDateString() === hoy.toDateString() ? "hoy"
                  : d.toDateString() === manana.toDateString() ? "mañana"
                  : d.toLocaleDateString(Qt.locale("es_CO"), "ddd d MMM");
        const falta = min < 60 ? `en ${Math.max(min, 1)} min` : min < 1440 ? `en ${Math.floor(min / 60)} h ${min % 60} min` : "";
        return `${dia} ${hora(ms)}` + (falta ? ` · ${falta}` : "");
    }

    // «20m texto» · «1h30 texto» · «en 2 horas texto» · «18:30 texto» · «6pm texto» · «mañana 8:00 texto»
    // → { cuando, texto } o null si no se entiende la hora
    function interpretar(s) {
        s = s.trim().replace(/^en\s+/i, "");
        const ahora = new Date();
        let m;
        // relativo: 20m · 20 min · 45 minutos · 1h · 1h30 · 1 h 30 min · 2 horas · 90s
        m = s.match(/^(\d+)\s*(h|hr|horas?)(?:\s*(\d+)\s*(?:m|min|mins|minutos?)?)?(?=\s|$)/i)
         || s.match(/^(\d+)\s*(m|min|mins|minutos?)(?=\s|$)/i)
         || s.match(/^(\d+)\s*(s|seg|segundos?)(?=\s|$)/i);
        if (m) {
            const u = m[2][0].toLowerCase();
            const ms = u === "h" ? (+m[1] * 3600 + (+(m[3] || 0)) * 60) * 1000 : u === "m" ? +m[1] * 60000 : +m[1] * 1000;
            const texto = s.slice(m[0].length).trim();
            return ms > 0 && texto ? { cuando: Date.now() + ms, texto: texto } : null;
        }
        // absoluto: [mañana] [a las] 18:30 | 6pm | 6:30 pm  (sin «:» ni am/pm, un número solo no es hora)
        let dias = 0;
        if ((m = s.match(/^mañana\s+/i))) { dias = 1; s = s.slice(m[0].length); }
        s = s.replace(/^a\s+las?\s+/i, "");
        if ((m = s.match(/^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?=\s|$)/i)) && (m[2] || m[3])) {
            let h = +m[1]; const mi = +(m[2] || 0), ap = (m[3] || "").toLowerCase();
            if (ap === "pm" && h < 12) h += 12;
            if (ap === "am" && h === 12) h = 0;
            if (h > 23 || mi > 59) return null;
            const d = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate() + dias, h, mi);
            if (dias === 0 && d <= ahora) d.setDate(d.getDate() + 1);       // ya pasó hoy → mañana
            const texto = s.slice(m[0].length).trim();
            return texto ? { cuando: d.getTime(), texto: texto } : null;
        }
        return null;
    }
}
