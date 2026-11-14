// La acción principal y los paneles usan el mismo despachador y la misma validación.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio
    property var cola: []
    signal completada(var resultado)
    function ejecutar(ref, accion, valores) {
        cola=[...cola,{ref:ref,accion:accion,valores:valores || {}}]; siguiente();
    }
    function siguiente() {
        if (orden.running || !cola.length) return;
        const dato=cola[0];cola=cola.slice(1);orden.respuesta=null;
        orden.command=["python3",Quickshell.env("HOME")+"/.config/hypr/scripts/acciones.py","ejecutar",JSON.stringify(dato)];orden.running=true;
    }
    Process {
        id: orden
        property var respuesta: null
        stdout: StdioCollector { onStreamFinished: { try { orden.respuesta=JSON.parse(text); } catch(e) {} } }
        onExited: (codigo,estado) => {
            const r=respuesta || {ok:false,error:"El servicio de acciones no respondió."};
            if (codigo!==0 || estado!==0 || !r.ok) {
                Quickshell.execDetached(["notify-send","-a","ORION","No se pudo completar la acción",r.error || "Reintenta desde el lanzador."]);
            } else Quickshell.execDetached(["notify-send","-a","ORION","Acción confirmada",EstadoEscritorio.privacidad ? "Operación completada" : r.mensaje]);
            servicio.completada(r);Qt.callLater(servicio.siguiente);
        }
    }
}
