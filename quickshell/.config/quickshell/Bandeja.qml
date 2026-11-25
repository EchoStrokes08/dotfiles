import QtQuick
import QtQuick.Effects
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
    // win: la ventana donde está `origen` (la barra o el desplegable)
    function activar(item, boton, origen, win) {
        if (boton === Qt.MiddleButton) item.secondaryActivate();
        else if (boton === Qt.RightButton || item.onlyMenu) {
            if (!item.hasMenu) return;
            // menú con el estilo del sistema; si falla, el nativo de Qt
            if (!menuBandeja.abrir(item, origen, win ?? ventana)) { const p = origen.mapToItem(null,0,origen.height); item.display(ventana,p.x,p.y+8); }
        } else item.activate();
    }
    MenuBandeja { id: menuBandeja }
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
    // Botón del desplegable: círculo del alto de las cápsulas de la barra (24 px), dentro de la isla.
    // Antes era un BotonCompacto de 34 px de alto cuyo borde se salía del filo de la isla.
    Item {
        id: abrir
        implicitWidth: 30; implicitHeight: 34
        visible: bandeja.items.length > 0
        Accessible.role: Accessible.Button
        Accessible.name: "Bandeja · " + bandeja.items.length + " aplicaciones"
        Rectangle {
            anchors.centerIn: parent
            width: 24; height: 24; radius: height / 2
            color: bandeja.expandida ? EstiloPanel.rellenoActivo : zonaAbrir.containsMouse ? EstiloPanel.relleno : "transparent"
            border { width: 1; color: bandeja.expandida || zonaAbrir.containsMouse ? EstiloPanel.borde : "transparent" }
            scale: zonaAbrir.pressed ? .9 : 1
            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "⌄"
                rotation: bandeja.expandida ? 180 : 0
                color: bandeja.expandida || zonaAbrir.containsMouse ? Paleta.texto : EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 13; bold: true }
                Behavior on rotation { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.normal : 0; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            id: zonaAbrir
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bandeja.expandida = !bandeja.expandida
        }
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
        // entrada: la tarjeta crece desde la esquina del botón con un pequeño rebote
        Item {
            id: cuerpo
            anchors.fill: parent
            transformOrigin: Item.TopRight
            opacity: 0; scale: .94
            states: State { when: desplegable.visible; PropertyChanges { cuerpo.opacity: 1; cuerpo.scale: 1 } }
            transitions: Transition {
                to: "*"
                NumberAnimation { property: "opacity"; duration: EstiloPanel.normal }
                NumberAnimation { property: "scale"; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
            }
            FondoPanel { anchors.fill: parent; opacidad: 1 }   // las emergentes no reciben el blur de Hyprland
            ColumnLayout {
                id: contenido
                anchors { fill: parent; margins: 12 }
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.bottomMargin: 4
                    spacing: 8
                    Etiqueta { text: "EN SEGUNDO PLANO" }
                    Rectangle {   // contador en chip
                        implicitWidth: Math.max(implicitHeight, cuenta.implicitWidth + 12); implicitHeight: 18
                        radius: height / 2
                        color: Qt.alpha(Paleta.acento, .14)
                        border { width: 1; color: Qt.alpha(Paleta.acento, .4) }
                        Text { id: cuenta; anchors.centerIn: parent; text: bandeja.items.length; color: Paleta.acento
                               font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                    }
                    Item { Layout.fillWidth: true }
                    BotonCompacto { text: "×"; implicitWidth: 30; implicitHeight: 28; Accessible.name: "Cerrar"; onClicked: bandeja.expandida = false }
                }
                Repeater {
                    model: bandeja.items
                    Item {
                        id: fila
                        required property var modelData
                        required property int index
                        readonly property bool fijada: PreferenciasUI.favoritosBandeja.includes(modelData.id)
                        readonly property bool atencion: modelData.status === Status.NeedsAttention
                        Layout.fillWidth: true
                        implicitHeight: 44
                        opacity: 0
                        transform: Translate { id: desliz; y: 8 }
                        Connections {
                            target: desplegable
                            function onVisibleChanged() { if (desplegable.visible) entradaFila.restart(); }
                        }
                        Component.onCompleted: if (desplegable.visible) entradaFila.restart()
                        SequentialAnimation {
                            id: entradaFila
                            PropertyAction { target: fila; property: "opacity"; value: EstiloPanel.movimiento ? 0 : 1 }
                            PropertyAction { target: desliz; property: "y"; value: EstiloPanel.movimiento ? 8 : 0 }
                            PauseAnimation { duration: EstiloPanel.movimiento ? 60 + fila.index * 35 : 0 }
                            ParallelAnimation {
                                NumberAnimation { target: fila; property: "opacity"; to: 1; duration: EstiloPanel.normal }
                                NumberAnimation { target: desliz; property: "y"; to: 0; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
                            }
                        }
                        FondoSeleccion {
                            anchors.fill: parent
                            encima: true; marca: true
                            tinte: fila.atencion ? Paleta.aviso : Paleta.acento
                            opacity: zona.containsMouse ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
                        }
                        MouseArea {
                            id: zona
                            anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (e) => bandeja.activar(fila.modelData, e.button, fila, desplegable)
                        }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                            spacing: 12
                            Rectangle {   // baldosa del icono; brilla con sus colores al pasar
                                implicitWidth: 30; implicitHeight: 30; radius: EstiloPanel.rChip
                                color: zona.containsMouse ? EstiloPanel.elevada : EstiloPanel.relleno
                                border { width: 1; color: zona.containsMouse ? EstiloPanel.bordeFuerte : EstiloPanel.borde }
                                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                MultiEffect {
                                    z: -1
                                    visible: EstiloPanel.profundidad && zona.containsMouse && icono.status === Image.Ready
                                    anchors.centerIn: parent
                                    width: 44; height: 44
                                    source: icono
                                    blurEnabled: true; blur: 1; blurMax: 32
                                    saturation: .5; brightness: .25
                                }
                                IconImage {
                                    id: icono
                                    anchors.centerIn: parent
                                    implicitSize: 20
                                    source: fila.modelData.icon
                                    scale: zona.containsMouse ? 1.1 : 1
                                    Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: fila.modelData.title || fila.modelData.id
                                    elide: Text.ElideRight
                                    color: zona.containsMouse ? Paleta.texto : EstiloPanel.secundario
                                    font { family: Paleta.fuente; pixelSize: 13; bold: zona.containsMouse }
                                }
                                Text {
                                    visible: fila.atencion
                                    text: "Necesita atención"
                                    color: Paleta.aviso
                                    font { family: Paleta.fuente; pixelSize: 11 }
                                }
                            }
                            Item {   // estrella: fijar en la barra
                                implicitWidth: 32; implicitHeight: 32
                                Accessible.role: Accessible.Button
                                Accessible.name: (fila.fijada ? "Quitar de la barra " : "Fijar en la barra ") + (fila.modelData.title || fila.modelData.id)
                                Text {
                                    id: estrella
                                    anchors.centerIn: parent
                                    text: fila.fijada ? "★" : "☆"
                                    color: fila.fijada ? Paleta.aviso : zonaEstrella.containsMouse ? Paleta.texto : EstiloPanel.apagado
                                    font { family: Paleta.fuente; pixelSize: 16 }
                                    scale: zonaEstrella.pressed ? .8 : zonaEstrella.containsMouse ? 1.15 : 1
                                    Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                }
                                MultiEffect {   // brillo dorado de la estrella fijada
                                    z: -1
                                    visible: EstiloPanel.profundidad && fila.fijada
                                    anchors.fill: estrella
                                    source: estrella
                                    blurEnabled: true; blur: .8; blurMax: 16
                                    brightness: .2
                                }
                                MouseArea {
                                    id: zonaEstrella
                                    anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: PreferenciasUI.alternarFavorito("bandeja", fila.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
