// Modo concentración: temporizador + No molestar + apps que distraen escondidas.
//   SUPER+SHIFT+F → menú (25 / 50 / 90 min; si ya hay sesión: +10 min o terminar)
//   La barra muestra la cuenta atrás; clic en ella = el mismo menú.
// Esconder/devolver ventanas lo hace Hyprland: ~/.config/hypr/modulos/concentracion.lua
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: raiz

    // Sobrevive a recargas de Quickshell (la hora de fin es absoluta, no un contador)
    PersistentProperties {
        id: p
        reloadableId: "concentracion"
        property bool activo: false
        property real fin: 0              // Date.now() en que termina
        property int minutos: 0
        property int sesionesHoy: 0
        property string dia: ""
    }
    readonly property bool activo: p.activo
    readonly property int minutos: p.minutos
    readonly property int sesionesHoy: p.dia === new Date().toDateString() ? p.sesionesHoy : 0
    property real restante: 0             // segundos

    function texto() {
        const s = Math.max(0, Math.round(restante));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    function empezar(min) {
        p.minutos = min;
        p.fin = Date.now() + min * 60000;
        p.activo = true;
        restante = min * 60;
        Hyprland.dispatch("concentracion.empezar() or hl.dsp.no_op()");
        sh(`qs ipc call osd mensaje "Concentración: ${min} min" f04fe`);
    }
    function sumar(min) {
        if (!p.activo) return;
        p.fin += min * 60000;
        sh(`qs ipc call osd mensaje "+${min} min" f04fe`);
    }
    function terminar(completada) {
        if (!p.activo) return;
        p.activo = false;
        Hyprland.dispatch("concentracion.terminar() or hl.dsp.no_op()");
        if (completada) {
            const hoy = new Date().toDateString();
            if (p.dia !== hoy) { p.dia = hoy; p.sesionesHoy = 0; }
            p.sesionesHoy++;
            sh(`notify-send -a "Concentración" -i alarm-symbolic "¡Sesión terminada!" "${p.minutos} min de concentración · ${p.sesionesHoy} hoy. Tus apps han vuelto a su sitio."; ` +
               "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null");
        } else {
            sh(`qs ipc call osd mensaje "Concentración terminada" f04fe`);
        }
    }

    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: p.activo
        onTriggered: {
            raiz.restante = (p.fin - Date.now()) / 1000;
            if (raiz.restante <= 0) raiz.terminar(true);
        }
    }
}
