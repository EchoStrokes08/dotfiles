// Clima (Open-Meteo: gratis, sin cuenta ni clave). Se actualiza cada 30 min; lo enseñan Brújula › Hoy y los widgets del escritorio.
// Ubicación: Bogotá. Para cambiarla, edita lat/lon/lugar aquí (coordenadas: buscar «ciudad coordenadas»).
// El «ahora» (icono, texto y clima vivo) sale de lo que observa la estación METAR más cercana (aviationweather.gov,
// cada 10 min): el modelo puede decir «llovizna» en toda la celda mientras en tu zona hace sol. El modelo queda
// para el pronóstico (próximas horas, máx/mín, % de lluvia) y de respaldo si no hay observación reciente.
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
    property int codigoModelo: 0        // código WMO del pronóstico (celda del modelo)
    property int observado: -1          // código WMO deducido del METAR (-1 = sin observación reciente)
    property string estacion: ""        // estación usada, p. ej. "SKBO"
    readonly property int codigo: observado >= 0 ? observado : codigoModelo
    property bool deDia: true
    property int humedad: 0
    property real max: 0
    property real min: 0
    property int lluviaHoy: 0           // % máximo de lluvia hoy
    property var proximas: []           // [{ hora: "13", lluvia: %, temp }] próximas 6 h

    // Clima vivo en el escritorio (ClimaVivo.qml): qué se dibuja según el código WMO actual.
    //   qs ipc call clima simular lluvia   (llovizna · lluvia · chubasco · tormenta · nieve · niebla · nubes · "" = real)
    property string simulado: ""
    readonly property string vivo: simulado !== "" ? simulado : !listo ? ""
        : codigo >= 95 ? "tormenta" : codigo >= 80 && codigo <= 82 ? "chubasco" : codigo >= 61 && codigo <= 67 ? "lluvia"
        : codigo >= 51 && codigo <= 57 ? "llovizna" : (codigo >= 71 && codigo <= 77) || codigo === 85 || codigo === 86 ? "nieve"
        : codigo === 45 || codigo === 48 ? "niebla" : codigo === 2 || codigo === 3 ? "nubes" : ""

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
                    c.codigoModelo = d.current.weather_code; c.deDia = d.current.is_day === 1;
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

    // Observación real: estaciones METAR de Bogotá (El Dorado al occidente, Guaymaral al norte). Se usa la más
    // cercana a lat/lon con un reporte de hace ≤ 90 min. Solo cuenta lo que pasa EN la estación: «VC» (en las
    // cercanías) y «RE» (hace un rato) no pintan lluvia.
    readonly property var estaciones: ["SKBO", "SKGY"]
    function desdeMetar(m) {
        const fuerza = t => t.startsWith("+") ? 2 : t.startsWith("-") ? 0 : 1;
        let cod = -1;
        for (const t of (m.wxString || "").split(" ")) {
            if (t === "" || t.startsWith("VC") || t.startsWith("RE")) continue;
            const f = fuerza(t), w = t.replace(/^[-+]/, "");
            const c2 = w.includes("TS") ? 95
                : w.includes("SH") && w.includes("SN") ? 85 + Math.min(f, 1)
                : w.includes("SH") ? 80 + f
                : w.includes("RA") ? 61 + 2 * f
                : w.includes("SN") ? 71 + 2 * f
                : w.includes("DZ") ? 51 + 2 * f
                : w.includes("FG") && !w.startsWith("MI") && !w.startsWith("BC") ? 45 : -1;
            cod = Math.max(cod, c2);
        }
        if (cod >= 0) return cod;
        const cubre = (m.clouds || []).map(n => n.cover);
        return cubre.includes("OVC") || cubre.includes("VV") ? 3 : cubre.includes("BKN") || cubre.includes("SCT") ? 2
             : cubre.includes("FEW") ? 1 : 0;
    }
    Process {
        id: observar
        command: ["curl", "-sf", "--max-time", "20",
            `https://aviationweather.gov/api/data/metar?ids=${c.estaciones.join(",")}&format=json&hours=2`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ahora = Date.now() / 1000;
                    const dist = m => Math.hypot(m.lat - c.lat, (m.lon - c.lon) * Math.cos(c.lat * Math.PI / 180));
                    const recientes = JSON.parse(this.text).filter(m => ahora - m.obsTime <= 90 * 60)
                        .sort((a, b) => dist(a) - dist(b) || b.obsTime - a.obsTime);
                    if (recientes.length === 0) { c.observado = -1; c.estacion = ""; return; }
                    c.observado = c.desdeMetar(recientes[0]); c.estacion = recientes[0].icaoId;
                } catch (e) { c.observado = -1; c.estacion = ""; }
            }
        }
    }
    Timer { interval: 10 * 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: observar.running = true }
    function actualizar() { pedir.running = true; observar.running = true; }
}
