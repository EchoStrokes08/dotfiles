// Modulo: una "caja" de la barra (icono + texto).
//   Modulo { icono: "…"; texto: "42%"; color: Paleta.acento2; ayuda: "tooltip"
//            onClic: (boton) => …;  onRueda: (arriba) => … }
// El tooltip lo pinta Ayuda.qml (una sola ventana emergente para todos los módulos).
import QtQuick
import QtQuick.Effects
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
    // Para lectores de pantalla: la primera línea de la ayuda (o el texto) y que se puede pulsar
    Accessible.role: Accessible.Button
    Accessible.name: (ayuda.split("\n")[0] || texto)

    signal clic(int boton)        // Qt.LeftButton, Qt.RightButton, Qt.MiddleButton
    signal rueda(bool arriba)
    property var gestorAyuda: null   // la ventana de tooltip compartida (BarraDerecha la pasa)

    implicitWidth: fila.implicitWidth + relleno * 2
    implicitHeight: 34

    // Estado destacado (un color que no es el del texto: cargando, batería baja, silencio…):
    // cápsula tenue de su color con halo. Al cambiar de estado, el halo destella y vuelve.
    readonly property bool destaca: !Qt.colorEqual(color, Paleta.texto)
    property real destello: 0
    onColorChanged: if (destaca && EstiloPanel.movimiento) animDestello.restart()
    NumberAnimation { id: animDestello; target: modulo; property: "destello"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }
    RectangularShadow {
        anchors.fill: parent; anchors.topMargin: 5; anchors.bottomMargin: 5
        visible: EstiloPanel.profundidad && modulo.destaca
        radius: height / 2; blur: 14 + 10 * modulo.destello; spread: -2
        color: Qt.alpha(modulo.color, .22 + .45 * modulo.destello)
    }
    Rectangle {
        anchors.fill: parent; anchors.topMargin: 5; anchors.bottomMargin: 5
        visible: modulo.destaca
        radius: height / 2
        color: Qt.alpha(modulo.color, .10 + .12 * modulo.destello)
        border { width: 1; color: Qt.alpha(modulo.color, .28) }
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5; anchors.bottomMargin: 5
        radius: height / 2
        color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(modulo.color, .35)), zona.containsMouse ? 0.11 : 0)
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
    }

    RowLayout {
        id: fila
        anchors.centerIn: parent
        height: parent.height
        spacing: 4
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
