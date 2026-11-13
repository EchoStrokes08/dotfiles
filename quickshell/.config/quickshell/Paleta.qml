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
    property color fondo:     "#0e1419"
    property color texto:     "#e5e1cf"
    property color acento:    "#f19618"
    property color acento2:   "#36a3d9"
    property color exito:     "#b8cc52"
    property color aviso:     "#e6c446"
    property color peligro:   "#ff3333"
    property color seleccion: "#243340"
    property color gris:      "#78818b"
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
        path: Quickshell.env("HOME") + "/.local/state/tema/colores.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // Cada línea es:  @define-color acento   #f19618;
            const re = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})/g;
            let m;
            while ((m = re.exec(text())) !== null) {
                const nombre = root.antiguos[m[1]] ?? m[1];
                if (nombre in root) root[nombre] = m[2];
            }
        }
    }
}
