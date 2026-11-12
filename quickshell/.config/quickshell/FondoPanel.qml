// FondoPanel: el "cristal" de todas las ventanas flotantes (dashboard, lanzador, centro de control,
// Superpuesta…). Se pone como primer hijo de la tarjeta:  FondoPanel { anchors.fill: parent; acento: … }
//   · sombra suave que separa la tarjeta del fondo + halo difuso del color del panel
//   · degradado vertical con un toque del acento arriba (se nota el color del panel sin teñirlo todo)
//   · dos luces radiales (acento arriba a la izquierda, morado abajo a la derecha) que dan profundidad
//   · filo de luz en el borde superior, como el canto de un cristal
// En los perfiles mínimo/rendimiento, con batería o jugando (EstiloPanel.efectos) quita sombras y luces.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: f
    property color acento: Paleta.naranja
    property color acento2: Paleta.morado
    property real radio: 22
    property real opacidad: 0.84          // con el blur de Hyprland detrás, < 0.9 se ve "cristal"
    property bool luces: EstiloPanel.efectos

    // Sombra y halo: fuera de la tarjeta (no recortan)
    RectangularShadow {
        anchors.fill: parent
        visible: f.luces
        radius: f.radio
        offset.y: 18
        blur: 48
        spread: -6
        color: Qt.alpha("black", .42)
    }
    RectangularShadow {
        anchors.fill: parent
        visible: f.luces
        radius: f.radio
        blur: 70
        spread: -20
        color: Qt.alpha(f.acento, .14)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Cuerpo: degradado vertical
        ShapePath {
            strokeWidth: 1
            strokeColor: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(f.acento, .55)), .16)
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: f.height
                GradientStop { position: 0;   color: Qt.alpha(Qt.tint(Paleta.fondo, Qt.alpha(f.acento, .09)), f.opacidad) }
                GradientStop { position: .38; color: Qt.alpha(Paleta.fondo, f.opacidad) }
                GradientStop { position: 1;   color: Qt.alpha(Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .025)), Math.min(1, f.opacidad + .05)) }
            }
            PathRectangle { x: .5; y: .5; width: f.width - 1; height: f.height - 1; radius: f.radio }
        }
        // Luz del acento (arriba a la izquierda)
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: f.width * .16; centerY: -f.height * .05
                centerRadius: Math.max(260, Math.min(f.width, 900) * .62)
                focalX: centerX; focalY: centerY
                GradientStop { position: 0;   color: Qt.alpha(f.acento, f.luces ? .17 : .08) }
                GradientStop { position: .55; color: Qt.alpha(f.acento, f.luces ? .05 : .02) }
                GradientStop { position: 1;   color: "transparent" }
            }
            PathRectangle { x: 1; y: 1; width: f.width - 2; height: f.height - 2; radius: f.radio - 1 }
        }
        // Contraluz frío (abajo a la derecha)
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: f.width * .96; centerY: f.height * 1.04
                centerRadius: Math.max(220, Math.min(f.width, 800) * .5)
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: Qt.alpha(f.acento2, f.luces ? .09 : 0) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { x: 1; y: 1; width: f.width - 2; height: f.height - 2; radius: f.radio - 1 }
        }
    }

    // Bisel interior: un segundo filo, más tenue, 1 px hacia dentro (cristal grueso)
    Rectangle {
        anchors { fill: parent; margins: 1.5 }
        radius: f.radio - 1.5
        color: "transparent"
        border { width: 1; color: Qt.alpha(Paleta.texto, .035) }
    }
    // Filo de luz superior
    Rectangle {
        x: f.radio * .8; y: 1
        width: f.width - f.radio * 1.6; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;  color: "transparent" }
            GradientStop { position: .3; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(f.acento, .4)), .30) }
            GradientStop { position: .7; color: Qt.alpha(Paleta.texto, .14) }
            GradientStop { position: 1;  color: "transparent" }
        }
    }
}
