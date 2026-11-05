// Ayuda: el tooltip de la barra. Una sola ventana emergente que se recoloca bajo el módulo
// que tenga el ratón encima. Aparece tras una pausa corta para no parpadear al pasar de largo.
import QtQuick
import Quickshell

PopupWindow {
    id: ayuda
    property var ventana: null       // la PanelWindow de la barra
    property string texto: ""
    property real centroX: 0

    function mostrar(item, txt) {
        // coordenadas del módulo dentro de la ventana de la barra
        const p = item.mapToItem(null, item.width / 2, 0);
        centroX = p.x;
        texto = txt;
        espera.restart();
    }
    function ocultar() {
        espera.stop();
        visible = false;
    }

    Timer { id: espera; interval: 450; onTriggered: ayuda.visible = true }

    anchor.window: ventana
    // centrado bajo el módulo, sin salirse por la derecha
    anchor.rect.x: Math.max(4, Math.min(centroX - implicitWidth / 2, (ventana?.width ?? 0) - implicitWidth - 4))
    anchor.rect.y: (ventana?.height ?? 34) + 6
    implicitWidth: etiqueta.implicitWidth + 24
    implicitHeight: etiqueta.implicitHeight + 16
    color: "transparent"
    visible: false

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.alpha(Paleta.fondo, 0.96)
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.6) }
        Text {
            id: etiqueta
            anchors.centerIn: parent
            text: ayuda.texto
            color: Paleta.texto
            lineHeight: 1.15
            font { family: Paleta.fuente; pixelSize: 12 }
        }
    }
}
