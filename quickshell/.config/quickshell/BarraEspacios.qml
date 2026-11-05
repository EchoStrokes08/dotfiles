// Workspaces de la barra: números, con una raya naranja que se DESLIZA hasta el activo.
// Rueda del ratón = workspace siguiente/anterior. Clic = ir.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: raiz
    property var monitor: null           // HyprlandMonitor de la pantalla de esta barra

    readonly property int anchoBoton: 30
    implicitWidth: fila.implicitWidth
    implicitHeight: 34

    function ir(destino) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${destino} })`);
    }

    // Workspaces normales de ESTE monitor, en orden
    readonly property var lista: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (!raiz.monitor || w.monitor?.name === raiz.monitor.name))
        .sort((a, b) => a.id - b.id)
    readonly property int activo: lista.findIndex(w => w.active)

    Row {
        id: fila
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: botones
            model: raiz.lista

            Item {
                required property var modelData
                readonly property bool ocupado: modelData.toplevels.values.length > 0
                width: raiz.anchoBoton
                height: raiz.height

                Rectangle {   // fondo al pasar el ratón
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 6
                    color: Qt.alpha(Paleta.texto, zona.containsMouse && !modelData.active ? 0.08 : 0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    color: modelData.urgent ? Paleta.rojo
                         : modelData.active ? Paleta.naranja
                         : ocupado ? Qt.alpha(Paleta.texto, 0.75) : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: raiz.ir(modelData.id)
                }
            }
        }
    }

    // La raya: se coloca bajo el botón activo y se anima al cambiar
    // (todos los botones miden lo mismo → su posición sale del índice; itemAt() no sería reactivo)
    Rectangle {
        visible: raiz.activo >= 0
        y: raiz.height - 2
        height: 2
        radius: 1
        color: Paleta.naranja
        x: raiz.activo * raiz.anchoBoton + 6
        width: raiz.anchoBoton - 12
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    WheelHandler {
        onWheel: (e) => raiz.ir(e.angleDelta.y > 0 ? '"e-1"' : '"e+1"')
    }
}
