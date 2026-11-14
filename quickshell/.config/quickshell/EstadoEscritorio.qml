// Estado escrito atómicamente por el compositor; sin sondeo ni títulos de ventanas.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: estado
    property var datos: ({})
    readonly property string perfil: datos.perfil || "cristal"
    readonly property bool privacidad: capturaPrivada || datos.privacidad_activa === "true" || datos.privacidad === "true"
    readonly property string motivos: [
        datos.juego_activo === "true" ? "juego" : "",
        datos.bateria === "true" ? "batería" : "",
        datos.concentracion === "true" ? "concentración" : "",
        datos.presentacion === "true" ? "presentación" : "",
        datos.reunion === "true" ? "reunión" : privacidad ? "privacidad" : ""
    ].filter(x => x !== "").join(" · ") || "Sin automatizaciones activas"
    property var captura: ({})
    property real ahora: Date.now()
    readonly property bool capturaPrivada: captura.activo === true && Number(captura.expira || 0) > ahora
    Timer { interval: 200; repeat:true; running: estado.captura.activo === true; onTriggered: estado.ahora=Date.now() }
    Process {
        command: ["python3",Quickshell.env("HOME")+"/.config/hypr/scripts/captura_privada.py","estado"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            try { estado.captura=JSON.parse(text); } catch(e) {}
            capturaArchivo.path=Quickshell.env("XDG_RUNTIME_DIR")+"/orion-captura-privada.json";
        } }
    }
    FileView {
        id: capturaArchivo
        watchChanges:true; printErrors:false
        onFileChanged: reload()
        onLoaded: { try { estado.ahora=Date.now();estado.captura=JSON.parse(text()); } catch(e) { estado.captura=({}); } }
    }
    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr-escritorio-" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + ".state"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const nuevo = {};
            for (const linea of text().trim().split("\n")) {
                const partes = linea.split("=");
                if (partes.length === 2) nuevo[partes[0]] = partes[1];
            }
            estado.datos = nuevo;
        }
    }
}
