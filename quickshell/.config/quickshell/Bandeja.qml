import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

RowLayout {
    id: bandeja
    property var ventana: null
    property bool ocultarBuds: false
    property bool expandida: false
    spacing: 4
    readonly property var items: SystemTray.items.values.filter(i => !ocultarBuds || i.status === Status.NeedsAttention || !/buds/i.test(i.id + " " + i.title))
    readonly property var visibles: items.filter(i => PreferenciasUI.favoritosBandeja.includes(i.id) || i.status === Status.NeedsAttention)
    function activar(item, boton, origen) {
        if (boton === Qt.MiddleButton) item.secondaryActivate();
        else if (boton === Qt.RightButton || item.onlyMenu) {
            if (item.hasMenu) { const p = origen.mapToItem(null,0,origen.height); item.display(ventana,p.x,p.y+8); }
        } else item.activate();
    }
    Repeater {
        model: bandeja.visibles
        Item {
            required property var modelData
            implicitWidth: 28; implicitHeight: 34
            IconImage { anchors.centerIn: parent; implicitSize: 16; source: modelData.icon }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (e) => bandeja.activar(modelData,e.button,parent)
            }
        }
    }
    BotonCompacto {
        id: abrir
        text: bandeja.expandida ? "⌃" : "⌄"
        implicitWidth: 28
        visible: bandeja.items.length > 0
        Accessible.name: "Bandeja · " + bandeja.items.length + " aplicaciones"
        onClicked: bandeja.expandida = !bandeja.expandida
    }
    PopupWindow {
        id: desplegable
        visible: bandeja.expandida
        anchor.window: bandeja.ventana
        anchor.rect.x: Math.max(4,Math.min(abrir.mapToItem(null,0,0).x-implicitWidth+28,(bandeja.ventana?.width ?? 1280)-implicitWidth-8))
        anchor.rect.y: (bandeja.ventana?.height ?? 42)+4
        implicitWidth: 320
        implicitHeight: contenido.implicitHeight+24
        color: "transparent"
        FondoPanel { anchors.fill: parent }
        ColumnLayout {
            id: contenido
            anchors { fill: parent; margins: 12 }
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Aplicaciones en segundo plano"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                BotonCompacto { text: "×"; onClicked: bandeja.expandida = false }
            }
            Repeater {
                model: bandeja.items
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    IconImage { implicitSize: 20; source: modelData.icon }
                    BotonCompacto {
                        Layout.fillWidth: true
                        text: modelData.title || modelData.id
                        onClicked: bandeja.activar(modelData,Qt.LeftButton,this)
                        MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: bandeja.activar(modelData,Qt.RightButton,parent) }
                    }
                    BotonCompacto { text: PreferenciasUI.favoritosBandeja.includes(modelData.id) ? "★" : "☆"; Accessible.name: "Fijar " + (modelData.title || modelData.id); onClicked: PreferenciasUI.alternarFavorito("bandeja",modelData.id) }
                }
            }
        }
    }
}
