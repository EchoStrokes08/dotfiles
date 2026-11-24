// Colores del inicio de sesión. Este es el de partida (Ayu oscuro); sincronizar-sddm.sh
// lo reescribe en /usr/share/sddm/themes/ayu-glass con la paleta activa de tema.sh
// al apagar y al encender, para que el login se vea como el bloqueo de Quickshell.
import QtQuick

QtObject {
    property color fondo:   "#121519"
    property color texto:   "#edf0f5"
    property color acento:  "#f19618"
    property color acento2: "#36a3d9"
    property color exito:   "#b8cc52"
    property color aviso:   "#e6c446"
    property color peligro: "#ff3333"
    property color gris:    "#aab3c0"
    property bool claro: false
}
