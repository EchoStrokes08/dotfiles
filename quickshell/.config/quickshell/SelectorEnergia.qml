import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.UPower

TarjetaPanel {
    id: energia
    property string aviso: ""
    readonly property var opciones: {
        const perfiles = [
            {nombre: "Ahorro de energía", id: "power-saver", perfil: PowerProfile.PowerSaver},
            {nombre: "Equilibrado", id: "balanced", perfil: PowerProfile.Balanced}
        ];
        if (PowerProfiles.hasPerformanceProfile)
            perfiles.push({nombre: "Máximo rendimiento", id: "performance", perfil: PowerProfile.Performance});
        return perfiles;
    }
    function indiceActual() { return opciones.findIndex(p => p.perfil === PowerProfiles.profile); }
    function elegir(indice) {
        if (cambio.running || indice < 0 || indice >= opciones.length) return;
        aviso = "";
        cambio.destino = opciones[indice].id;
        cambio.running = true;
    }
    relleno: 12
    espaciado: 8
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
            text: "Energía"
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 13; bold: true }
        }
        SelectorPanel {
            id: selector
            objectName: "perfilEnergia"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            model: energia.opciones
            textRole: "nombre"
            valueRole: "id"
            currentIndex: energia.indiceActual()
            enabled: !cambio.running
            Accessible.name: "Perfil de energía del equipo"
            onActivated: (indice) => energia.elegir(indice)
        }
    }
    Text {
        Layout.fillWidth: true
        text: cambio.running ? "Aplicando perfil…"
            : PowerProfiles.profile === PowerProfile.Performance ? "Máxima potencia disponible · mayor consumo y calor."
            : PowerProfiles.profile === PowerProfile.PowerSaver ? "Prioriza la autonomía y reduce el consumo."
            : "Equilibra rendimiento y consumo."
        wrapMode: Text.Wrap
        color: EstiloPanel.tenue
        font { family: Paleta.fuente; pixelSize: 12 }
    }
    Text {
        Layout.fillWidth: true
        visible: energia.aviso !== ""
        text: energia.aviso
        wrapMode: Text.Wrap
        color: Paleta.peligro
        font { family: Paleta.fuente; pixelSize: 12 }
    }
    Process {
        id: cambio
        property string destino: "balanced"
        command: ["sh", "-c", "powerprofilesctl set \"$1\" && powerprofilesctl get", "perfil-energia", destino]
        stdout: StdioCollector { id: resultado }
        stderr: StdioCollector { }
        onExited: (codigo, estadoSalida) => {
            if (codigo !== 0 || estadoSalida !== 0)
                energia.aviso = "No se pudo cambiar el perfil de energía. Inténtalo de nuevo.";
            else if (resultado.text.trim() !== destino)
                energia.aviso = "El sistema no confirmó el perfil elegido. Revisa el modo activo.";
            selector.currentIndex = Qt.binding(() => energia.indiceActual());
        }
    }
}
