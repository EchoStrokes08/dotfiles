// BordeMusica: mientras suena algo con carátula, el borde de la ventana activa (y su resplandor) toma los
// colores de la portada; al cambiar de canción cambia con un fundido corto, y al parar la música (3 s en
// pausa) vuelve al degradado del tema. Lo aplica Hyprland con borde_musica() (apariencia.lua), sin recargar.
// Portadas en grises: se queda el tema. Apagado jugando y en perfil rendimiento.
//   PreferenciasUI.bordeMusica · interruptor en Apariencia · qs ipc call borde probar <imagen> | borde probar ""
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: b
    readonly property bool permitido: PreferenciasUI.bordeMusica
        && EstadoEscritorio.perfil !== "rendimiento" && EstadoEscritorio.datos.juego_activo !== "true"
    property string forzada: ""                // qs ipc call borde probar <imagen> (vacío = dejar de probar)
    readonly property string caratula: forzada || (permitido && Isla.suena ? Isla.caratula : "")
    IpcHandler {
        target: "borde"
        function probar(imagen: string): void { b.forzada = imagen && !imagen.includes("://") ? "file://" + imagen : imagen; }
    }

    ColorQuantizer {
        id: q
        source: b.caratula
        depth: 3
        rescaleSize: 64
        onColorsChanged: b.decidir()
    }
    onCaratulaChanged: {
        if (caratula) return;               // la nueva portada avisa por colorsChanged
        volver.restart();                    // en pausa o sin portada: 3 s y vuelve al tema
    }
    Timer { id: volver; interval: 3000; onTriggered: if (!b.caratula) b.irA(null) }

    // ── qué colores ───────────────────────────────────────────────────────────────────────────────
    function nota(c) { return c.hslSaturation * (1 - Math.abs(c.hslLightness - .5) * 1.4); }
    function vivo(c) { return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, .55), Math.min(.75, Math.max(.6, c.hslLightness)), 1); }
    function decidir() {
        if (!caratula) return;
        const cs = (q.colors ?? []).filter(c => c.hslSaturation >= .18 && c.hslLightness > .08 && c.hslLightness < .95);
        if (!cs.length) { irA(null); return; }        // portada en grises
        cs.sort((x, y) => nota(y) - nota(x));
        const a = cs[0];
        const otro = cs.find(c => Math.min(Math.abs(c.hslHue - a.hslHue), 1 - Math.abs(c.hslHue - a.hslHue)) > .08);
        const segundo = otro ?? Qt.hsla((a.hslHue + .08) % 1, a.hslSaturation, a.hslLightness, 1);
        volver.stop();
        irA([vivo(a), vivo(segundo)]);
    }

    // ── el fundido: 6 pasos en ~½ s de lo que hay a lo nuevo ──────────────────────────────────────
    property var actual: null                 // [a, b] puestos; null = los del tema
    property var desde: []
    property var hacia: null
    property int paso: 0
    function tema() { return [Qt.lighter(Paleta.acento, 1), Qt.lighter(Paleta.acento2, 1)]; }
    function irA(par) {
        if (par === null && actual === null) return;
        desde = actual ?? tema();
        hacia = par;
        paso = 0;
        fundido.restart();
    }
    Timer {
        id: fundido
        interval: 80; repeat: true
        onTriggered: {
            b.paso++;
            const k = b.paso / 6, fin = b.hacia ?? b.tema();
            const mez = (x, y) => Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k, 1);
            const par = [mez(b.desde[0], fin[0]), mez(b.desde[1], fin[1])];
            if (b.paso >= 6) {
                stop();
                b.actual = b.hacia;
                if (b.hacia === null) { b.aplicar(null); return; }
            }
            b.aplicar(par);
        }
    }
    function hex(c, alfa) { return "rgba(" + c.toString().slice(1, 7) + alfa + ")"; }
    function aplicar(par) {
        const lua = par ? `borde_musica("${hex(par[0], "ff")}","${hex(par[1], "ff")}","${hex(par[0], "3d")}")` : "borde_musica()";
        Quickshell.execDetached(["hyprctl", "dispatch", `borde_musica and ${lua} or hl.dsp.no_op()`]);
    }
    // si Quickshell se reinició con los colores de una canción puestos, se limpian
    Component.onCompleted: aplicar(null)
}
