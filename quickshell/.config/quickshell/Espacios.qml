// Espacios de trabajo: una "píldora" por workspace con los iconos de sus ventanas.
// Solo se muestran los que tienen ventanas (y el actual). Clic = ir a ese workspace.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Flow {
    id: espacios
    signal elegido()          // el Dashboard se cierra al elegir uno
    spacing: 8

    // Icono de una app a partir de su class (busca su archivo .desktop)
    function icono(clase) {
        const entrada = DesktopEntries.heuristicLookup(clase);
        return entrada ? Quickshell.iconPath(entrada.icon, true) : "";
    }

    Repeater {
        // ids normales (>0); los especiales (scratchpad) tienen id negativo
        model: Hyprland.workspaces.values
            .filter(w => w.id > 0 && (w.toplevels.values.length > 0 || w.focused))
            .sort((a, b) => a.id - b.id)

        Rectangle {
            id: pildora
            required property var modelData
            readonly property var ventanas: modelData.toplevels.values
            readonly property int maxIconos: 4

            implicitWidth: fila.implicitWidth + 20
            implicitHeight: 38
            radius: 12
            color: modelData.focused ? Qt.alpha(Paleta.naranja, 0.14)
                 : zona.containsMouse ? Qt.alpha(Paleta.texto, 0.07) : Qt.alpha(Paleta.texto, 0.035)
            border { width: 1; color: modelData.focused ? Qt.alpha(Paleta.naranja, 0.6) : "transparent" }
            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: fila
                anchors.centerIn: parent
                spacing: 7

                Text {
                    text: pildora.modelData.id
                    color: pildora.modelData.focused ? Paleta.naranja : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 13; bold: true }
                }

                Repeater {
                    model: pildora.ventanas.slice(0, pildora.maxIconos)
                    Item {
                        required property var modelData
                        readonly property string clase: modelData.lastIpcObject?.class ?? ""
                        readonly property string ruta: espacios.icono(clase)
                        implicitWidth: 20; implicitHeight: 20

                        IconImage {
                            anchors.fill: parent
                            visible: parent.ruta !== ""
                            source: parent.ruta
                            asynchronous: true
                        }
                        // Sin icono: círculo con la inicial
                        Rectangle {
                            anchors.fill: parent
                            visible: parent.ruta === ""
                            radius: 10
                            color: Paleta.seleccion
                            Text {
                                anchors.centerIn: parent
                                text: (parent.parent.clase.split(".").pop()[0] ?? "?").toUpperCase()
                                color: Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 10; bold: true }
                            }
                        }
                    }
                }

                Text {
                    visible: pildora.ventanas.length > pildora.maxIconos
                    text: "+" + (pildora.ventanas.length - pildora.maxIconos)
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
            }

            MouseArea {
                id: zona
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { pildora.modelData.activate(); espacios.elegido(); }
            }
        }
    }
}
