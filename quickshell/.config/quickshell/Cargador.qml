// Cargador: reacciona al enchufar / desenchufar el portátil.
//   Desenchufar → perfil "Ahorro de energía" + sin blur ni sombras (modulos/bateria.lua) + bloqueo a los 5 min
//   Enchufar    → vuelve el perfil que tenías antes + apariencia normal + bloqueo a los 10 min
// Solo actúa en el CAMBIO: si con batería eliges otro perfil a mano, se respeta.
//   qs ipc call cargador estado      → "batería" / "cargador"   (el IpcHandler está en shell.qml)
//   qs ipc call cargador simular bat → prueba sin desenchufar (o "ac")
// Avisos de batería (CapaBateria.qml dibuja el borde, la isla lo dice):
//   20 % ámbar · 10 % rojo · 5 % o menos: resplandor rojo que respira hasta enchufar
//   cargada (al 80 % con el modo conservación, o al 100 %): una vez por enchufada, «ya puedes desenchufar»
//   qs ipc call bateria probar 20 | 10 | 5 | llena   (solo el efecto)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: c
    readonly property bool conBateria: UPower.onBattery
    property string perfilAntes: "balanced"     // el perfil que había al desenchufar
    signal probar(bool ac)                       // solo el efecto de CapaEnergia.qml
    IpcHandler {
        target: "energia"
        function probar(modo: string): void { c.probar(modo !== "bat"); }
    }
    // ── Avisos de batería ──
    signal alerta(int nivel)                     // 20, 10, 5 = baja · 0 = cargada
    property int simulada: -1                    // qs ipc call bateria probar 5: el resplandor crítico sin estar al 5 %
    readonly property bool critica: simulada === 5 || (conBateria && porcentaje > 0 && porcentaje <= 5)
    property int avisado: 101                    // el último umbral avisado en esta descarga
    property bool cargaAvisada: false
    readonly property int estado: UPower.displayDevice?.state ?? 0
    readonly property real quedan: UPower.displayDevice?.timeToEmpty ?? 0   // segundos (0 = no se sabe)
    function tiempo(s) {
        if (s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round(s % 3600 / 60);
        return h > 0 ? `${h} h ${String(m).padStart(2, "0")} min` : `${m} min`;
    }
    function avisar(nivel, simulado) {
        const pct = simulado ? nivel : porcentaje;
        if (nivel === 0) {
            Isla.mostrar(String.fromCodePoint(0xF17E2), -1, `Cargada al ${simulado ? 80 : porcentaje} % · ya puedes desenchufar`, false, 3200);
        } else {
            const resto = tiempo(simulado ? nivel * 420 : quedan);
            Isla.mostrar(String.fromCodePoint(nivel <= 5 ? 0xF10CD : nivel <= 10 ? 0xF007A : 0xF007B), -1,
                         `Batería al ${pct} %` + (resto ? ` · quedan ${resto}` : ""), false, nivel <= 10 ? 4200 : 3200);
        }
        alerta(nivel);
    }
    function comprobar() {
        if (!UPower.displayDevice?.isLaptopBattery) return;
        if (!conBateria) {
            avisado = 101;
            const llena = estado === UPowerDeviceState.FullyCharged || estado === UPowerDeviceState.PendingCharge;
            if (llena && !cargaAvisada && porcentaje >= 60) { cargaAvisada = true; avisar(0, false); }
            return;
        }
        cargaAvisada = false;
        for (const u of [5, 10, 20]) {
            if (porcentaje <= u && avisado > u) { avisado = u; avisar(u, false); return; }
        }
    }
    onPorcentajeChanged: Qt.callLater(comprobar)
    onEstadoChanged: Qt.callLater(comprobar)
    // al arrancar o recargar no se avisa de lo que ya pasaba (ni de la carga ya completa): ver Component.onCompleted
    IpcHandler {
        target: "bateria"
        function probar(nivel: string): void {
            const n = nivel === "llena" ? 0 : parseInt(nivel) || 20;
            c.simulada = n === 5 ? 5 : -1;
            c.avisar(n, true);
            if (n === 5) finSimulada.restart();
        }
    }
    Timer { id: finSimulada; interval: 9000; onTriggered: c.simulada = -1 }

    readonly property int porcentaje: {
        const b = UPower.displayDevice;
        return Math.round(b ? (b.percentage > 1 ? b.percentage : b.percentage * 100) : 0);
    }

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
        sh(`qs ipc call osd mensaje 'Cargando · ${c.porcentaje} %' f0084`);
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
        c.cargaAvisada = !c.conBateria && (c.estado === UPowerDeviceState.FullyCharged || c.estado === UPowerDeviceState.PendingCharge);
        c.avisado = c.conBateria ? [5, 10, 20, 101].find(u => c.porcentaje <= u) : 101;
        if (c.conBateria)
            c.sh("gamemoded -s 2>/dev/null | grep -q 'is active' || powerprofilesctl set power-saver");
        else
            c.sh(`gamemoded -s 2>/dev/null | grep -q 'is active' || powerprofilesctl set ${c.perfilAntes}`);
    }
}
