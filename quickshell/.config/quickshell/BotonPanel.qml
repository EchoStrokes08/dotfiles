import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: b
    property bool destacado: false
    property string simbolo: ""
    property color tinte: Paleta.acento
    // confirmando: el clic siguiente hace algo irreversible → rojo de peligro, sacudida corta al pedirlo
    // y halo que late (FondoBoton.alerta) mientras espera
    property bool confirmando: false
    transform: Translate { id: desplazar }
    onConfirmandoChanged: if (confirmando && EstiloPanel.movimiento) sacudida.restart()
    SequentialAnimation {
        id: sacudida
        NumberAnimation { target: desplazar; property: "x"; to: -5; duration: 45 }
        NumberAnimation { target: desplazar; property: "x"; to: 4;  duration: 60 }
        NumberAnimation { target: desplazar; property: "x"; to: -2; duration: 60 }
        NumberAnimation { target: desplazar; property: "x"; to: 0;  duration: 45 }
    }
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredWidth: 1
    implicitHeight: 40
    implicitWidth: 120
    padding: 8
    hoverEnabled: true
    Accessible.name: text
    opacity: enabled ? 1 : .42
    scale: down ? .965 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
    readonly property color tinteReal: confirmando ? Paleta.peligro : tinte
    background: FondoBoton {
        tinte: b.tinteReal
        destacado: b.destacado || b.confirmando
        alerta: b.confirmando
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
                color: b.destacado || b.confirmando || b.hovered ? Qt.lighter(b.tinteReal, 1.08) : Qt.alpha(b.tinteReal, .85)
                font { family: Paleta.fuente; pixelSize: 14 }
                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, contenido.width - (icono.visible ? icono.implicitWidth + 8 : 0))
                text: b.text
                color: b.confirmando ? Qt.lighter(Paleta.peligro, 1.1) : b.destacado || b.hovered ? Paleta.texto : EstiloPanel.tenue
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font { family: EstiloPanel.fuente; pixelSize: 12; weight: b.destacado || b.confirmando ? Font.DemiBold : Font.Medium }
                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            }
        }
    }
    ToolTip.visible: hovered && etiqueta.truncated
    ToolTip.text: text
    ToolTip.delay: 600
    // Medición independiente: conserva el texto completo cuando el panel se estrecha.
    Text { id: etiqueta; visible: false; width: b.availableWidth - (b.simbolo ? 23 : 0); text: b.text; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12 } }
}
