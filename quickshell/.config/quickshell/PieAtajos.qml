// PieAtajos: la fila de atajos al pie de un panel, con cada tecla dibujada como Tecla.
//   PieAtajos { Layout.alignment: Qt.AlignHCenter; atajos: [["↵", "copiar"], ["Supr", "borrar"], ["Esc", "cerrar"]] }
pragma ComponentBehavior: Bound
import QtQuick

Row {
    id: pie
    property var atajos: []            // [[tecla, qué hace], …]; tecla "" = solo texto
    spacing: 16
    Repeater {
        model: pie.atajos
        Row {
            id: atajo
            required property var modelData
            spacing: 6
            Tecla { anchors.verticalCenter: parent.verticalCenter; visible: atajo.modelData[0] !== ""; texto: atajo.modelData[0] }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: atajo.modelData[1]
                color: EstiloPanel.tenue
                font { family: EstiloPanel.fuente; pixelSize: 11 }
            }
        }
    }
}
