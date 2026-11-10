// Actualizaciones pendientes (para la barra y el resumen del día). Pregunta cada 3 horas con
// scripts/actualizaciones.sh, que NO toca el sistema (checkupdates trabaja sobre una copia).
//   repos / aur = paquetes por actualizar · noticias = avisos de Arch sin leer (a veces piden pasos
//   manuales antes de actualizar) · vulnerables = paquetes con fallo de seguridad ya corregido
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: a
    property int repos: 0
    property int aur: 0
    property int noticias: 0
    property int vulnerables: 0
    property string lista: ""
    property bool listo: false
    readonly property int total: repos + aur

    function refrescar() { if (!lector.running) lector.running = true; }

    Process {
        id: lector
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/actualizaciones.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    a.repos = d.repos; a.aur = d.aur; a.noticias = d.noticias; a.vulnerables = d.vulnerables; a.lista = d.lista;
                    a.listo = true;
                } catch (e) {}
            }
        }
    }
    Timer { interval: 60000; running: true; onTriggered: a.refrescar() }                      // 1 min tras arrancar (ya hay red)
    Timer { interval: 3 * 3600 * 1000; running: true; repeat: true; onTriggered: a.refrescar() }
}
