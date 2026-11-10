// Audífonos: complemento de Buds Manager (que ya pausa/reanuda por el sensor de oreja y cambia la
// salida entre audífonos y bocinas). Esto cubre el hueco que él no ve: si los audífonos Bluetooth se
// DESCONECTAN sin salir de la oreja (sin batería, fuera de alcance) mientras algo suena por ellos,
// pausa la música para que no salga de golpe por las bocinas. No reanuda: eso lo hace Buds Manager.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

Singleton {
    id: a
    // salidas Bluetooth (bluez_output.*) y el ecualizador de Buds Manager (buds_pceq.*)
    function esAudifono(n) { return !!n && /^(bluez_output|buds_pceq)\./.test(n.name ?? ""); }
    readonly property bool hayAudifonos: Pipewire.nodes.values.some(n => n.isSink && !n.isStream && a.esAudifono(n))
    property bool sonabaEnAudifonos: false      // se actualiza cada 2 s mientras están

    // Mejora de sonido (EasyEffects, scripts/sonido.sh): los perfiles son para las bocinas. Al cambiar
    // la salida se le avisa y él decide si aplica los efectos (bocinas) o los salta (audífonos).
    readonly property string salida: Pipewire.defaultAudioSink?.name ?? ""
    onSalidaChanged: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/sonido.sh", "salida"])

    Timer {
        interval: 2000; running: a.hayAudifonos; repeat: true; triggeredOnStart: true
        onTriggered: a.sonabaEnAudifonos = a.esAudifono(Pipewire.defaultAudioSink) && Mpris.players.values.some(p => p.isPlaying)
    }
    onHayAudifonosChanged: {
        if (hayAudifonos || !sonabaEnAudifonos) return;
        sonabaEnAudifonos = false;
        for (const p of Mpris.players.values) if (p.isPlaying && p.canPause) p.pause();
        Quickshell.execDetached(["qs", "ipc", "call", "osd", "mensaje", "Audífonos desconectados · música en pausa", "f02cb"]);
    }
}
