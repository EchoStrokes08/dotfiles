pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ajustes
    property var favoritosControles: []
    property var favoritosBandeja: []
    property bool mostrarContinuidad: true
    property bool panorama: true            // el wallpaper como paisaje entre espacios (Panorama.qml)
    property bool cieloSolar: true          // la luz del escritorio sigue al sol (CieloSolar.qml)
    property bool esquinas: true            // la pantalla con las esquinas redondeadas (EsquinasPantalla.qml)
    property bool esquinaActiva: true       // puntero arriba a la izquierda → vista general (EsquinasPantalla.qml)
    property bool reposo: true              // reloj de mesa al dejar el equipo quieto (Reposo.qml)
    property bool bordeMusica: true         // el borde de la ventana activa con los colores de la carátula (BordeMusica.qml)
    property real escala: 1                 // tamaño de la interfaz: 1, 1.1 o 1.25 (QT_SCALE_FACTOR al arrancar)
    readonly property real escalaActiva: Number(Quickshell.env("QT_SCALE_FACTOR") || 1)
    function guardar() {
        archivo.setText(JSON.stringify({controles:favoritosControles,bandeja:favoritosBandeja,escala:escala,mostrarContinuidad:mostrarContinuidad,panorama:panorama,cieloSolar:cieloSolar,esquinas:esquinas,esquinaActiva:esquinaActiva,reposo:reposo,bordeMusica:bordeMusica}));
    }
    // Cambiar la escala reinicia la barra y los paneles (unos 2 s); los avisos abiertos se pierden.
    function fijarEscala(v) {
        escala = v; guardar();
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/shell.sh", "reiniciar"]);
    }
    property string errorTema: ""
    readonly property bool cambiandoTema: tema.running
    function alternarFavorito(tipo, id) {
        const lista = tipo === "control" ? favoritosControles : favoritosBandeja;
        const nueva = lista.includes(id) ? lista.filter(x => x !== id) : [...lista,id];
        if (tipo === "control") favoritosControles = nueva.slice(-2); else favoritosBandeja = nueva;
        guardar();
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
            try { const p = JSON.parse(text()); ajustes.favoritosControles = p.controles || []; ajustes.favoritosBandeja = p.bandeja || []; ajustes.escala = Number(p.escala) || 1; ajustes.mostrarContinuidad = p.mostrarContinuidad !== false; ajustes.panorama = p.panorama !== false; ajustes.cieloSolar = p.cieloSolar !== false; ajustes.esquinas = p.esquinas !== false; ajustes.esquinaActiva = p.esquinaActiva !== false; ajustes.reposo = p.reposo !== false; ajustes.bordeMusica = p.bordeMusica !== false; } catch (e) { }
        }
    }
    Process {
        id: tema
        onExited: (codigo, estado) => { if (codigo !== 0 || estado !== 0) ajustes.errorTema = "No se pudo actualizar el tema. Se conserva la última paleta válida."; }
    }
}
