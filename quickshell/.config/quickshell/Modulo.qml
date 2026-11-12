// Modulo: una "caja" de la barra (icono + texto), como cada módulo de waybar.
//   Modulo { icono: "…"; texto: "42%"; color: Paleta.azul; ayuda: "tooltip"
//            onClic: (boton) => …;  onRueda: (arriba) => … }
// El tooltip lo pinta Ayuda.qml (una sola ventana emergente para todos los módulos).
import QtQuick
import QtQuick.Layouts

Item {
    id: modulo
    property string icono: ""
    property string texto: ""
    property color color: Paleta.texto
    property color colorTexto: color
    property int tamIcono: 15
    property string ayuda: ""
    property real relleno: 7

    signal clic(int boton)        // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
    signal rueda(bool arriba)
    property var gestorAyuda: null   // la ventana de tooltip compartida (BarraDerecha la pasa)

    implicitWidth: fila.implicitWidth + relleno * 2
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5; anchors.bottomMargin: 5
        radius: height / 2
        color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(modulo.color, .35)), zona.containsMouse ? 0.11 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: fila
        anchors.centerIn: parent
        height: parent.height
        spacing: 6
        // Glifo = centrado óptico (ver Glifo.qml): icono y texto quedan a la misma altura
        Glifo {
            visible: modulo.icono !== ""
            alto: modulo.height
            text: modulo.icono
            color: modulo.color
            font.pixelSize: modulo.tamIcono
        }
        Glifo {
            visible: modulo.texto !== ""
            alto: modulo.height
            text: modulo.texto
            color: modulo.colorTexto
            font { pixelSize: 13; weight: Font.DemiBold; features: { "tnum": 1 } }
        }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => modulo.clic(e.button)
        onWheel: (e) => modulo.rueda(e.angleDelta.y > 0)
        onContainsMouseChanged: {
            if (!modulo.gestorAyuda) return;
            if (containsMouse && modulo.ayuda !== "") modulo.gestorAyuda.mostrar(modulo, modulo.ayuda);
            else modulo.gestorAyuda.ocultar();
        }
    }
}
