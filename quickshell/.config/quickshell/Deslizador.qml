// Deslizador (volumen, brillo…). valor de 0 a 1; emite "movido" al arrastrar o con la rueda.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: raiz
    property real valor: 0
    property string icono: ""
    property string etiqueta: ""            // nombre a la izquierda (volumen por app)
    property bool apagado: false
    signal movido(real v)
    signal iconoPulsado()
    spacing: 10

    Text {
        text: raiz.icono
        color: raiz.apagado ? Paleta.gris : Paleta.naranja
        font { family: Paleta.fuente; pixelSize: 16 }
        Layout.preferredWidth: 20
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: raiz.iconoPulsado() }
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
        implicitHeight: 18
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Qt.alpha(Paleta.texto, 0.12)
            Rectangle {
                height: parent.height; radius: 3
                width: parent.width * Math.max(0, Math.min(1, raiz.valor))
                color: raiz.apagado ? Paleta.gris : Paleta.naranja
            }
        }
        Rectangle {   // tirador
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: (pista.width - width) * Math.max(0, Math.min(1, raiz.valor))
            color: Paleta.texto
            scale: zona.pressed || zona.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            function mover(x) { raiz.movido(Math.max(0, Math.min(1, x / pista.width))); }
            onPressed: (e) => mover(e.x)
            onPositionChanged: (e) => { if (pressed) mover(e.x); }
            onWheel: (e) => raiz.movido(Math.max(0, Math.min(1, raiz.valor + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text {
        Layout.preferredWidth: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(raiz.valor * 100) + "%"
        color: Paleta.gris
        font { family: Paleta.fuente; pixelSize: 11 }
    }
}
