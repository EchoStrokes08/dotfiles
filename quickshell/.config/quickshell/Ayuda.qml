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
    implicitWidth: etiqueta.implicitWidth + 28
    implicitHeight: etiqueta.implicitHeight + 18
    color: "transparent"
    visible: false

    Rectangle {
        anchors.fill: parent
        radius: 11
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.naranja, .08)) }
            GradientStop { position: 1; color: Paleta.fondo }
        }
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }
        Rectangle {   // filo de luz
            x: 10; y: 1; width: parent.width - 20; height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: .5; color: Qt.alpha(Paleta.texto, .18) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
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
