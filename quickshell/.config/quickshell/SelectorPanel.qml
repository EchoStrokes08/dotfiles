import QtQuick
import QtQuick.Controls

ComboBox {
    id: selector
    implicitHeight: 32
    font { family: Paleta.fuente; pixelSize: 12 }
    palette { window: Paleta.fondo; base: Paleta.fondo; text: Paleta.texto; buttonText: Paleta.texto; highlight: Paleta.acento; highlightedText: Paleta.sobreAcento }
    background: Rectangle { radius: EstiloPanel.rControl; color: EstiloPanel.elevada; border { width: selector.activeFocus ? 2 : 1; color: selector.activeFocus ? Paleta.acento : EstiloPanel.bordeFuerte } }
}
