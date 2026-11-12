import QtQuick
import QtQuick.Layouts

Rectangle {
    id: estado
    property string mensaje: ""
    property string error: ""
    property bool ocupado: false
    readonly property color tinte: error ? Paleta.rojo : ocupado ? Paleta.azul : Paleta.verde
    Layout.fillWidth: true
    implicitHeight: 42
    radius: 10
    color: Qt.alpha(tinte, .065)
    border { width: 1; color: Qt.alpha(tinte, .14) }
    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 10
        Text { text: estado.error ? "!" : estado.ocupado ? "…" : "✓"; color: estado.tinte; font { family: EstiloPanel.fuente; pixelSize: 15; bold: true } }
        Text { Layout.fillWidth: true; text: estado.error || estado.mensaje; color: estado.error ? Paleta.rojo : EstiloPanel.tenue; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; font { family: EstiloPanel.fuente; pixelSize: 12 } }
    }
}
