// BotonCompacto: botón de ancho natural para filas de acciones dentro de una tarjeta
// (Brújula, Móvil, Agente). Para botones que reparten el ancho de una fila, BotonPanel.
//   BotonCompacto { text: "Ver agenda"; destacado: true }
//   BotonCompacto { text: "Borrar"; acento: Paleta.peligro }
import QtQuick
import QtQuick.Controls

Button {
    id: bt
    property bool destacado: false
    property color acento: Paleta.acento
    implicitHeight: 34
    leftPadding: EstiloPanel.e3; rightPadding: EstiloPanel.e3
    hoverEnabled: true
    Accessible.name: text
    scale: down ? .96 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
    background: FondoBoton { tinte: bt.acento; destacado: bt.destacado; encima: bt.hovered; pulsado: bt.down; foco: bt.activeFocus; radio: EstiloPanel.rControl }
    contentItem: Text {
        text: bt.text
        color: !bt.enabled ? EstiloPanel.apagado : bt.destacado || bt.hovered ? Paleta.texto : EstiloPanel.secundario
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font { family: Paleta.fuente; pixelSize: 12; bold: bt.destacado }
    }
}
