import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: tarjeta
    property string error: EstadoRecarga.error
    property bool detalle: false
    implicitHeight: contenido.implicitHeight + 32
    implicitWidth: 620
    FondoPanel { anchors.fill: parent }
    ColumnLayout {
        id: contenido
        anchors { fill: parent; margins: 16 }
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: "No se pudo cargar la configuración"
            wrapMode: Text.Wrap
            color: Paleta.peligro
            font { family: Paleta.fuente; pixelSize: 16; bold: true }
            Accessible.role: Accessible.AlertMessage
            Accessible.name: text
        }
        Text {
            Layout.fillWidth: true
            text: "Sigue activa la versión anterior. Corrige el error y vuelve a intentarlo."
            wrapMode: Text.Wrap
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 13 }
        }
        ScrollView {
            visible: tarjeta.detalle
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(180, diagnostico.implicitHeight + 16)
            clip: true
            TextArea {
                id: diagnostico
                text: tarjeta.error
                readOnly: true
                wrapMode: TextEdit.Wrap
                color: Paleta.texto
                font { family: Paleta.mono; pixelSize: 12 }
                background: Rectangle { color: EstiloPanel.relleno; radius: EstiloPanel.rChip }
                Accessible.name: "Detalle del error de configuración"
            }
        }
        RowLayout {
            spacing: 8
            BotonCompacto { text: tarjeta.detalle ? "Ocultar detalle" : "Ver detalle"; onClicked: tarjeta.detalle = !tarjeta.detalle }
            BotonCompacto { text: "Reintentar"; destacado: true; onClicked: EstadoRecarga.reintentar() }
        }
    }
}
