// Maquina: la máquina del tiempo (CapaMaquina.qml la dibuja). Tu pantalla se vuelve la primera tarjeta
// de una pila que se pierde en el fondo; cada tarjeta es un momento del día (scripts/maquina.py).
//   Maquina.abrir()                 · qs ipc call maquina abrir · lanzador «Máquina del tiempo»
// Datos de la línea de tiempo de Brújula; con sus capturas cifradas activas, cada momento muestra la suya.
// Como «Tu día», se anima también en el perfil mínimo; sin movimiento solo con «reducir movimiento» o un juego.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: mq
    property bool activa: false
    property bool saliendo: false
    property var datos: null
    property int indice: 0               // la tarjeta al frente (0 = ahora, si es hoy)
    property string pantalla: ""
    property string captura: ""          // la pantalla de ahora (ppm en $XDG_RUNTIME_DIR)
    property int numero: 0
    property bool cargando: false
    // Los títulos de las ventanas pueden ser privados y esto ocupa toda la pantalla: salen difuminados
    // hasta que pasas el ratón por la tarjeta del frente o pulsas T (solo mientras está abierta)
    property bool verTitulos: false
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"

    readonly property bool cine: !Paleta.reducirMovimiento && EstadoEscritorio.datos.juego_activo !== "true"
    readonly property int corto: cine ? 180 : 0
    readonly property int medio: cine ? 420 : 0
    readonly property int largo: cine ? 700 : 0

    readonly property bool hoy: datos?.hoy === true
    // Las tarjetas, de la más reciente a la más antigua; hoy empieza por «ahora» (tu pantalla)
    readonly property var tarjetas: !datos ? [] : (hoy && captura ? [{ ahora: true, app: -1 }] : []).concat(datos.momentos ?? [])
    readonly property var actual: tarjetas[indice] ?? null
    readonly property int numDias: (datos?.dias ?? []).length
    readonly property int posDia: (datos?.dias ?? []).indexOf(datos?.dia ?? "")

    readonly property var ordenSerie: [0, 1, 4, 2, 6, 5, 3, 7]
    function color(i) { return i < 0 ? Paleta.texto : Paleta.serie[ordenSerie[i % ordenSerie.length]]; }

    function abrir() {
        if (activa || cargador.running) return;
        pantalla = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
        const ruta = dir && pantalla ? dir + "/maquina-" + pantalla + ".ppm" : "";
        cargador.ruta = ruta;
        cargador.command = ["sh", "-c",
            'umask 077; [ -n "$1" ] && { grim -o "$2" -t ppm "$1" 2>/dev/null || rm -f "$1"; }; exec python3 "$3/maquina.py"',
            "sh", ruta, pantalla, scripts];
        cargador.running = true;
    }
    // Otro día: d = +1 más antiguo, -1 más reciente
    function cambiarDia(d) {
        const dias = datos?.dias ?? [];
        const n = posDia + d;
        if (!activa || saliendo || n < 0 || n >= dias.length || otroDia.running) return;
        cargando = true;
        otroDia.command = ["python3", scripts + "/maquina.py", "--dia", dias[n]];
        otroDia.running = true;
    }
    function ir(n) { indice = Math.max(0, Math.min(tarjetas.length - 1, n)); }
    function atras() { ir(indice + 1); }
    function adelante() { ir(indice - 1); }
    function cerrar() { if (activa) saliendo = true; }
    function terminar() {
        if (captura) Quickshell.execDetached(["rm", "-f", captura]);
        if (datos?.capturas) Quickshell.execDetached([scripts + "/brujula.py", "capturas", "limpiar"]);
        activa = false; saliendo = false; datos = null; indice = 0; captura = ""; cargando = false; verTitulos = false;
    }
    function abrirApp(m) {
        const e = DesktopEntries.heuristicLookup(m?.clase ?? "");
        if (e) e.execute();
        cerrar();
    }
    function abrirArchivo(ruta) {
        Qt.openUrlExternally("file://" + ruta);
        cerrar();
    }

    Process {
        id: cargador
        property string ruta: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d) { console.warn("Maquina: maquina.py no devolvió datos"); return; }
                mq.captura = cargador.ruta;
                mq.datos = d;
                mq.numero++;
                mq.indice = 0;
                mq.saliendo = false;
                mq.activa = true;
            }
        }
    }
    Process {
        id: otroDia
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                mq.cargando = false;
                if (!d) return;
                mq.datos = d;
                mq.indice = 0;
            }
        }
    }
}
