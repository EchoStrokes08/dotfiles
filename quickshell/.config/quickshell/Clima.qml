// Clima (Open-Meteo: gratis, sin cuenta ni clave). Se actualiza cada 30 min; lo enseña el dashboard.
// Ubicación: Bogotá. Para cambiarla, edita lat/lon/lugar aquí (coordenadas: buscar «ciudad coordenadas»).
//   qs ipc call clima estado
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: c
    readonly property real lat: 4.711
    readonly property real lon: -74.0721
    readonly property string lugar: "Bogotá"

    property bool listo: false
    property real temp: 0
    property real sensacion: 0
    property int codigo: 0
    property bool deDia: true
    property int humedad: 0
    property real max: 0
    property real min: 0
    property int lluviaHoy: 0           // % máximo de lluvia hoy
    property var proximas: []           // [{ hora: "13", lluvia: %, temp }] próximas 6 h

    function g(cp) { return String.fromCodePoint(cp); }
    // Códigos WMO → texto e icono
    function texto(cod) {
        return cod === 0 ? "Despejado" : cod <= 2 ? "Parcialmente nublado" : cod === 3 ? "Nublado"
             : cod <= 48 ? "Niebla" : cod <= 57 ? "Llovizna" : cod <= 67 ? "Lluvia" : cod <= 77 ? "Nieve"
             : cod <= 82 ? "Chubascos" : "Tormenta";
    }
    function icono(cod, dia) {
        return g(cod === 0 ? (dia ? 0xF0599 : 0xF0594) : cod <= 2 ? (dia ? 0xF0595 : 0xF0F31) : cod === 3 ? 0xF0590
               : cod <= 48 ? 0xF0591 : cod <= 67 ? 0xF0597 : cod <= 77 ? 0xF0598 : cod <= 82 ? 0xF0596 : 0xF067E);
    }

    Process {
        id: pedir
        command: ["curl", "-sf", "--max-time", "20",
            `https://api.open-meteo.com/v1/forecast?latitude=${c.lat}&longitude=${c.lon}` +
            "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m" +
            "&hourly=precipitation_probability,temperature_2m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max" +
            "&timezone=auto&forecast_days=1&forecast_hours=7"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    c.temp = d.current.temperature_2m; c.sensacion = d.current.apparent_temperature;
                    c.codigo = d.current.weather_code; c.deDia = d.current.is_day === 1;
                    c.humedad = d.current.relative_humidity_2m;
                    c.max = d.daily.temperature_2m_max[0]; c.min = d.daily.temperature_2m_min[0];
                    c.lluviaHoy = d.daily.precipitation_probability_max[0] ?? 0;
                    c.proximas = d.hourly.time.slice(1, 7).map((t, i) => ({ hora: t.slice(11, 13),
                        lluvia: d.hourly.precipitation_probability[i + 1] ?? 0, temp: d.hourly.temperature_2m[i + 1] }));
                    c.listo = true;
                } catch (e) { /* sin internet: se queda el último dato */ }
            }
        }
    }
    Timer { interval: 30 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pedir.running = true }
    function actualizar() { pedir.running = true; }
}
