import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: b
    property bool destacado: false
    property string simbolo: ""
    property color tinte: Paleta.naranja
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredWidth: 1
    implicitHeight: 40
    implicitWidth: 120
    padding: 10
    hoverEnabled: true
    Accessible.name: text
    opacity: enabled ? 1 : .42
    scale: down ? .965 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: EstiloPanel.breve } }
    background: FondoBoton {
        tinte: b.tinte
        destacado: b.destacado
        encima: b.hovered
        pulsado: b.down
        foco: b.activeFocus
    }
    // icono + texto centrados juntos; si no cabe, el texto se corta con «…»
    contentItem: Item {
        id: contenido
        implicitHeight: 20
        Row {
            anchors.centerIn: parent
            spacing: icono.visible ? 8 : 0
            Text {
                id: icono
                anchors.verticalCenter: parent.verticalCenter
                visible: b.simbolo !== ""
                text: b.simbolo
                color: b.destacado || b.hovered ? Qt.lighter(b.tinte, 1.08) : Qt.alpha(b.tinte, .85)
                font { family: Paleta.fuente; pixelSize: 15 }
                Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, contenido.width - (icono.visible ? icono.implicitWidth + 8 : 0))
                text: b.text
                color: b.destacado || b.hovered ? Paleta.texto : EstiloPanel.tenue
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font { family: EstiloPanel.fuente; pixelSize: 12; weight: b.destacado ? Font.DemiBold : Font.Medium }
                Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
            }
        }
    }
    ToolTip.visible: hovered && etiqueta.truncated
    ToolTip.text: text
    ToolTip.delay: 600
    // Medición independiente: conserva el texto completo cuando el panel se estrecha.
    Text { id: etiqueta; visible: false; width: b.availableWidth - (b.simbolo ? 23 : 0); text: b.text; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12 } }
}
