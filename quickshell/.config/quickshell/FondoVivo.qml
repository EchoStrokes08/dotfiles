// FondoVivo: el wallpaper «respira» al cambiar de espacio (escritorio que respira).
// awww pinta el fondo y no sabe moverlo; esta capa, justo encima de awww y debajo de los widgets del
// escritorio, tiene una copia idéntica del fondo, invisible en reposo. Al cambiar de espacio aparece en
// el mismo sitio (no se nota el cambio), se desliza unos píxeles en sentido contrario al de las ventanas
// con un zoom mínimo que tapa los bordes, y vuelve a su sitio; luego se oculta otra vez.
// Solo con movimiento y profundidad (no con batería, en Mínimo ni jugando). Una por pantalla (shell.qml).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: fv
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int espacio: monitor?.activeWorkspace?.id ?? 0
    property int anterior: 0
    property string ruta: ""
    readonly property real amplitud: 22          // px que se desplaza el fondo
    // Con el panorama (Panorama.qml) el fondo ya se mueve entre espacios: entonces no respira
    readonly property bool permitido: EstiloPanel.movimiento && EstiloPanel.profundidad
        && !(PreferenciasUI.panorama && EstadoEscritorio.perfil !== "rendimiento" && EstadoEscritorio.datos.juego_activo !== "true")

    // Siempre mapeada (transparente y sin clics): mostrar/ocultar un PanelWindow con `visible` lo destruye
    // y lo recrea, y si en ese instante cambia una imagen o un texto Quickshell se cae (26-nov, al cerrar un
    // juego). Se apaga el contenido; tests/test_estilo.py lo vigila.
    contentItem.visible: permitido
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-fondo-vivo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}                              // los clics llegan al escritorio

    // En cada cambio de espacio se relee el fondo (unos ms): si cambió, la copia se recarga y esta vez no
    // se anima; así nunca aparece un fondo viejo, cambie como cambie (selector, rotación, tema fijo…).
    property real direccion: 0
    onEspacioChanged: {
        const antes = anterior;
        anterior = espacio;
        if (antes <= 0 || espacio <= 0 || !permitido) return;
        direccion = espacio > antes ? -1 : 1;
        leer.running = true;
    }
    Process {
        id: leer
        running: true
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/tema/wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                const igual = r === fv.ruta && imagen.status === Image.Ready;
                fv.ruta = r;
                if (igual && fv.direccion !== 0) { ida.to = fv.direccion * fv.amplitud; respiro.restart(); }
                fv.direccion = 0;
            }
        }
    }

    Item {
        id: lienzo
        anchors.fill: parent
        opacity: respiro.running ? 1 : 0
        Image {
            id: imagen
            anchors.fill: parent
            source: fv.permitido && fv.ruta ? "file://" + fv.ruta : ""
            // como awww: recorte centrado que llena la pantalla, a resolución física
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(fv.width * (fv.screen?.devicePixelRatio ?? 1) * 1.04),
                                Math.ceil(fv.height * (fv.screen?.devicePixelRatio ?? 1) * 1.04))
            asynchronous: true
            smooth: true
            mipmap: true
            transform: Translate { id: mover }
        }
    }

    // Ida y vuelta con la misma curva para desplazamiento y zoom: el borde nunca queda a la vista
    SequentialAnimation {
        id: respiro
        ParallelAnimation {
            NumberAnimation { id: ida; target: mover; property: "x"; duration: EstiloPanel.lento; easing.type: Easing.OutCubic }
            NumberAnimation { target: imagen; property: "scale"; to: 1 + 2.4 * fv.amplitud / Math.max(1, fv.width); duration: EstiloPanel.lento; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: mover; property: "x"; to: 0; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { target: imagen; property: "scale"; to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }
}
