// Glifo: un texto (o icono Nerd Font) centrado ÓPTICAMENTE en vertical.
// Qt centra la "caja" de la letra (ascendente + descendente), pero los iconos Nerd Font
// se dibujan más arriba dentro de esa caja y parecen flotar sobre el texto.
// TextMetrics da el contorno real del dibujo (tightBoundingRect) y con eso se centra lo que se VE.
import QtQuick

Item {
    id: g
    property alias text: etiqueta.text
    property alias color: etiqueta.color
    property alias font: etiqueta.font
    property real alto: 34                // alto de la fila donde se centra (la barra)

    implicitWidth: etiqueta.implicitWidth
    implicitHeight: alto

    TextMetrics { id: medida; font: etiqueta.font; text: etiqueta.text }
    FontMetrics { id: fuente; font: etiqueta.font }

    Text {
        id: etiqueta
        // borde superior del dibujo dentro del Text = ascendente + y del contorno (negativo, desde la línea base)
        y: Math.round((g.alto - medida.tightBoundingRect.height) / 2 - (fuente.ascent + medida.tightBoundingRect.y))
        font.family: Paleta.fuente
        Behavior on color { ColorAnimation { duration: 200 } }
    }
}
