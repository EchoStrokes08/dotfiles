// Bienvenida: el inicio de sesión cinematográfico (una vez por sesión: Isla.bienvenida).
// Una capa por pantalla, por encima del wallpaper y por debajo de ventanas y barra:
//   negro (como al salir de SDDM) → las islas de la barra caen como una ola (IslaBarra.qml)
//   → el wallpaper florece con un zoom suave → la capa se va y queda el fondo real (awww, idéntico).
// La isla del reloj saluda según la hora (Isla.saludar). Los clics atraviesan la capa.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: b
    property bool activa: Isla.bienvenida
    visible: activa || final.running
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-bienvenida"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Item {
        id: todo
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "black" }
        Image {
            id: fondo
            anchors.fill: parent
            // como awww: recorte centrado a resolución física (al terminar coincide con el fondo real)
            source: "file://" + Quickshell.env("HOME") + "/.local/state/tema/wallpaper"
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(b.width * (b.screen?.devicePixelRatio ?? 1)), Math.ceil(b.height * (b.screen?.devicePixelRatio ?? 1)))
            cache: false
            asynchronous: false
            smooth: true
            opacity: 0
            scale: 1.12
        }
    }

    Component.onCompleted: if (activa) florecer.start()
    SequentialAnimation {
        id: florecer
        PauseAnimation { duration: 700 }                 // el negro: aquí caen las islas
        ParallelAnimation {
            NumberAnimation { target: fondo; property: "opacity"; to: 1; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: fondo; property: "scale"; to: 1; duration: 1600; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: final.start() }
    }
    // Ya es igual al fondo real: la capa se desvanece sin que se note y se oculta
    NumberAnimation { id: final; target: todo; property: "opacity"; to: 0; duration: EstiloPanel.lento }
}
