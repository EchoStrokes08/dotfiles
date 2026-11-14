pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ajustes
    property var favoritosControles: []
    property var favoritosBandeja: []
    property string errorTema: ""
    readonly property bool cambiandoTema: tema.running
    function alternarFavorito(tipo, id) {
        const lista = tipo === "control" ? favoritosControles : favoritosBandeja;
        const nueva = lista.includes(id) ? lista.filter(x => x !== id) : [...lista,id];
        if (tipo === "control") favoritosControles = nueva.slice(-2); else favoritosBandeja = nueva;
        archivo.setText(JSON.stringify({controles:favoritosControles,bandeja:favoritosBandeja}));
    }
    function cambiarTema(args) {
        if (tema.running) return;
        errorTema = "";
        tema.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/tema.sh", ...args]; tema.running = true;
    }
    Process {
        running:true
        command:["sh","-c","mkdir -p \"$(dirname \"$1\")\"; [ -s \"$1\" ] || printf %s \"{}\" > \"$1\"","_",Quickshell.env("HOME")+"/.local/state/quickshell/preferencias.json"]
        onExited: archivo.path=Quickshell.env("HOME")+"/.local/state/quickshell/preferencias.json"
    }
    FileView {
        id: archivo
        printErrors: false
        onLoaded: {
            try { const p = JSON.parse(text()); ajustes.favoritosControles = p.controles || []; ajustes.favoritosBandeja = p.bandeja || []; } catch (e) { }
        }
    }
    Process {
        id: tema
        onExited: (codigo, estado) => { if (codigo !== 0 || estado !== 0) ajustes.errorTema = "No se pudo actualizar el tema. Se conserva la última paleta válida."; }
    }
}
