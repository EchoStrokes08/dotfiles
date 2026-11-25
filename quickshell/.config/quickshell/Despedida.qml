// Despedida: el apagado cinematográfico, el cierre de la bienvenida (CapaDespedida.qml lo dibuja).
//   Despedida.hacer(comando, tipo)   tipo: "apagar" · "reiniciar" · "salir" (cerrar sesión)
// Espera a que se vaya el menú, captura la pantalla (como el bloqueo, en $XDG_RUNTIME_DIR), la aleja
// hasta el negro mientras la isla se despide y DESPUÉS ejecuta el comando. Sin movimiento: directo.
//   qs ipc call despedida probar   → la animación entera sin apagar nada
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: d
    property bool activa: false
    property string tipo: ""
    property var comando: []
    property var capturas: ({})          // nombre del monitor → captura
    property int numero: 0
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") || ""

    readonly property string mensaje: {
        const h = new Date().getHours(), noche = h >= 20 || h < 5;
        const u = Quickshell.env("USER") || "";
        const base = tipo === "reiniciar" ? "Vuelvo enseguida" : tipo === "salir" ? "Hasta pronto" : noche ? "Hasta mañana" : "Hasta luego";
        return base + (u ? ", " + u.charAt(0).toUpperCase() + u.slice(1) : "");
    }

    function hacer(cmd, t) {
        if (activa || capturador.running || antes.running) return;
        if (!EstiloPanel.movimiento || dir === "") { if (cmd.length) Quickshell.execDetached(cmd); return; }
        comando = cmd; tipo = t ?? "apagar";
        antes.restart();                 // a que el menú de apagado termine de irse
    }
    Timer {
        id: antes; interval: 260
        onTriggered: {
            capturador.command = ["sh", "-c",
                'umask 077; d="$1"; shift; for o; do grim -o "$o" -t ppm "$d/despedida-$o.ppm" 2>/dev/null && printf "%s\\n" "$o"; done',
                "sh", d.dir, ...Quickshell.screens.map(p => p.name)];
            capturador.running = true;
        }
    }
    Process {
        id: capturador
        stdout: StdioCollector {
            onStreamFinished: {
                const c = {};
                for (const o of text.split("\n").filter(x => x !== "")) c[o] = d.dir + "/despedida-" + o + ".ppm";
                d.capturas = c; d.numero++; d.activa = true;
                final.restart();
            }
        }
    }
    // La animación dura ~1,6 s (CapaDespedida); entonces, la acción
    Timer {
        id: final; interval: 1700
        onTriggered: {
            if (d.comando.length) Quickshell.execDetached(d.comando);
            else { d.activa = false; d.capturas = {}; }          // prueba: vuelve todo
            Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/despedida-*.ppm', "sh", d.dir]);
        }
    }
}
