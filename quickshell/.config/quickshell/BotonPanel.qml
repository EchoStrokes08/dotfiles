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
    implicitHeight: 38
    implicitWidth: 120
    padding: 10
    hoverEnabled: true
    Accessible.name: text
    opacity: enabled ? 1 : .42
    scale: down ? .975 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: EstiloPanel.breve } }
    background: Rectangle {
        radius: 10
        color: b.destacado ? Qt.tint(EstiloPanel.superficie, Qt.alpha(b.tinte, b.hovered ? .30 : .20))
            : b.hovered ? EstiloPanel.elevada : Qt.alpha(Paleta.texto, .035)
        border.width: b.activeFocus ? 2 : 1
        border.color: b.activeFocus ? b.tinte : b.destacado ? Qt.alpha(b.tinte, .55) : EstiloPanel.borde
        Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
        Behavior on border.color { ColorAnimation { duration: EstiloPanel.breve } }
    }
    contentItem: RowLayout {
        spacing: 7
        Text { visible: b.simbolo !== ""; text: b.simbolo; color: b.tinte; font { family: Paleta.fuente; pixelSize: 15 } }
        Text {
            Layout.fillWidth: true
            text: b.text
            color: b.destacado ? Paleta.texto : EstiloPanel.tenue
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font { family: EstiloPanel.fuente; pixelSize: 12; weight: b.destacado ? Font.DemiBold : Font.Medium }
        }
    }
    ToolTip.visible: hovered && etiqueta.truncated
    ToolTip.text: text
    ToolTip.delay: 600
    // Medición independiente: conserva el texto completo cuando el panel se estrecha.
    Text { id: etiqueta; visible: false; width: b.availableWidth - (b.simbolo ? 22 : 0); text: b.text; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12 } }
}
