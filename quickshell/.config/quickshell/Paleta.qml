// Paleta: los colores del escritorio, leídos de la paleta ACTIVA de tema.sh.
// "pragma Singleton" = hay un único objeto Paleta, accesible desde cualquier archivo (Paleta.naranja).
// Al cambiar de tema (SUPER+SHIFT+T) el archivo cambia, FileView lo nota y todo se repinta solo.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Valores de partida: Ayu (por si el archivo aún no existe)
    property color fondo:     "#0e1419"
    property color texto:     "#e5e1cf"
    property color naranja:   "#f19618"
    property color amarillo:  "#e6c446"
    property color azul:      "#36a3d9"
    property color verde:     "#b8cc52"
    property color rojo:      "#ff3333"
    property color seleccion: "#243340"
    property color gris:      "#5c6773"
    readonly property color morado: "#d2a6ff"   // el del ✦ del prompt (no está en la paleta)
    readonly property string fuente: "Adwaita Sans"            // texto de la interfaz
    readonly property string mono: "JetBrainsMono Nerd Font"   // código, atajos y cifras alineadas

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/tema/colores.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            // Cada línea es:  @define-color naranja   #f19618;
            const re = /@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})/g;
            let m;
            while ((m = re.exec(text())) !== null) {
                if (m[1] in root) root[m[1]] = m[2];
            }
        }
    }
}
