// Aviso persistente de error, independiente del centro de notificaciones y No molestar.
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    PanelWindow {
        visible: EstadoRecarga.error !== ""
        anchors { top: true; right: true }
        margins { top: 50; right: 16 }
        implicitWidth: Math.min(620, (screen?.width ?? 1280) - 32)
        implicitHeight: tarjeta.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-error-recarga"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        TarjetaRecarga { id: tarjeta; anchors.fill: parent }
    }
}
