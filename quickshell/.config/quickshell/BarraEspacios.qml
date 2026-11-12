// Workspaces de la barra: números, con una píldora de color que se DESLIZA hasta el activo
// y un punto bajo los que tienen ventanas. Rueda del ratón = siguiente/anterior. Clic = ir.
import QtQuick
import QtQuick.Effects
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

    // La píldora: se coloca tras el botón activo y se anima al cambiar
    // (todos los botones miden lo mismo → su posición sale del índice; itemAt() no sería reactivo)
    Item {
        id: pildora
        visible: raiz.activo >= 0
        x: raiz.activo * raiz.anchoBoton + 2
        width: raiz.anchoBoton - 4
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1 } }
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.efectos
            radius: 12; offset.y: 2; blur: 12; spread: -3
            color: Qt.alpha(Paleta.naranja, .55)
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(Qt.lighter(Paleta.naranja, 1.1), .62)) }
                GradientStop { position: 1; color: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.naranja, .38)) }
            }
            border { width: 1; color: Qt.alpha(Qt.lighter(Paleta.naranja, 1.2), .7) }
        }
    }

    Row {
        id: fila
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: botones
            model: raiz.lista

            Item {
                id: boton
                required property var modelData
                readonly property bool ocupado: modelData.toplevels.values.length > 0
                width: raiz.anchoBoton
                height: raiz.height

                Rectangle {   // fondo al pasar el ratón
                    anchors.centerIn: parent
                    width: raiz.anchoBoton - 4; height: 24
                    radius: 12
                    color: Qt.alpha(Paleta.texto, zona.containsMouse && !boton.modelData.active ? 0.09 : 0)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: boton.ocupado && !boton.modelData.active ? -2 : 0
                    text: boton.modelData.id
                    color: boton.modelData.urgent ? Paleta.rojo
                         : boton.modelData.active ? Paleta.texto
                         : boton.ocupado ? Qt.alpha(Paleta.texto, 0.85) : Qt.alpha(Paleta.gris, .9)
                    font { family: Paleta.fuente; pixelSize: 13; weight: boton.modelData.active ? Font.Bold : Font.DemiBold }
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 160 } }
                }
                // punto: tiene ventanas
                Rectangle {
                    visible: boton.ocupado && !boton.modelData.active
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 8 }
                    width: 4; height: 4; radius: 2
                    color: boton.modelData.urgent ? Paleta.rojo : Qt.alpha(Paleta.naranja, .8)
                }
                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: raiz.ir(boton.modelData.id)
                }
            }
        }
    }

    WheelHandler {
        onWheel: (e) => raiz.ir(e.angleDelta.y > 0 ? '"e-1"' : '"e+1"')
    }
}
