pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: memoria
    property var proyectos: []
    property string ultimoId: ""
    readonly property var ultimo: proyectos.find(x => x.id === ultimoId) || null
    readonly property string carpetaEstado: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/mesa-trabajo"
    Process { running: true; command: ["mkdir", "-p", memoria.carpetaEstado]; onExited: archivo.reload() }
    FileView {
        id: archivo
        path: memoria.carpetaEstado + "/proyectos.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { const d=JSON.parse(text()); memoria.proyectos=d.proyectos || []; memoria.ultimoId=d.ultimo || ""; }
            catch(e) { memoria.proyectos=[]; memoria.ultimoId=""; }
        }
        onLoadFailed: { memoria.proyectos=[]; memoria.ultimoId=""; }
    }
}
