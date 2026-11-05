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
        anchors.topMargin: 4; anchors.bottomMargin: 4
        radius: 7
        color: Qt.alpha(Paleta.texto, zona.containsMouse ? 0.08 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
        id: fila
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: modulo.icono !== ""
            text: modulo.icono
            color: modulo.color
            font { family: Paleta.fuente; pixelSize: modulo.tamIcono }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            visible: modulo.texto !== ""
            text: modulo.texto
            color: modulo.colorTexto
            font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
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
