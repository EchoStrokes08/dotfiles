// Pausas activas: tras 50 minutos SEGUIDOS frente a la pantalla, un aviso suave para descansar la
// vista y moverse. "Seguidos" = sin una pausa de al menos 3 minutos sin tocar teclado ni ratón
// (ver un vídeo sin tocar nada cuenta como pausa: el aviso es para cuando trabajas).
// No avisa con No molestar activo (modo juego, concentración, presentación): espera a que termine.
//   Cambiar el tiempo: MINUTOS aquí abajo.        qs ipc call pausas estado
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: p
    readonly property int minutos: 50
    property int seguidos: 0              // minutos de uso sin descansar

    readonly property var consejos: [
        "Mira algo a más de 6 metros durante 20 segundos.",
        "Levántate y estira la espalda y el cuello.",
        "Toma agua y parpadea despacio unas cuantas veces.",
        "Suelta los hombros y gira las muñecas.",
        "Camina un minuto: vuelves más despejado."
    ]

    IdleMonitor {
        id: quieto
        timeout: 180                      // segundos sin tocar nada = estás descansando
        respectInhibitors: false          // un vídeo no cuenta como "estar usando el equipo"
        onIsIdleChanged: if (isIdle) p.seguidos = 0
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: {
            if (quieto.isIdle) return;
            p.seguidos++;
            if (p.seguidos < p.minutos || Notificaciones.noMolestar) return;
            p.seguidos = 0;
            Quickshell.execDetached(["notify-send", "-a", "Pausa", "-u", "low", "-t", "15000", "-i", "appointment-soon",
                `Llevas ${p.minutos} minutos seguidos`, p.consejos[Math.floor(Math.random() * p.consejos.length)]]);
        }
    }
}
