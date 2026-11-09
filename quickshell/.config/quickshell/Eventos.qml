// Eventos de Google Calendar (scripts/eventos.py, cada 15 min). El dashboard marca los días con
// eventos en el calendario y enseña los próximos; 10 min antes de cada evento con hora, avisa.
// La dirección del calendario está en ~/.config/calendario/url (privada, fuera del repo).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ev
    property var lista: []            // [{ inicio: Date, fin: Date, titulo, lugar, todoDia }]
    property var avisados: ({})       // eventos ya avisados (inicio+título), para no repetir

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
    function actualizar() { leer.running = true; }

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
