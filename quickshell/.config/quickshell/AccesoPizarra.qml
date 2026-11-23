// Acceso a la Pizarra desde Brújula → Hoy: dice a qué proyecto vas a entrar antes de pulsar.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: b
    property string proyecto: ""
    property string siguiente: ""
    property string simbolo: ""
    Layout.fillWidth: true
    implicitHeight: 64
    padding: 12
    leftPadding: 12
    rightPadding: 16
    hoverEnabled: true
    Accessible.name: "Abrir pizarra" + (proyecto ? " de " + proyecto : "")
    scale: down ? .985 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
    background: FondoBoton {
        radio: EstiloPanel.rTarjeta
        encima: b.hovered
        pulsado: b.down
        foco: b.activeFocus
    }
    contentItem: RowLayout {
        spacing: 12
        // Tres hojas superpuestas: el mismo motivo que el lienzo vacío de la pizarra.
        Item {
            Layout.preferredWidth: 40; Layout.preferredHeight: 40
            Rectangle {
                anchors.fill: parent; radius: EstiloPanel.rControl
                color: Qt.alpha(Paleta.acento, b.hovered ? .22 : .14)
                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 13; height: 16; radius: EstiloPanel.rPunto
                    x: 6 + index * 7; y: 12 - (index === 1 ? 3 : 0)
                    rotation: (index - 1) * 12 * (b.hovered ? 1.5 : 1)
                    color: Qt.alpha(Paleta.fondo, .55)
                    border.width: 1.4
                    border.color: [Paleta.exito, Paleta.acento, Paleta.acento2][index]
                    Behavior on rotation { enabled: EstiloPanel.movimiento; NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutBack } }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: b.proyecto ? "Pizarra · " + b.proyecto : "Pizarra libre"
                color: Paleta.texto
                elide: Text.ElideRight
                font { family: EstiloPanel.fuente; pixelSize: EstiloPanel.t14; weight: Font.DemiBold }
            }
            Text {
                Layout.fillWidth: true
                text: b.siguiente ? "Siguiente: " + b.siguiente : "Reúne PDF, capturas, notas y ventanas en un lienzo"
                color: EstiloPanel.tenue
                elide: Text.ElideRight
                font { family: EstiloPanel.fuente; pixelSize: EstiloPanel.t12 }
            }
        }
        Text {
            text: "→"
            color: b.hovered ? Paleta.acento : EstiloPanel.tenue
            font { family: EstiloPanel.fuente; pixelSize: EstiloPanel.t16 }
            Layout.rightMargin: b.hovered && EstiloPanel.movimiento ? 0 : 4
            Behavior on Layout.rightMargin { NumberAnimation { duration: EstiloPanel.rapido } }
            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        }
    }
}
