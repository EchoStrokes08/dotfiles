// Calendario del mes, empezando en lunes. Las flechas (o la rueda del ratón) cambian de mes.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cal
    property date hoy: new Date()
    property int desfase: 0          // meses respecto al actual (‹ resta, › suma)
    spacing: 6

    readonly property date mes: new Date(hoy.getFullYear(), hoy.getMonth() + desfase, 1)
    // lunes = 0 … domingo = 6 (getDay() da domingo = 0)
    readonly property int hueco: (mes.getDay() + 6) % 7
    readonly property int dias: new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate()

    // Cabecera: ‹ noviembre 2026 ›
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: ""; color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.desfase-- }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cal.mes.toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy")
            color: Paleta.naranja
            font { family: Paleta.fuente; pixelSize: 14; bold: true }
            MouseArea { anchors.fill: parent; onClicked: cal.desfase = 0 }   // clic = volver a hoy
        }
        Text {
            text: ""; color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.desfase++ }
        }
    }

    GridLayout {
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        // L M X J V S D
        Repeater {
            model: ["L", "M", "X", "J", "V", "S", "D"]
            Text {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Paleta.azul : Paleta.gris
                font { family: Paleta.fuente; pixelSize: 11; bold: true }
            }
        }

        // huecos + días del mes
        Repeater {
            model: cal.hueco + cal.dias
            Rectangle {
                readonly property int dia: index - cal.hueco + 1
                readonly property bool esHoy: cal.desfase === 0 && dia === cal.hoy.getDate()
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
                radius: 8
                color: esHoy ? Paleta.naranja : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: dia > 0 ? dia : ""
                    color: parent.esHoy ? Paleta.fondo : Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 12; bold: parent.esHoy }
                }
            }
        }
    }

    WheelHandler { onWheel: (e) => cal.desfase += e.angleDelta.y > 0 ? -1 : 1 }
}
