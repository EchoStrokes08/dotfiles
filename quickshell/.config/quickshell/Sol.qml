// Sol: dónde está el sol de verdad ahora mismo (en Clima.lat / Clima.lon), para CieloSolar.qml.
//   elevacion   grados sobre el horizonte (negativo = de noche)
//   lado        -1 = por el este (mañana) … 0 = mediodía … 1 = por el oeste (tarde)
//   oro, ocaso, azul, noche   cuánto de cada luz toca ahora (0..1)
// Fórmulas solares de baja precisión (NOAA/Almanaque, error < 1°): de sobra para pintar luz.
//   qs ipc call cielo simular 17:50   ver el cielo a esa hora ("" vuelve a la real)
//   qs ipc call cielo timelapse       un día entero en 24 s
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sol
    property real simulada: -1                 // ms de una hora simulada; -1 = la real
    readonly property bool rapido: lapso.running // durante el timelapse la luz cambia sin suavizar
    property real elevacion: 0
    property real lado: 0

    function suave(a, b, x) { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); }
    // luz dorada: con el sol bajo pero por encima del horizonte
    readonly property real oro: suave(-3, 2, elevacion) * (1 - suave(10, 22, elevacion))
    // horizonte rosado: justo al cruzar el horizonte
    readonly property real ocaso: suave(-8, -2.5, elevacion) * (1 - suave(0, 6, elevacion))
    // hora azul: el sol ya se fue pero aún queda luz
    readonly property real azul: suave(-11, -5, elevacion) * (1 - suave(-3, 1, elevacion))
    readonly property real noche: 1 - suave(-12, -4, elevacion)

    function calcular() {
        const ms = simulada >= 0 ? simulada : Date.now();
        const rad = Math.PI / 180;
        const n = ms / 86400000 + 2440587.5 - 2451545.0;            // días desde J2000
        const L = (280.460 + 0.9856474 * n) % 360;
        const g = ((357.528 + 0.9856003 * n) % 360) * rad;
        const lam = (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * rad;
        const eps = (23.439 - 0.0000004 * n) * rad;
        const ar = Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam));
        const dec = Math.asin(Math.sin(eps) * Math.sin(lam));
        const gmst = ((18.697374558 + 24.06570982441908 * n) % 24 + 24) % 24;
        let h = (gmst * 15 + Clima.lon) * rad - ar;                // ángulo horario
        h = Math.atan2(Math.sin(h), Math.cos(h));
        const fi = Clima.lat * rad;
        elevacion = Math.asin(Math.sin(fi) * Math.sin(dec) + Math.cos(fi) * Math.cos(dec) * Math.cos(h)) / rad;
        lado = Math.sin(h);
    }
    Component.onCompleted: calcular()
    onSimuladaChanged: calcular()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: sol.calcular() }

    NumberAnimation { id: lapso; target: sol; property: "simulada"; duration: 24000; onFinished: sol.simulada = -1 }

    IpcHandler {
        target: "cielo"
        function simular(hora: string): void {
            lapso.stop();
            const m = /^(\d{1,2}):(\d{2})$/.exec(hora.trim());
            if (!m) { sol.simulada = -1; return; }
            const d = new Date(); d.setHours(+m[1], +m[2], 0, 0);
            sol.simulada = d.getTime();
        }
        function timelapse(): void {
            const d = new Date(); d.setHours(4, 0, 0, 0);
            lapso.from = d.getTime(); lapso.to = d.getTime() + 86400000;
            lapso.restart();
        }
        function estado(): string {
            return JSON.stringify({ elevacion: +sol.elevacion.toFixed(1), lado: +sol.lado.toFixed(2), oro: +sol.oro.toFixed(2),
                                    ocaso: +sol.ocaso.toFixed(2), azul: +sol.azul.toFixed(2), noche: +sol.noche.toFixed(2) });
        }
    }
}
