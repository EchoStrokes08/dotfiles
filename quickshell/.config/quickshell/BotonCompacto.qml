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
    implicitHeight: 34
    leftPadding: EstiloPanel.e3; rightPadding: EstiloPanel.e3
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) click(); }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) click(); }
    Accessible.name: text
    scale: down ? .96 : 1
    Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
    background: FondoBoton { tinte: bt.confirmando ? Paleta.peligro : bt.acento; destacado: bt.destacado || bt.confirmando; alerta: bt.confirmando; encima: bt.hovered; pulsado: bt.down; foco: bt.activeFocus; radio: EstiloPanel.rControl }
    contentItem: Text {
        text: bt.text
        color: !bt.enabled ? EstiloPanel.apagado : bt.confirmando ? Qt.lighter(Paleta.peligro, 1.1) : bt.destacado || bt.hovered ? Paleta.texto : EstiloPanel.secundario
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font { family: Paleta.fuente; pixelSize: 12; bold: bt.destacado || bt.confirmando }
    }
}
