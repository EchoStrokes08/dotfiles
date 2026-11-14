// Fecha y contexto breve: la hora permanece en la barra.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    spacing: 12
    SystemClock { id: reloj; precision: SystemClock.Minutes }
    Text {
        Layout.fillWidth: true
        readonly property string fecha: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
        text: fecha.charAt(0).toUpperCase() + fecha.slice(1)
        color: Paleta.texto
        font { family: Paleta.fuente; pixelSize: 20; bold: true }
    }
    Text {
        text: "Tu día, a tu ritmo"
        color: EstiloPanel.tenue
        font { family: Paleta.fuente; pixelSize: 12 }
    }
}
