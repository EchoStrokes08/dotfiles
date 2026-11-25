// Paleta: los colores del escritorio, leídos de la paleta ACTIVA de tema.sh.
// "pragma Singleton" = hay un único objeto Paleta, accesible desde cualquier archivo (Paleta.acento).
// Al cambiar de tema (SUPER+SHIFT+T) el archivo cambia, FileView lo nota y todo se repinta solo.
//
// Los nombres dicen la FUNCIÓN, no el tono (en modo wallpaper «acento» puede ser azul):
//   acento   foco, selección, acción principal · el único color «de marca»
//   acento2  solo en parejas con acento: hora/minutos, series de gráficas
//   exito · aviso · peligro   estados; fijos en todos los modos para que siempre se reconozcan
//   fondo · texto · seleccion · gris   neutros
// Las capas de transparencia, escalas de letra, radios y tiempos están en EstiloPanel.qml.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Valores de partida: Ayu (por si el archivo aún no existe)
    property color fondo:     "#121519"
    property color texto:     "#edf0f5"
    property color acento:    "#f19618"
    property color acento2:   "#36a3d9"
    property color exito:     "#b8cc52"
    property color aviso:     "#e6c446"
    property color peligro:   "#ff3333"
    property color seleccion: "#243340"
    property color gris:      "#aab3c0"
    property color sobreAcento: "#121519"
    property string modo: "ayu"
    property string variante: "oscuro"
    property bool fijado: false
    property bool reducirMovimiento: false
    property bool permitirTransicion: true
    readonly property bool animarColor: permitirTransicion && !reducirMovimiento && EstadoEscritorio.perfil !== "minimo" && EstadoEscritorio.perfil !== "rendimiento"
    Behavior on acento { enabled: !root.enOnda; ColorAnimation { duration: root.animarColor ? 500 : 0 } }
    Behavior on acento2 { enabled: !root.enOnda; ColorAnimation { duration: root.animarColor ? 500 : 0 } }

    // ── Onda de color (OndaTema.qml): el tema nuevo se propaga desde el cursor ──
    // Antes de aplicar los colores, «preparar» avisa a cada barra para que se fotografíe con los viejos;
    // un instante después se aplican y la foto se va borrando en círculo desde el cursor.
    readonly property bool onda: !reducirMovimiento && EstadoEscritorio.perfil !== "rendimiento"
        && EstadoEscritorio.datos.juego_activo !== "true"
    property bool enOnda: false
    property bool listo: false               // la primera carga (al arrancar) nunca hace onda
    signal preparar()
    signal ondaLista()
    property var pendientes: null
    function aplicar(nuevos) {
        for (const k in nuevos) root[k] = nuevos[k];
    }
    Timer {
        id: tras
        interval: 90                             // unos fotogramas para la foto (grabToImage)
        onTriggered: { root.aplicar(root.pendientes); root.pendientes = null; root.ondaLista(); fin.restart(); }
    }
    Timer { id: fin; interval: 1400; onTriggered: root.enOnda = false }
    // Serie para DATOS por categoría (gráficas, contextos de Brújula): empieza por los colores del tema
    // y sigue con tonos Ayu fijos. No es decoración: fuera de gráficas y etiquetas de categoría, usar acento.
    readonly property var serie: [acento, acento2, exito, aviso, "#d2a6ff", "#95e6cb", "#f07178", "#ffb454"]
    // Texto sobre fotos (widgets del escritorio): marfil fijo, no depende del tema
    readonly property color sobreImagen: "#f3efe0"
    readonly property string fuente: "Adwaita Sans"            // texto de la interfaz
    readonly property string mono: "JetBrainsMono Nerd Font"   // código, atajos y cifras alineadas

    // Archivos de estado anteriores a los nombres por función
    readonly property var antiguos: ({ naranja: "acento", azul: "acento2", verde: "exito", amarillo: "aviso", rojo: "peligro" })

    FileView {
        id: colores
        path: Quickshell.env("HOME") + "/.local/state/tema/colores.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // Cada línea es:  @define-color acento   #f19618;
            const re = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})/g;
            const nuevoFondo = text().match(/@define-color\s+fondo\s+(#[0-9a-fA-F]{6})/);
            // Cambiar de luminosidad es inmediato: no mezclar texto claro con un acento anterior claro.
            root.permitirTransicion = !nuevoFondo || nuevoFondo[1].toLowerCase() === root.fondo.toString().toLowerCase();
            let m;
            const nuevos = {};
            while ((m = re.exec(text())) !== null) {
                const nombre = root.antiguos[m[1]] ?? m[1];
                if (nombre in root) nuevos[nombre] = m[2];
            }
            const cambia = Object.keys(nuevos).some(k => root[k].toString().toLowerCase() !== nuevos[k].toLowerCase());
            if (root.listo && root.onda && cambia) {
                root.enOnda = true; root.pendientes = nuevos;
                root.preparar();
                tras.restart();
            } else root.aplicar(nuevos);
            root.listo = true;
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/tema/version"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); colores.reload(); preferencias.reload(); }
    }
    FileView {
        id: preferencias
        path: Quickshell.env("HOME") + "/.local/state/tema/preferencias.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const p = JSON.parse(text());
                root.modo = p.modo; root.variante = p.variante;
                root.fijado = !!p.fijado; root.reducirMovimiento = !!p.reducirMovimiento;
            } catch (e) { }
        }
    }
}
