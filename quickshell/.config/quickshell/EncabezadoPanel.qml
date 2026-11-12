import QtQuick
import QtQuick.Layouts

RowLayout {
    id: cabecera
    property string seccion: ""
    property string titulo: ""
    property string simbolo: ""
    property color tinte: Paleta.naranja
    signal cerrar()
    Layout.fillWidth: true
    implicitHeight: 60
    spacing: 14
    Rectangle {
        width: 48; height: 48; radius: 15
        color: Qt.alpha(cabecera.tinte, .13)
        border { width: 1; color: Qt.alpha(cabecera.tinte, .25) }
        Text { anchors.centerIn: parent; text: cabecera.simbolo; color: cabecera.tinte; font { family: Paleta.fuente; pixelSize: 24 } }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        Text { Layout.fillWidth: true; text: cabecera.seccion; elide: Text.ElideRight; color: cabecera.tinte; font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 2 } }
        Text { Layout.fillWidth: true; text: cabecera.titulo; elide: Text.ElideRight; color: Paleta.texto; font { family: EstiloPanel.fuente; pixelSize: 25; weight: Font.DemiBold } }
    }
    BotonPanel {
        Layout.fillWidth: false; Layout.preferredWidth: 62
        text: "Esc"
        Accessible.name: "Cerrar panel"
        onClicked: cabecera.cerrar()
    }
}
