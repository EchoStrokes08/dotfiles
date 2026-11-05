// Anillo: un indicador circular (CPU, RAM…). Se usa así:
//   Anillo { valor: 0.42; color: Paleta.azul; etiqueta: "CPU"; texto: "42%" }
import QtQuick
import QtQuick.Shapes

Item {
    id: anillo
    property real valor: 0          // 0..1
    property color color: Paleta.naranja
    property string etiqueta: ""
    property string texto: ""
    property real grosor: 7

    implicitWidth: 96
    implicitHeight: 96

    // valor animado: el arco se desliza en vez de saltar
    property real mostrado: Math.max(0, Math.min(1, valor))
    Behavior on mostrado { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer   // bordes suaves

        // pista (el círculo de fondo)
        ShapePath {
            strokeColor: Qt.alpha(Paleta.texto, 0.10)
            strokeWidth: anillo.grosor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anillo.width / 2; centerY: anillo.height / 2
                radiusX: anillo.width / 2 - anillo.grosor; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        // el valor, empezando arriba (-90°) en sentido horario
        ShapePath {
            strokeColor: anillo.color
            strokeWidth: anillo.grosor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: anillo.width / 2; centerY: anillo.height / 2
                radiusX: anillo.width / 2 - anillo.grosor; radiusY: radiusX
                startAngle: -90; sweepAngle: 360 * anillo.mostrado
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: anillo.texto
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 17; bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: anillo.etiqueta
            color: anillo.color
            font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1 }
        }
    }
}
