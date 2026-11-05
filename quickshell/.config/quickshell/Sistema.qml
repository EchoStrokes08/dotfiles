// Sistema: CPU, RAM, temperatura y tiempo encendido.
// Lo usan la barra (siempre) y el dashboard. Un proceso cada 2 s: coste despreciable.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool activo: true
    property real cpu: 0        // 0..1
    property real ram: 0        // 0..1
    property real ramUsadaGiB: 0
    property real ramTotalGiB: 0
    property real temp: 0       // °C
    property string encendido: ""

    property var anterior: null // lectura anterior de /proc/stat (la CPU se calcula por diferencia)

    Timer {
        interval: 2000
        running: root.activo
        repeat: true
        triggeredOnStart: true
        onTriggered: lector.running = true
    }

    // Un solo proceso que imprime líneas "clave valores…"
    Process {
        id: lector
        command: ["sh", "-c",
            "printf 'cpu '; head -1 /proc/stat | cut -d' ' -f3-;" +
            "awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print \"mem\", t, a}' /proc/meminfo;" +
            "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name)\" = k10temp ] && echo temp $(cat $h/temp1_input); done;" +
            "echo up $(cut -d' ' -f1 /proc/uptime)"]
        stdout: StdioCollector {
            onStreamFinished: root.procesar(this.text)
        }
    }

    function procesar(salida) {
        for (const linea of salida.trim().split("\n")) {
            const p = linea.trim().split(/\s+/);
            const v = p.slice(1).map(Number);
            if (p[0] === "cpu") {
                // user nice system idle iowait irq softirq steal…
                const inactivo = v[3] + v[4];
                const total = v.reduce((a, b) => a + b, 0);
                if (root.anterior) {
                    const dt = total - root.anterior.total;
                    root.cpu = dt > 0 ? 1 - (inactivo - root.anterior.inactivo) / dt : 0;
                }
                root.anterior = { inactivo: inactivo, total: total };
            } else if (p[0] === "mem") {
                root.ram = 1 - v[1] / v[0];
                root.ramTotalGiB = v[0] / 1048576;          // kB → GiB
                root.ramUsadaGiB = (v[0] - v[1]) / 1048576;
            } else if (p[0] === "temp") {
                root.temp = v[0] / 1000;
            } else if (p[0] === "up") {
                const h = Math.floor(v[0] / 3600), m = Math.floor(v[0] % 3600 / 60);
                root.encendido = h > 0 ? `${h} h ${m} min` : `${m} min`;
            }
        }
    }
}
