// Un estado compartido por todas las barras; eventos y resincronización al reconectar.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: modo
    property string actual: ""
    property int revision: 0
    readonly property bool activo: actual !== ""
    readonly property string nombre: actual === "redimensionar" ? "Redimensionar" : actual === "lanzar" ? "Lanzar" : actual
    readonly property string ayuda: actual === "redimensionar" ? "Flechas: tamaño · Esc o Enter: salir"
        : actual === "lanzar" ? "F navegador · T terminal · E archivos · W WhatsApp · G juego · S música · N Nebula · I impresora · Esc: salir"
        : "Esc: salir del modo de teclado"
    function recibir(nombre) {
        revision++;
        actual = nombre === "reset" || nombre === "default" ? "" : nombre.trim();
    }
    function sincronizar() {
        if (!consulta.running) { consulta.revision = revision; consulta.running = true; }
    }
    function salir() { Hyprland.dispatch('hl.dsp.submap("reset")'); }
    Socket {
        id: eventos
        path: Hyprland.eventSocketPath
        connected: true
        onConnectionStateChanged: {
            if (connected) modo.sincronizar();
            else modo.recibir("");
        }
        parser: SplitParser {
            onRead: (linea) => { if (linea.startsWith("submap>>")) modo.recibir(linea.slice(8)); }
        }
    }
    Timer {
        interval: 3000
        running: !eventos.connected
        repeat: true
        onTriggered: eventos.connected = true
    }
    Process {
        id: consulta
        property int revision: 0
        property string resultado: ""
        // Hyprland 0.57: la consulta antigua «hyprctl submap» se sustituyó por la API Lua.
        command: ["hyprctl", "repl", "hl.get_current_submap()"]
        stdout: StdioCollector { onStreamFinished: consulta.resultado = text.trim() }
        onExited: (codigo, estadoSalida) => {
            if (codigo === 0 && estadoSalida === 0 && revision === modo.revision)
                modo.recibir(resultado);
            else if (revision !== modo.revision && eventos.connected) Qt.callLater(modo.sincronizar);
        }
    }
    Timer { interval: 5000; running: consulta.running; onTriggered: consulta.running = false }
}
