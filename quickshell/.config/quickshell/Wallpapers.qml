// Selector de wallpapers (SUPER+SHIFT+W): rejilla de miniaturas grandes.
//   flechas/clic para elegir · Enter aplica · el actual lleva borde naranja
// Aplica con ~/.config/hypr/scripts/wallpaper.sh poner <ruta> (hyprpaper + colores si el modo es "wallpaper").
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Superpuesta {
    id: sel
    espacio: "wallpapers"
    anchoTarjeta: 4 * 214 + 2 * margenPanel + 4   // cuatro columnas exactas: antes cabían tres y sobraba un hueco
    alturaRelativa: 0.10

    readonly property string carpeta: Quickshell.env("HOME") + "/Imágenes/wallpapers"
    property string actual: ""          // ruta real del wallpaper puesto
    property string modo: Paleta.modo         // ayu | wallpaper (tema.sh estado)

    function guion(args) { Quickshell.execDetached(["sh", "-c", "~/.config/hypr/scripts/" + args]); }
    function poner(ruta) { guion(`wallpaper.sh poner "${ruta}"`); abierto = false; }

    onAbriendose: { leerActual.running = true; leerModo.running = true; rejilla.forceActiveFocus(); }

    Process {
        id: leerActual
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/tema/wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                sel.actual = this.text.trim();
                // empezar con el actual seleccionado
                const nombre = sel.actual.split("/").pop();
                for (let i = 0; i < archivos.count; i++)
                    if (archivos.get(i, "fileName") === nombre) { rejilla.currentIndex = i; break; }
            }
        }
    }
    Process {
        id: leerModo
        command: ["sh", "-c", "~/.config/hypr/scripts/tema.sh estado"]
        stdout: StdioCollector { onStreamFinished: sel.modo = this.text.trim() }
    }
    // (~/Imágenes/wallpapers es un enlace al repo: por eso se compara solo el nombre del archivo)

    FolderListModel {
        id: archivos
        folder: "file://" + sel.carpeta
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    ColumnLayout {
        width: parent.width
        spacing: 12

        // Cabecera: título · colores · aleatorio
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: String.fromCodePoint(0xF0E09) + "  Wallpapers  <font color='" + Paleta.gris + "'>(" + archivos.count + ")</font>"
                textFormat: Text.StyledText
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 16; bold: true }
            }
            Text { text: "Color actual: " + (Paleta.fijado ? "fijado" : Paleta.modo === "wallpaper" ? "del fondo" : "Ayu"); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
            BotonCompacto { text: "Cambiar colores"; onClicked: ajustesColores.visible = !ajustesColores.visible }
            BotonCompacto { text: "Aleatorio"; onClicked: { sel.guion("wallpaper.sh aleatorio"); sel.abierto = false; } }

        }

        AjustesApariencia { id: ajustesColores; visible: false; Layout.fillWidth: true }

        GridView {
            id: rejilla
            Layout.fillWidth: true
            implicitHeight: Math.min(3, Math.ceil(count / 4)) * cellHeight
            cellWidth: 214
            cellHeight: 134
            clip: true
            focus: true
            model: archivos
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: true
            highlightFollowsCurrentItem: true
            Keys.onReturnPressed: sel.poner(archivos.get(currentIndex, "filePath"))
            Keys.onEnterPressed: sel.poner(archivos.get(currentIndex, "filePath"))

            delegate: Item {
                id: celda
                required property string filePath
                required property string fileName
                required property int index
                readonly property bool esActual: sel.actual !== "" && sel.actual.split("/").pop() === fileName
                readonly property bool marcada: GridView.isCurrentItem
                width: rejilla.cellWidth
                height: rejilla.cellHeight

                // resplandor bajo la miniatura: del acento en el fondo puesto, neutro en la marcada
                RectangularShadow {
                    anchors { fill: parent; margins: 4 }
                    visible: EstiloPanel.profundidad && (celda.marcada || celda.esActual)
                    radius: 12; offset.y: 6; blur: 26; spread: -4
                    color: celda.esActual ? Qt.alpha(Paleta.acento, .55) : Qt.alpha("black", .55)
                    scale: marco.scale
                }
                ClippingRectangle {
                    id: marco
                    anchors { fill: parent; margins: 4 }
                    radius: 12
                    color: Paleta.seleccion
                    border { width: celda.esActual ? 3 : celda.marcada ? 2 : 0
                             color: celda.esActual ? Paleta.acento : Paleta.texto }
                    scale: celda.marcada ? 1.0 : 0.95
                    Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source: "file://" + celda.filePath
                        sourceSize { width: 404; height: 244 }   // se decodifica pequeña: rápido y ligero
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        scale: celda.marcada ? 1.07 : 1      // se acerca dentro de su marco
                        Behavior on scale { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
                    }
                    // nombre al pasar el ratón o al estar seleccionada
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 34
                        visible: celda.marcada || zonaCelda.containsMouse
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.alpha(Paleta.fondo, .85) }
                        }
                        Text {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 8 }
                            verticalAlignment: Text.AlignVCenter
                            text: (celda.esActual ? "  " : "") + celda.fileName
                            color: celda.esActual ? Paleta.acento : Paleta.texto
                            elide: Text.ElideMiddle
                            font { family: Paleta.fuente; pixelSize: 11 }
                        }
                    }
                }
                MouseArea {
                    id: zonaCelda
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: rejilla.currentIndex = celda.index
                    onClicked: sel.poner(celda.filePath)
                }
            }
        }

        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            atajos: [["↵", "poner"], ["← →", "moverse"], ["Esc", "cerrar"]]
        }
    }
}
