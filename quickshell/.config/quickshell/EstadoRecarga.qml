// La generación válida recibe el fallo y continúa atendiendo la interfaz.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: estado
    property string error: ""
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) {
            estado.error = errorString || "Consulta el registro de Quickshell para ver el detalle.";
            Quickshell.inhibitReloadPopup();
        }
        function onReloadCompleted() { estado.error = ""; }
    }
    function reintentar() { Quickshell.reload(false); }
}
