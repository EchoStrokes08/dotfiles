// Menú genérico: una lista corta de opciones con icono; cada una ejecuta un comando.
// Lo abre shell.qml con unas opciones concretas, p. ej. el de capturas (SHIFT+PRINT):
//   menu.abrirCon("Capturas", [{ icono: 0xF0A6D, texto: "Región", cmd: "…" }, …])
import QtQuick
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
            highlight: Rectangle {
                radius: 9
                color: Qt.alpha(Paleta.naranja, 0.13)
                Rectangle { width: 3; height: parent.height - 14; radius: 2; color: Paleta.naranja
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } }
            }
            delegate: Item {
                required property var modelData
                required property int index
                width: lista.width; height: 44
                RowLayout {
                    anchors { fill: parent; leftMargin: 18 }
                    spacing: 14
                    Text { text: String.fromCodePoint(modelData.icono); color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 18 } }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.texto
                        color: lista.currentIndex === index ? Paleta.texto : Qt.alpha(Paleta.texto, 0.8)
                        font { family: Paleta.fuente; pixelSize: 13; bold: lista.currentIndex === index }
                    }
                    Text {   // número: pulsar 1-9 elige directamente
                        Layout.rightMargin: 12
                        text: index + 1
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 10 }
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
