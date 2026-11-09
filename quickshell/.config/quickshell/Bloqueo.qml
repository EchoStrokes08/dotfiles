// Bloqueo: la pantalla de bloqueo propia (sustituye a hyprlock, que queda de respaldo).
//
//   qs ipc call bloqueo bloquear   → bloquea (lo usa hypridle: lock_cmd, SUPER+L, antes de suspender)
//   qs ipc call bloqueo probar     → bloquea 12 s y se desbloquea solo (para ver el diseño sin riesgo)
//
// La contraseña la comprueba PAM con /etc/pam.d/hyprlock, igual que hyprlock.
//
// Envío automático: la clave se comprueba sola al llegar a su número de caracteres, sin Enter.
// La longitud se APRENDE sola: cada desbloqueo correcto guarda cuántos caracteres tenía la clave
// en ~/.local/state/bloqueo/longitud (fuera de dotfiles: el repo es público). Nunca se guarda la clave.
// Si cambias de contraseña:
//   · más corta → no se envía sola; pulsa Enter una vez y aprende la nueva longitud.
//   · más larga → se envía sola a la longitud vieja y falla; desde ese fallo el envío automático
//     se apaga hasta el siguiente bloqueo. Escríbela entera + Enter y aprende la nueva longitud.
// SI ALGO FALLA y no puedes escribir: Ctrl+Alt+F3, entra, y ejecuta
//   ~/.config/hypr/scripts/desbloqueo-emergencia.sh       (lanza hyprlock en su lugar)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: bloqueo

    // Estado compartido por todas las pantallas
    property string clave: ""
    property bool comprobando: false
    property bool error: false
    property int intentos: 0
    property bool saliendo: false        // animación de salida antes de soltar el bloqueo
    property bool bloqMayus: false
    property int longitudClave: 0        // aprendida; 0 = aún no se sabe (usa Enter)
    property bool autoEnvio: true        // se apaga tras un envío automático fallido
    property bool ultimoFueAuto: false
    property int longitudEnviada: 0

    // Validador: en cuanto la clave tiene la longitud aprendida, se envía como si fuera Enter
    onClaveChanged: {
        if (autoEnvio && longitudClave > 0 && clave.length === longitudClave) enviar(true);
    }
    readonly property string dirEstado: Quickshell.env("HOME") + "/.local/state/bloqueo"
    FileView {
        id: archivoLongitud
        path: bloqueo.dirEstado + "/longitud"
        printErrors: false
        onLoaded: bloqueo.longitudClave = Math.max(0, parseInt(text().trim()) || 0)
        onLoadFailed: bloqueo.longitudClave = 0
    }
    function aprenderLongitud(n) {
        if (n === longitudClave) return;
        longitudClave = n;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && printf "%s\\n" "$2" > "$1/longitud"',
                                 "sh", dirEstado, String(n)]);
    }

    function bloquear() {
        if (sesion.locked) return;
        clave = ""; error = false; comprobando = false; saliendo = false; intentos = 0;
        autoEnvio = true;
        archivoLongitud.reload();        // por si cambiaste la longitud desde el último bloqueo
        sesion.locked = true;
        leerMayus();
    }
    function desbloquear() {
        saliendo = true;
        soltar.restart();                // deja ver la animación y luego suelta
    }
    Timer { id: soltar; interval: 350; onTriggered: { sesion.locked = false; bloqueo.saliendo = false; bloqueo.clave = ""; } }

    // ── Comprobar la contraseña con PAM ─────────────────────────────────
    function enviar(auto) {
        if (clave === "" || comprobando) return;   // Enter vacío no cuenta como intento
        ultimoFueAuto = auto === true;
        longitudEnviada = clave.length;
        comprobando = true;
        error = false;
        pam.start();
    }
    PamContext {
        id: pam
        config: "hyprlock"                         // /etc/pam.d/hyprlock (auth include login)
        onResponseRequiredChanged: {
            if (responseRequired) { respond(bloqueo.clave); }
        }
        onCompleted: (resultado) => {
            bloqueo.comprobando = false;
            if (resultado === PamResult.Success) {
                bloqueo.aprenderLongitud(bloqueo.longitudEnviada);
                bloqueo.desbloquear();
            } else {
                if (bloqueo.ultimoFueAuto) bloqueo.autoEnvio = false;   // quizá cambió la contraseña
                bloqueo.error = true;
                bloqueo.intentos++;
                bloqueo.clave = "";
                borrarError.restart();
            }
        }
    }
    Timer { id: borrarError; interval: 2500; onTriggered: bloqueo.error = false }

    // ── Bloq Mayús (se mira al bloquear y cada vez que se pulsa la tecla) ─
    function leerMayus() { lectorMayus.running = true; }
    Process {
        id: lectorMayus
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { bloqueo.bloqMayus = JSON.parse(this.text).keyboards.some(k => k.capsLock); } catch (e) {}
            }
        }
    }

    // ── El bloqueo de Wayland: una PantallaBloqueo por monitor ─────────
    WlSessionLock {
        id: sesion
        PantallaBloqueo { estado: bloqueo }
    }

    // Modo prueba: se desbloquea solo a los 12 s (la contraseña también funciona)
    Timer { id: prueba; interval: 12000; onTriggered: bloqueo.desbloquear() }

    IpcHandler {
        target: "bloqueo"
        function bloquear(): void { bloqueo.bloquear(); }
        function probar(): void { bloqueo.bloquear(); prueba.restart(); }
        function estado(): string { return sesion.locked ? (sesion.secure ? "bloqueado" : "bloqueando") : "libre"; }
    }
}
