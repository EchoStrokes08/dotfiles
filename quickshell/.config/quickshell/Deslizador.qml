// Deslizador (volumen, brillo…). valor de 0 a 1; emite "movido" al arrastrar o con la rueda.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

RowLayout {
    id: raiz
    property real valor: 0
    property string icono: ""
    property string etiqueta: ""            // nombre a la izquierda (volumen por app)
    property bool apagado: false
    property color acento: Paleta.naranja
    signal movido(real v)
    signal iconoPulsado()
    spacing: 10
    readonly property real v: Math.max(0, Math.min(1, valor))
    readonly property color tono: apagado ? Paleta.gris : acento

    // Icono en una pastilla (clic = silenciar)
    Rectangle {
        implicitWidth: 32; implicitHeight: 32; radius: 11
        color: zonaIcono.containsMouse ? Qt.alpha(raiz.tono, .26) : Qt.alpha(raiz.tono, raiz.apagado ? .08 : .15)
        border { width: 1; color: Qt.alpha(raiz.tono, .28) }
        Behavior on color { ColorAnimation { duration: 140 } }
        Text {
            anchors.centerIn: parent
            text: raiz.icono
            color: raiz.tono
            font { family: Paleta.fuente; pixelSize: 15 }
        }
        MouseArea { id: zonaIcono; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: raiz.iconoPulsado() }
    }
    Text {
        visible: raiz.etiqueta !== ""
        Layout.preferredWidth: 90
        text: raiz.etiqueta
        color: Paleta.texto
        elide: Text.ElideRight
        font { family: Paleta.fuente; pixelSize: 11 }
    }
    Item {
        id: pista
        Layout.fillWidth: true
        implicitHeight: 22
        Rectangle {
            id: carril
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: zona.containsMouse || zona.pressed ? 10 : 8; radius: height / 2
            color: Qt.alpha(Paleta.texto, 0.10)
            border { width: 1; color: Qt.alpha(Paleta.texto, .05) }
            Behavior on height { NumberAnimation { duration: 120 } }
            RectangularShadow {   // resplandor bajo la parte llena
                width: relleno.width; height: parent.height
                visible: EstiloPanel.efectos && !raiz.apagado && raiz.v > 0
                radius: parent.radius; blur: 12; spread: -2
                color: Qt.alpha(raiz.tono, .35)
            }
            Rectangle {
                id: relleno
                height: parent.height; radius: parent.radius
                width: Math.max(height, parent.width * raiz.v)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(raiz.tono, .55) }
                    GradientStop { position: 1; color: raiz.apagado ? raiz.tono : Qt.lighter(raiz.tono, 1.12) }
                }
            }
        }
        Rectangle {   // tirador
            width: 16; height: 16; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            x: (pista.width - width) * raiz.v
            color: "white"
            border { width: 3; color: raiz.tono }
            scale: zona.pressed ? 1.2 : zona.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function mover(x) { raiz.movido(Math.max(0, Math.min(1, x / pista.width))); }
            onPressed: (e) => mover(e.x)
            onPositionChanged: (e) => { if (pressed) mover(e.x); }
            onWheel: (e) => raiz.movido(Math.max(0, Math.min(1, raiz.valor + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text {
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
        text: Math.round(raiz.valor * 100) + "%"
        color: raiz.apagado ? Paleta.gris : Paleta.texto
        font { family: Paleta.fuente; pixelSize: 11; bold: true; features: { "tnum": 1 } }   // cifras de igual ancho
    }
}
