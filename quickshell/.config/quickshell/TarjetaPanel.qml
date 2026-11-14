// TarjetaPanel: una sección dentro de un panel (estilo "bento"): fondo translúcido con un leve
// degradado del acento y filo de luz. Lo de dentro va en una columna.
//   TarjetaPanel { acento: Paleta.acento2; Text { … } Otra { Layout.fillWidth: true } }
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: t
    property color acento: Paleta.texto
    property real relleno: 14
    property alias espaciado: interior.spacing
    default property alias contenido: interior.data
    implicitWidth: interior.implicitWidth + relleno * 2
    implicitHeight: interior.implicitHeight + relleno * 2
    radius: 16
    color: EstiloPanel.superficie
    border { width: 1; color: EstiloPanel.borde }
    ColumnLayout {
        id: interior
        anchors { fill: parent; margins: t.relleno }
        spacing: 8
    }
}
