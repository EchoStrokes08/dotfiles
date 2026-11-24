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
    // Es «líquida»: sus dos bordes se mueven por separado. El delantero sale enseguida y el trasero
    // lo sigue con retraso, así se estira como una gota hacia el destino y se recoge al llegar.
    // sin enlaces a «activo»: si los tuvieran, saltarían al instante antes de que empiece la gota
    property real izq: 2
    property real der: anchoBoton - 2
    property int previo: -1
    Component.onCompleted: { previo = activo; izq = Math.max(0, activo) * anchoBoton + 2; der = izq + anchoBoton - 4; }
    onActivoChanged: {
        const x0 = activo * anchoBoton + 2, x1 = x0 + anchoBoton - 4;
        if (!EstiloPanel.movimiento || previo < 0 || activo < 0) { gota.stop(); izq = x0; der = x1; previo = activo; return; }
        const avanza = activo > previo;
        bordeDelantero.target = raiz; bordeDelantero.property = avanza ? "der" : "izq"; bordeDelantero.to = avanza ? x1 : x0;
        bordeTrasero.target = raiz;   bordeTrasero.property   = avanza ? "izq" : "der"; bordeTrasero.to   = avanza ? x0 : x1;
        previo = activo;
        gota.restart();
    }
    ParallelAnimation {
        id: gota
        NumberAnimation { id: bordeDelantero; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { id: bordeTrasero; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }
    Item {
        id: pildora
        visible: raiz.activo >= 0
        x: raiz.izq
        width: raiz.der - raiz.izq
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        RectangularShadow {
            anchors.fill: parent
            visible: EstiloPanel.profundidad
            radius: 12; offset.y: 2; blur: 12; spread: -3
            color: Qt.alpha(Paleta.acento, .55)
        }
        Rectangle {
            anchors.fill: parent
            radius: 12
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(Qt.lighter(Paleta.acento, 1.1), .62)) }
                GradientStop { position: 1; color: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.acento, .38)) }
            }
            border { width: 1; color: Qt.alpha(Qt.lighter(Paleta.acento, 1.2), .7) }
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
                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: boton.ocupado && !boton.modelData.active ? -2 : 0
                    text: boton.modelData.id
                    color: boton.modelData.urgent ? Paleta.peligro
                         : boton.modelData.active ? Paleta.texto
                         : boton.ocupado ? EstiloPanel.secundario : Qt.alpha(Paleta.gris, .9)
                    font { family: Paleta.fuente; pixelSize: 13; weight: boton.modelData.active ? Font.Bold : Font.DemiBold }
                    Behavior on color { ColorAnimation { duration: EstiloPanel.normal } }
                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: EstiloPanel.rapido } }
                }
                // punto: tiene ventanas (urgente: rojo, con un halo que late hasta que vas)
                Item {
                    visible: boton.ocupado && !boton.modelData.active
                    anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 8 }
                    width: 4; height: 4
                    property real latido: 0
                    SequentialAnimation on latido {
                        running: boton.modelData.urgent && EstiloPanel.movimiento
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 600; easing.type: Easing.InOutSine }
                    }
                    RectangularShadow {
                        anchors.fill: parent
                        visible: EstiloPanel.profundidad && boton.modelData.urgent
                        radius: width / 2; blur: 6 + 6 * parent.latido; spread: 1
                        color: Qt.alpha(Paleta.peligro, .5 + .4 * parent.latido)
                    }
                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: boton.modelData.urgent ? Paleta.peligro : Qt.alpha(Paleta.acento, .8)
                    }
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
