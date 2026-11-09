// Cargador: reacciona al enchufar / desenchufar el portátil.
//   Desenchufar → perfil "Ahorro de energía" + sin blur ni sombras (modulos/bateria.lua)
//   Enchufar    → vuelve el perfil que tenías antes + apariencia normal
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
    }
    function alEnchufar() {
        sh(`powerprofilesctl set ${c.perfilAntes}`);
        sh("hyprctl dispatch 'bateria.normal() or hl.dsp.no_op()'");
        sh("qs ipc call osd mensaje 'Cargando · modo normal' f0084");
    }

    Process {
        id: leerPerfil
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p && p !== "power-saver") c.perfilAntes = p;   // si ya estaba en ahorro, recuerda el último normal
                Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"]);
            }
        }
    }

    onConBateriaChanged: conBateria ? alDesenchufar() : alEnchufar()
}
