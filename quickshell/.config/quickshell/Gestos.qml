// Gestos: los gestos del touchpad MIENTRAS ocurren (Hyprland solo avisa al terminar).
// Lee `libinput debug-events` solo del touchpad. Hace falta instalar/gestos.sh una vez (libinput-tools y
// acceso de la sesión SOLO al touchpad); sin eso, disponible = false y nadie nota nada.
// Hyprland sigue haciendo lo suyo con el mismo gesto (cambiar de espacio, abrir Brújula…); esto solo
// permite que lo visual siga al dedo: Panorama.qml (3 dedos a los lados) y CapaTirador.qml (3 dedos abajo).
//   Gestos.activo · dedos · eje ("" | "h" | "v") · dx, dy (acumulados, + = derecha / abajo)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: g
    property bool disponible: false
    property string dispositivo: ""
    property bool activo: false
    property int dedos: 0
    property string eje: ""
    property real dx: 0
    property real dy: 0
    property bool cancelado: false
    signal empezo()
    signal termino()

    // Busca el touchpad legible y que libinput esté; si no, vuelve a mirar cada 30 s (tras instalar/gestos.sh)
    Process {
        id: buscar
        running: true
        command: ["sh", "-c",
            'command -v libinput >/dev/null && command -v stdbuf >/dev/null || exit 0; ' +
            'for e in /sys/class/input/event*; do grep -qi touchpad "$e/device/name" 2>/dev/null || continue; ' +
            'd="/dev/input/${e##*/}"; [ -r "$d" ] && { echo "$d"; exit 0; }; done'];
        stdout: StdioCollector {
            onStreamFinished: {
                g.dispositivo = text.trim();
                g.disponible = g.dispositivo !== "";
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: !g.disponible; onTriggered: buscar.running = true }

    Process {
        id: lector
        running: g.disponible
        command: ["stdbuf", "-oL", "libinput", "debug-events", "--device", g.dispositivo]
        stdout: SplitParser {
            onRead: (l) => {
                const m = l.match(/GESTURE_SWIPE_(BEGIN|UPDATE|END)\s+\+?[\d.]+s\s+(\d+)\s*(.*)$/);
                if (!m) return;
                if (m[1] === "BEGIN") {
                    g.dedos = +m[2]; g.dx = 0; g.dy = 0; g.eje = ""; g.cancelado = false; g.activo = true;
                    g.empezo();
                } else if (m[1] === "UPDATE" && g.activo) {
                    const d = m[3].match(/(-?[\d.]+)\/\s*(-?[\d.]+)/);
                    if (!d) return;
                    g.dx += +d[1]; g.dy += +d[2];
                    // Como Hyprland: el eje lo decide el primer tramo del movimiento
                    if (g.eje === "" && Math.abs(g.dx) + Math.abs(g.dy) > 12) g.eje = Math.abs(g.dx) > Math.abs(g.dy) ? "h" : "v";
                } else if (m[1] === "END" && g.activo) {
                    g.cancelado = m[3].indexOf("cancelled") >= 0;
                    g.activo = false;
                    g.termino();
                }
            }
        }
        // Si libinput se cierra (touchpad desconectado, permisos…), se vuelve a buscar
        onExited: { g.activo = false; g.disponible = false; reintentar.restart(); }
    }
    Timer { id: reintentar; interval: 5000; onTriggered: buscar.running = true }
}
