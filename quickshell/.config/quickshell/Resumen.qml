// Resumen del día: la primera vez que usas el equipo cada día (a partir de las 5:00) abre Brújula › Hoy,
// que reúne el clima, la agenda, los recordatorios, el sistema y el tiempo de pantalla.
// Antes era una tarjeta aparte con lo mismo; ahora no hay dos sitios para «tu día».
//   qs ipc call resumen mostrar      (también «Resumen del día» en el lanzador)
// La fecha del último resumen se guarda en ~/.local/state/quickshell/resumen-fecha.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: r
    property bool abierto: false          // no tiene ventana propia (shell.qml lo cierra con los demás)

    SystemClock { id: reloj; precision: SystemClock.Minutes }
    readonly property string hoy: Qt.formatDate(reloj.date, "yyyy-MM-dd")

    property string ultimo: "?"            // "?" = aún no se ha leído el archivo
    readonly property string ruta: Quickshell.env("HOME") + "/.local/state/quickshell/resumen-fecha"
    Process {
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null; true', "_", r.ruta]
        stdout: StdioCollector { onStreamFinished: r.ultimo = this.text.trim() }
    }
    function mostrar() {
        ultimo = hoy;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "_", ruta, hoy]);
        Quickshell.execDetached(["qs", "ipc", "call", "brujula", "abrir", "hoy"]);
    }
    Timer {   // espera a que haya clima y calendario; después comprueba cada minuto si ya es otro día
        interval: 20000; running: true; repeat: true
        onTriggered: {
            interval = 60000;
            if (r.ultimo !== "?" && r.ultimo !== r.hoy && reloj.date.getHours() >= 5) r.mostrar();
        }
    }
}
