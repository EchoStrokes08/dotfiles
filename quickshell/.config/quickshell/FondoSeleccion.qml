// FondoSeleccion: el fondo de cualquier elemento elegido (pestaña activa, fila actual, botón destacado).
// Superficie neutra, borde del acento y, si se pide, una marca lateral. Sin degradados ni resplandor
// de color: con acentos cálidos el tinte se volvía marrón (ORION 5.3, docs/diseno.md).
import QtQuick

Rectangle {
    id: s
    property bool encima: false
    property bool marca: false        // barra de 3 px a la izquierda (filas de lista)
    property color tinte: Paleta.acento
    radius: EstiloPanel.rControl
    color: encima ? EstiloPanel.seleccionadoEncima : EstiloPanel.seleccionado
    border { width: 1; color: Qt.alpha(s.tinte, .8) }
    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    Rectangle {
        visible: s.marca
        width: 3; height: parent.height - 20; radius: 4
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        color: s.tinte
    }
}
