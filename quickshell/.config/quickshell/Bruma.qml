// Bruma: una mancha elíptica que se difumina hacia todos los lados (degradado radial, sin bordes).
// La usa ClimaVivo.qml para la niebla y las nubes.
//   Bruma { width: 900; height: 300; tono: Paleta.sobreImagen; fuerza: .08 }
// El degradado radial es circular: se dibuja un círculo en un cuadrado y se aplasta en vertical,
// así la elipse se desvanece igual por arriba y por los lados.
import QtQuick
import QtQuick.Shapes

Item {
    id: b
    property color tono: "white"
    property real fuerza: .08            // opacidad en el centro

    Shape {
        width: b.width; height: b.width
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { yScale: b.height / Math.max(1, b.width) }
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: b.width / 2; centerY: b.width / 2
                centerRadius: b.width / 2
                focalX: centerX; focalY: centerY
                GradientStop { position: 0;   color: Qt.alpha(b.tono, b.fuerza) }
                GradientStop { position: .55; color: Qt.alpha(b.tono, b.fuerza * .45) }
                GradientStop { position: 1;   color: "transparent" }
            }
            PathAngleArc { centerX: b.width / 2; centerY: b.width / 2; radiusX: b.width / 2; radiusY: b.width / 2; startAngle: 0; sweepAngle: 360 }
        }
    }
}
