// IconoApp: icono de una app de sesión ({clase, nombre}); si no hay icono, su inicial.
import QtQuick
import Quickshell

Item {
    id: ia
    property var app: null
    property real lado: 20
    readonly property var entrada: DesktopEntries.heuristicLookup(app?.clase || app?.nombre || "")
    implicitWidth: lado; implicitHeight: lado
    width: lado; height: lado
    Image {
        id: img
        anchors.fill: parent
        source: ia.entrada ? Quickshell.iconPath(ia.entrada.icon, true) : ""
        sourceSize { width: ia.lado * 2; height: ia.lado * 2 }
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        radius: ia.lado * .3
        color: Qt.alpha(Paleta.azul, .2)
        Text {
            anchors.centerIn: parent
            text: (ia.entrada?.name || ia.app?.nombre || "?").charAt(0).toUpperCase()
            color: Paleta.azul
            font { family: EstiloPanel.fuente; pixelSize: ia.lado * .55; bold: true }
        }
    }
}
