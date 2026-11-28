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
    onSalidaChanged: {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/sonido.sh", "salida"]);
        anuncio.restart();
    }

    // La isla dice por dónde sale ahora el sonido («Sonido por REDMI Buds 8 Pro», «… por las bocinas»).
    // Espera 0,8 s a que la salida se asiente (al conectar Bluetooth salta varias veces); no avisa al
    // arrancar, por el sink virtual de EasyEffects ni si es la misma de antes.
    property bool arrancado: false
    property string anunciada: ""
    property real pausaAvisada: 0            // la desconexión ya avisó: no pisar su mensaje
    Timer { interval: 4000; running: true; onTriggered: { a.arrancado = true; a.anunciada = a.salida; } }
    Timer {
        id: anuncio
        interval: 800
        onTriggered: {
            const n = Pipewire.defaultAudioSink;
            if (!a.arrancado || !n || n.name === a.anunciada || /^easyeffects/.test(n.name)) return;
            a.anunciada = n.name;
            if (Date.now() - a.pausaAvisada < 3000) return;
            const desc = n.description || n.nickname || n.name;
            const [ic, txt] = a.esAudifono(n) ? [0xF02CB, "Sonido por " + desc]
                : /hdmi|displayport/i.test(n.name + desc) ? [0xF0379, "Sonido por la pantalla"]
                : /headphone|auricular|usb/i.test(n.name + desc) ? [0xF02CB, "Sonido por " + desc]
                : [0xF04C3, "Sonido por las bocinas"];
            Isla.mostrar(String.fromCodePoint(ic), -1, txt);
        }
    }

    Timer {
        interval: 2000; running: a.hayAudifonos; repeat: true; triggeredOnStart: true
        onTriggered: a.sonabaEnAudifonos = a.esAudifono(Pipewire.defaultAudioSink) && Mpris.players.values.some(p => p.isPlaying)
    }
    onHayAudifonosChanged: {
        if (hayAudifonos || !sonabaEnAudifonos) return;
        sonabaEnAudifonos = false;
        pausaAvisada = Date.now();
        for (const p of Mpris.players.values) if (p.isPlaying && p.canPause) p.pause();
        Quickshell.execDetached(["qs", "ipc", "call", "osd", "mensaje", "Audífonos desconectados · música en pausa", "f02cb"]);
    }
}
