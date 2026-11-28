// CieloSolar: la luz del escritorio sigue al sol de verdad (Sol.qml).
//   mañana y tarde   un resplandor dorado entra por el lado del sol (este = izquierda, oeste = derecha)
//   ocaso y alba     el horizonte (abajo) se vuelve rosado
//   hora azul        un velo azul frío
//   noche            el cielo se oscurece de arriba abajo
// De día no hace nada. Cambia tan despacio (30 s de transición por minuto) que no se ve cambiar.
// Encima del wallpaper (y de FondoVivo/Panorama), debajo de todo lo demás; se ve en el escritorio
// vacío, en los huecos y a través del blur de las ventanas. Solo en perfil Cristal; los clics atraviesan.
//   PreferenciasUI.cieloSolar · qs ipc call cielo simular 18:00 · qs ipc call cielo timelapse
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: v
    readonly property bool activo: EstiloPanel.efectos && PreferenciasUI.cieloSolar
    readonly property int suavizado: Sol.rapido ? 0 : 30000
    // Siempre mapeada (ver Barra.qml): se apaga solo el contenido
    contentItem.visible: lienzo.opacity > 0 && (Sol.oro + Sol.ocaso + Sol.azul + Sol.noche) > .01
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-cielo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // Las fuerzas, suavizadas (de minuto en minuto, sin saltos)
    property real oro: Sol.oro
    property real ocaso: Sol.ocaso
    property real azul: Sol.azul
    property real noche: Sol.noche
    property real lado: Sol.lado
    Behavior on oro   { NumberAnimation { duration: v.suavizado; easing.type: Easing.InOutSine } }
    Behavior on ocaso { NumberAnimation { duration: v.suavizado; easing.type: Easing.InOutSine } }
    Behavior on azul  { NumberAnimation { duration: v.suavizado; easing.type: Easing.InOutSine } }
    Behavior on noche { NumberAnimation { duration: v.suavizado; easing.type: Easing.InOutSine } }
    Behavior on lado  { NumberAnimation { duration: v.suavizado; easing.type: Easing.InOutSine } }

    Item {
        id: lienzo
        anchors.fill: parent
        opacity: v.activo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutSine } }

        // noche: más oscuro arriba (el cielo), algo menos abajo
        Rectangle {
            anchors.fill: parent
            opacity: v.noche
            gradient: Gradient {
                GradientStop { position: 0;  color: Qt.alpha(Paleta.cieloNoche, .55) }
                GradientStop { position: .6; color: Qt.alpha(Paleta.cieloNoche, .30) }
                GradientStop { position: 1;  color: Qt.alpha(Paleta.cieloNoche, .40) }
            }
        }
        // hora azul: velo frío, más denso arriba
        Rectangle {
            anchors.fill: parent
            opacity: v.azul
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Paleta.cieloAzul, .22) }
                GradientStop { position: 1; color: Qt.alpha(Paleta.cieloAzul, .08) }
            }
        }
        // ocaso / alba: el horizonte se enciende de rosa, más hacia el lado del sol
        Rectangle {
            anchors.fill: parent
            opacity: v.ocaso
            gradient: Gradient {
                GradientStop { position: .35; color: "transparent" }
                GradientStop { position: .8;  color: Qt.alpha(Paleta.solOcaso, .14) }
                GradientStop { position: 1;   color: Qt.alpha(Paleta.solOcaso, .26) }
            }
        }
        Bruma {
            width: v.width * 1.3; height: v.height * .9
            x: v.width * (.5 + .55 * v.lado) - width / 2
            y: v.height - height * .55
            tono: Paleta.solOcaso
            fuerza: .22 * v.ocaso
        }
        // hora dorada: un baño cálido general y el resplandor del sol bajo, entrando por su lado
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Paleta.solDorado, .07 * v.oro)
        }
        Bruma {
            width: v.width * 1.4; height: v.height * 1.6
            x: v.width * (.5 + .62 * v.lado) - width / 2
            y: v.height * .62 - height / 2
            tono: Paleta.solDorado
            fuerza: .30 * v.oro
        }
    }
}
