// Confirmar el lanzamiento no significa que la tarea personal esté hecha.
import QtQuick
import Quickshell
import Quickshell.Io

BotonCompacto {
    id: boton
    property var comando: []
    property string etiqueta: "Abrir"
    property bool confirmado: false
    property string error: ""
    signal comenzando()
    text: EstadoEscritorio.privacidad ? "Acción privada" : proceso.running ? "Abriendo…" : error ? "Reintentar" : confirmado ? "Solicitud enviada" : etiqueta
    enabled: !EstadoEscritorio.privacidad && !proceso.running && comando.length > 0
    onClicked: {
        if (!comando.length) return;
        error="";confirmado=false;comenzando();esperar.start();
    }
    Timer { id: esperar; interval: 90; onTriggered: { proceso.command=boton.comando; proceso.running=true; } }
    Process {
        id: proceso
        onExited: (codigo,estado) => {
            if (codigo===0 && estado===0) {
                boton.confirmado=true;
                Quickshell.execDetached(["notify-send","-a","ORION","Solicitud enviada","Se confirmó el inicio de la acción; la tarea personal sigue bajo tu control."]);
            } else {
                boton.error="No se pudo iniciar";
                Quickshell.execDetached(["notify-send","-a","ORION","No se pudo iniciar la acción","Vuelve a abrir Brújula para reintentar."]);
            }
        }
    }
}
