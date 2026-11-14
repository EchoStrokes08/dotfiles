// EncabezadoPanel: medalla, nombre del panel (titulo) y la sección en la que estás (seccion), y el botón de cerrar.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: cabecera
    property string seccion: ""
    property string titulo: ""
    property string simbolo: ""
    property color tinte: Paleta.acento
    signal cerrar()
    Layout.fillWidth: true
    implicitHeight: 48
    spacing: 12

    // Medalla del panel
    Rectangle {
        implicitWidth: 40; implicitHeight: 40
        radius: 12
        color: EstiloPanel.elevada
        border { width: 1; color: Qt.alpha(cabecera.tinte, .8) }
        Text {
            anchors.centerIn: parent
            text: cabecera.simbolo
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 20 }
        }
    }
    // Nombre del panel y, debajo, dónde estás dentro de él
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
            Layout.fillWidth: true
            text: cabecera.titulo
            elide: Text.ElideRight
            color: Paleta.texto
            font { family: EstiloPanel.fuente; pixelSize: 20; bold: true }
        }
        Text {
            Layout.fillWidth: true
            visible: cabecera.seccion !== ""
            text: cabecera.seccion
            elide: Text.ElideRight
            color: EstiloPanel.tenue
            font { family: EstiloPanel.fuente; pixelSize: 12 }
        }
    }
    // Cerrar: botón redondo con la tecla debajo
    Button {
        id: cerrar
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 38; implicitHeight: 38
        hoverEnabled: true
        Accessible.name: "Cerrar panel"
        ToolTip.visible: hovered
        ToolTip.text: "Cerrar · Esc"
        ToolTip.delay: 500
        scale: down ? .92 : 1
        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
        background: Rectangle {
            radius: width / 2
            color: cerrar.hovered ? Qt.alpha(Paleta.peligro, .20) : EstiloPanel.rellenoActivo
            border { width: cerrar.activeFocus ? 2 : 1; color: cerrar.activeFocus ? cabecera.tinte : cerrar.hovered ? Qt.alpha(Paleta.peligro, .55) : EstiloPanel.borde }
            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        }
        contentItem: Text {
            text: "󰅖"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: cerrar.hovered ? Paleta.peligro : EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 16 }
        }
        onClicked: cabecera.cerrar()
    }
}
