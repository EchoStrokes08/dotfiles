// Cargador: reacciona al enchufar / desenchufar el portátil.
//   Desenchufar → perfil "Ahorro de energía" + sin blur ni sombras (modulos/bateria.lua) + bloqueo a los 5 min
//   Enchufar    → vuelve el perfil que tenías antes + apariencia normal + bloqueo a los 10 min
// Solo actúa en el CAMBIO: si con batería eliges otro perfil a mano, se respeta.
//   qs ipc call cargador estado      → "batería" / "cargador"   (el IpcHandler está en shell.qml)
//   qs ipc call cargador simular bat → prueba sin desenchufar (o "ac")
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: c
    readonly property bool conBateria: UPower.onBattery
    property string perfilAntes: "balanced"     // el perfil que había al desenchufar

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    function alDesenchufar() {
        leerPerfil.running = true;   // guarda el actual y luego pone ahorro (ver abajo)
        sh("hyprctl dispatch 'bateria.ahorro() or hl.dsp.no_op()'");
        sh("qs ipc call osd mensaje 'Batería · modo ahorro' f0079");
        sh("~/.config/hypr/scripts/inactividad.sh bateria");   // inactividad más corta
    }
    function alEnchufar() {
        sh(`powerprofilesctl set ${c.perfilAntes}`);
        sh("hyprctl dispatch 'bateria.normal() or hl.dsp.no_op()'");
        sh("qs ipc call osd mensaje 'Cargando · modo normal' f0084");
        sh("~/.config/hypr/scripts/inactividad.sh red");
    }

    Process {
        id: leerPerfil
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p && p !== "power-saver") c.perfilAntes = p;   // si ya estaba en ahorro, recuerda el último normal
                // Jugando (gamemode activo) no se baja a ahorro: lo devuelve juego-energia.sh al terminar
                c.sh("gamemoded -s 2>/dev/null | grep -q 'is active' || powerprofilesctl set power-saver");
            }
        }
    }

    onConBateriaChanged: conBateria ? alDesenchufar() : alEnchufar()

    // Al arrancar, onConBateriaChanged no se dispara: el perfil queda como lo dejó el arranque
    // (típicamente power-saver) aunque estés enchufado. Fijamos el perfil correcto según el
    // estado real del cargador. Enchufado → el último perfil normal (perfilAntes); con batería → ahorro.
    // Jugando no se toca (gamemode manda).
    Component.onCompleted: {
        if (c.conBateria)
            c.sh("gamemoded -s 2>/dev/null | grep -q 'is active' || powerprofilesctl set power-saver");
        else
            c.sh(`gamemoded -s 2>/dev/null | grep -q 'is active' || powerprofilesctl set ${c.perfilAntes}`);
    }
}
