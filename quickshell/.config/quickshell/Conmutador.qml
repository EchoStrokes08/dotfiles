// Conmutador: ALT+TAB cinematográfico (CapaConmutador.qml lo dibuja). Todas las ventanas, de todos los espacios,
// por uso reciente (focusHistoryID de Hyprland), en un carrusel 3D con miniaturas en vivo.
//   ALT+TAB siguiente · ALT+SHIFT+TAB anterior · soltar ALT = ir (la miniatura crece hasta la ventana)
//   Con el carrusel abierto: ← → mover · Q cerrar la elegida · Esc cancelar · Intro ir
// Un toque rápido (soltar antes de ~0,12 s) cambia a la ventana anterior sin mostrar nada.
// Atajos en modulos/atajos.lua: qs ipc call conmutador siguiente | anterior | soltar
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: cm
    property bool abierto: false         // ALT está pulsado y hay lista
    property bool visible_: false        // ya se ve (tras el retardo)
    property bool saliendo: false
    property var ventanas: []            // [{ dir, clase, titulo, ws, x, y, w, h, flotante, toplevel }]
    property int indice: 0
    property string pantalla: ""
    property int pendiente: 0            // pulsaciones que llegaron mientras se leía la lista
    property bool soltarPendiente: false

    readonly property bool cine: !Paleta.reducirMovimiento && EstadoEscritorio.datos.juego_activo !== "true"
    readonly property int corto: cine ? 160 : 0
    readonly property int medio: cine ? 320 : 0
    readonly property var actual: ventanas[indice] ?? null

    function siguiente() { mover(1); }
    function anterior() { mover(-1); }
    function mover(d) {
        if (saliendo) return;
        if (abierto) { if (ventanas.length) indice = (indice + d + ventanas.length) % ventanas.length; return; }
        if (lector.running) { pendiente += d; return; }
        pendiente = d; soltarPendiente = false;
        pantalla = Hyprland.focusedMonitor?.name ?? "";
        lector.running = true;
    }
    function ir(n) { if (abierto && n >= 0 && n < ventanas.length) indice = n; }
    // Soltar ALT
    function soltar() {
        if (lector.running) { soltarPendiente = true; return; }
        if (!abierto || saliendo) return;
        if (!visible_) { mostrar.stop(); enfocar(actual); terminar(); return; }   // toque rápido: sin carrusel
        saliendo = true;                         // CapaConmutador hace crecer la elegida y llama a confirmar()
    }
    function cancelar() {
        if (!abierto) return;
        mostrar.stop();
        indice = -1;                             // ninguna: se va sin cambiar de ventana
        if (visible_) saliendo = true; else terminar();
    }
    function confirmar() { enfocar(actual); }
    function enfocar(v) {
        if (!v) return;
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${v.dir}" })`);
        if (v.flotante) Hyprland.dispatch(`hl.dsp.window.alter_zorder({ mode = "top" })`);
    }
    function cerrarElegida() {
        const v = actual;
        if (!v) return;
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${v.dir}" })`);
        const l = ventanas.filter(x => x.dir !== v.dir);
        if (!l.length) { cancelar(); return; }
        ventanas = l;
        indice = Math.min(indice, l.length - 1);
    }
    function terminar() {
        abierto = false; visible_ = false; saliendo = false; ventanas = []; indice = 0;
    }

    // La lista, por uso reciente (0 = la que tiene el foco ahora)
    Process {
        id: lector
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = [];
                try { l = JSON.parse(text); } catch (e) {}
                l = l.filter(c => c.mapped && !c.hidden && (c.workspace?.id ?? 0) > 0)
                     .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                     .map(c => {
                         const dir = c.address.replace(/^0x/, "");
                         return { dir: dir, clase: c.class, titulo: c.title, ws: c.workspace.id, x: c.at[0], y: c.at[1],
                                  w: c.size[0], h: c.size[1], flotante: c.floating, monitor: c.monitor,
                                  toplevel: Hyprland.toplevels.values.find(t => t.address === dir) ?? null };
                     });
                if (l.length < 2) {                // nada a lo que cambiar
                    cm.terminar();
                    return;
                }
                cm.ventanas = l;
                cm.indice = ((cm.pendiente % l.length) + l.length) % l.length;
                cm.abierto = true;
                if (cm.soltarPendiente) { cm.soltarPendiente = false; cm.enfocar(cm.actual); cm.terminar(); return; }
                mostrar.restart();
            }
        }
    }
    Timer { id: mostrar; interval: 120; onTriggered: cm.visible_ = true }
}
