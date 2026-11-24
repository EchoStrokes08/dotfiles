// Menú genérico: una lista corta de opciones con icono; cada una ejecuta un comando.
// Lo abre shell.qml con unas opciones concretas, p. ej. el de capturas (SHIFT+PRINT):
//   menu.abrirCon("Capturas", [{ icono: 0xF0A6D, texto: "Región", cmd: "…" }, …])
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

Superpuesta {
    id: menu
    espacio: "menu"
    anchoTarjeta: 340
    alturaRelativa: 0.28

    property string titulo: ""
    property var opciones: []

    function abrirCon(t, ops) {
        titulo = t; opciones = ops; lista.currentIndex = 0;
        abierto = true;
        lista.forceActiveFocus();
    }
    function elegir(op) {
        if (!op) return;
        abierto = false;
        // pequeña espera: que el menú desaparezca antes de, p. ej., hacer una captura
        Quickshell.execDetached(["sh", "-c", "sleep 0.3; " + op.cmd]);
    }

    ColumnLayout {
        width: parent.width
        spacing: 8
        Text {
            text: menu.titulo
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1; capitalization: Font.AllUppercase }
            Layout.leftMargin: 6
        }
        ListView {
            id: lista
            Layout.fillWidth: true
            implicitHeight: count * 44
            interactive: false
            focus: true
            model: menu.opciones
            highlightMoveDuration: 120
            keyNavigationWraps: true
            Keys.onReturnPressed: menu.elegir(menu.opciones[currentIndex])
            Keys.onEnterPressed: menu.elegir(menu.opciones[currentIndex])
            // la misma selección luminosa que el lanzador: superficie, borde y marca del acento con halo
            highlight: FondoSeleccion { radius: EstiloPanel.rControl; marca: true }
            delegate: Item {
                id: opcion
                required property var modelData
                required property int index
                readonly property bool actual: lista.currentIndex === index
                width: lista.width; height: 44
                // entrada escalonada con rebote: cada opción llega un instante después de la anterior
                opacity: 0
                transform: Translate { id: desliz; y: 10 }
                Component.onCompleted: entrada.start()
                Connections { target: menu; function onAbriendose() { entrada.restart(); } }
                SequentialAnimation {
                    id: entrada
                    PropertyAction { target: opcion; property: "opacity"; value: EstiloPanel.movimiento ? 0 : 1 }
                    PropertyAction { target: desliz; property: "y"; value: EstiloPanel.movimiento ? 10 : 0 }
                    PauseAnimation { duration: EstiloPanel.movimiento ? 40 + opcion.index * 35 : 0 }
                    ParallelAnimation {
                        NumberAnimation { target: opcion; property: "opacity"; to: 1; duration: EstiloPanel.normal }
                        NumberAnimation { target: desliz; property: "y"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
                    }
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 16 }
                    spacing: 12
                    Rectangle {   // baldosa del icono: se enciende con la opción elegida
                        implicitWidth: 30; implicitHeight: 30; radius: EstiloPanel.rChip
                        color: opcion.actual ? Qt.alpha(Paleta.acento, .16) : EstiloPanel.relleno
                        border { width: 1; color: opcion.actual ? Qt.alpha(Paleta.acento, .55) : EstiloPanel.borde }
                        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                        RectangularShadow {
                            anchors.fill: parent; z: -1
                            visible: EstiloPanel.profundidad && opcion.actual
                            radius: parent.radius; blur: 14; spread: -2
                            color: Qt.alpha(Paleta.acento, .35)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(opcion.modelData.icono)
                            color: opcion.actual ? Qt.lighter(Paleta.acento, 1.15) : Paleta.acento
                            font { family: Paleta.fuente; pixelSize: 16 }
                            scale: opcion.actual ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: opcion.modelData.texto
                        color: opcion.actual ? Paleta.texto : EstiloPanel.secundario
                        font { family: Paleta.fuente; pixelSize: 13; bold: opcion.actual }
                    }
                    Tecla {   // número: pulsar 1-9 elige directamente
                        Layout.rightMargin: 10
                        texto: opcion.index + 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: lista.currentIndex = index
                    onClicked: menu.elegir(modelData)
                }
            }
            Keys.onPressed: (e) => {
                const n = e.key - Qt.Key_1;
                if (n >= 0 && n < count) { menu.elegir(menu.opciones[n]); e.accepted = true; }
            }
        }
    }
}
