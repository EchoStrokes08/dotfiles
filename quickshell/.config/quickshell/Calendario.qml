// Calendario del mes, empezando en lunes. Las flechas (o la rueda del ratón) cambian de mes.
// Clic en un día = elegirlo (para crear un evento o tarea ese día; ver NuevoEvento.qml).
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cal
    property date hoy: new Date()
    property int desfase: 0          // meses respecto al actual (‹ resta, › suma)
    property date elegido: new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
    property bool conMas: false      // muestra el ＋ (nuevo evento/tarea el día elegido) en la cabecera
    signal nuevo()
    spacing: 4

    readonly property date mes: new Date(hoy.getFullYear(), hoy.getMonth() + desfase, 1)
    // lunes = 0 … domingo = 6 (getDay() da domingo = 0)
    readonly property int hueco: (mes.getDay() + 6) % 7
    readonly property int dias: new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate()

    // Cabecera: ‹ noviembre 2026 ›
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: ""; color: Paleta.gris
            font { family: Paleta.mono; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.desfase-- }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cal.mes.toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy")
            color: Paleta.acento
            font { family: Paleta.fuente; pixelSize: 14; bold: true }
            MouseArea {   // clic = volver a hoy
                anchors.fill: parent
                onClicked: { cal.desfase = 0; cal.elegido = new Date(cal.hoy.getFullYear(), cal.hoy.getMonth(), cal.hoy.getDate()); }
            }
        }
        Text {
            text: ""; color: Paleta.gris
            font { family: Paleta.mono; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.desfase++ }
        }
        Rectangle {   // ＋ = nuevo evento o tarea el día elegido
            visible: cal.conMas
            Layout.leftMargin: 4
            implicitWidth: 22; implicitHeight: 22; radius: height / 2
            color: mas.containsMouse ? Paleta.acento : Qt.alpha(Paleta.acento, .18)
            Text {
                anchors.centerIn: parent
                text: "\uF067"
                color: mas.containsMouse ? Paleta.fondo : Paleta.acento
                font { family: Paleta.mono; pixelSize: 11; bold: true }
            }
            MouseArea { id: mas; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.nuevo() }
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
                color: index >= 5 ? Paleta.acento2 : Paleta.gris
                font { family: Paleta.fuente; pixelSize: 11; bold: true }
            }
        }

        // huecos + días del mes
        Repeater {
            model: cal.hueco + cal.dias
            Rectangle {
                readonly property int dia: index - cal.hueco + 1
                readonly property bool esHoy: cal.desfase === 0 && dia === cal.hoy.getDate()
                readonly property date fecha: new Date(cal.mes.getFullYear(), cal.mes.getMonth(), dia)
                readonly property bool esElegido: dia > 0 && fecha.getTime() === cal.elegido.getTime()
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
                radius: 8
                color: esHoy ? Paleta.acento : "transparent"
                border { width: esElegido && !esHoy ? 1.5 : 0; color: Paleta.acento }
                MouseArea {
                    anchors.fill: parent
                    enabled: dia > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: cal.elegido = parent.fecha
                }
                Text {
                    anchors.centerIn: parent
                    text: dia > 0 ? dia : ""
                    color: parent.esHoy ? Paleta.sobreAcento : Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 12; bold: parent.esHoy }
                }
                // puntito = ese día hay algo fuera de la rutina diaria (Eventos.marcaEn)
                Rectangle {
                    visible: dia > 0 && Eventos.marcaEn(parent.fecha)
                    width: 4; height: 4; radius: height / 2
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                    color: parent.esHoy ? Paleta.sobreAcento : Paleta.acento2
                }
            }
        }
    }

    WheelHandler { onWheel: (e) => cal.desfase += e.angleDelta.y > 0 ? -1 : 1 }
}
