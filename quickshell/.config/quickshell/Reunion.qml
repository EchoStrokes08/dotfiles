pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: sesion
    property var datos: ({})
    property real ahora: Date.now()
    readonly property bool activa: Number(datos.fin || 0) * 1000 > ahora
    readonly property int restante: Math.max(0, Math.ceil((Number(datos.fin || 0) * 1000 - ahora) / 1000))
    readonly property string cuenta: Math.floor(restante / 60) + ":" + String(restante % 60).padStart(2, "0")
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-reunion-" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + ".json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { sesion.datos = JSON.parse(text()); } catch (e) { sesion.datos = {}; } sesion.ahora = Date.now(); }
        onLoadFailed: sesion.datos = ({})
    }
    Timer { interval: 1000; running: sesion.activa; repeat: true; onTriggered: sesion.ahora = Date.now() }
}
