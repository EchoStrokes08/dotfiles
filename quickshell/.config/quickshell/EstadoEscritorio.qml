// Estado escrito atómicamente por el compositor; sin sondeo ni títulos de ventanas.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: estado
    property var datos: ({})
    readonly property string perfil: datos.perfil || "cristal"
    readonly property bool privacidad: datos.privacidad === "true"
    readonly property string motivos: [
        datos.juego_activo === "true" ? "juego" : "",
        datos.bateria === "true" ? "batería" : "",
        datos.concentracion === "true" ? "concentración" : "",
        datos.presentacion === "true" ? "presentación" : "",
        privacidad ? "privacidad" : ""
    ].filter(x => x !== "").join(" · ") || "Sin automatizaciones activas"
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
