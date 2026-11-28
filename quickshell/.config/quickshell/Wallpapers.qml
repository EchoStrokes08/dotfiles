// Galería de fondos (SUPER+SHIFT+W). Las flechas y el clic eligen, Enter o doble clic aplica.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Superpuesta {
    id: sel
    espacio: "wallpapers"
    panelCuidado: true
    margenPanel: height < 640 ? EstiloPanel.e4 : EstiloPanel.e5
    anchoTarjeta: Math.min(1060, Math.max(1, width - 32))
    alturaRelativa: 0.10

    readonly property string carpeta: Quickshell.env("HOME") + "/Imágenes/wallpapers"
    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    readonly property bool horizontal: galeria.width >= 760
    readonly property string ruta: rejilla.currentIndex >= 0 && rejilla.currentIndex < archivos.count
        ? String(archivos.get(rejilla.currentIndex, "filePath")) : ""
    readonly property string nombre: ruta.split("/").pop()
    property string actual: ""

    function titulo(archivo) {
        const base = archivo.replace(/\.[^.]+$/, "");
        const numerado = /^thumb-1920-(\d+)$/.exec(base);
        if (numerado) return "Fondo " + numerado[1];
        const limpio = base.replace(/_\d+x\d+.*$/i, "").replace(/[-_]+/g, " ").trim();
        return limpio.charAt(0).toUpperCase() + limpio.slice(1);
    }

    function seleccionarActual() {
        for (let i = 0; i < archivos.count; i++) {
            if (archivos.get(i, "fileName") === actual) {
                rejilla.currentIndex = i;
                rejilla.positionViewAtIndex(i, GridView.Contain);
                return;
            }
        }
        rejilla.currentIndex = archivos.count > 0 ? 0 : -1;
    }

    function poner() {
        if (!ruta) return;
        Quickshell.execDetached([scripts + "wallpaper.sh", "poner", ruta]);
        abierto = false;
    }

    onAbriendose: {
        ajustes.visible = false;
        seleccionarActual();
        leerActual.running = true;
        rejilla.forceActiveFocus();
    }

    Shortcut {
        sequence: "Escape"
        enabled: sel.abierto
        onActivated: sel.abierto = false
    }

    Process {
        id: leerActual
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/tema/wallpaper"]
        stdout: StdioCollector {
            onStreamFinished: {
                sel.actual = text.trim().split("/").pop();
                if (sel.abierto) sel.seleccionarActual();
            }
        }
    }

    FolderListModel {
        id: archivos
        folder: "file://" + sel.carpeta
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: if (status === FolderListModel.Ready && sel.abierto) sel.seleccionarActual()
    }

    ColumnLayout {
        id: galeria
        width: parent.width
        spacing: sel.height < 640 ? EstiloPanel.e3 : EstiloPanel.e4

        EncabezadoPanel {
            titulo: "Fondos de pantalla"
            seccion: (archivos.count === 1 ? "1 imagen" : archivos.count + " imágenes")
                + "  ·  " + (Paleta.fijado ? "Acento fijado" : Paleta.modo === "wallpaper" ? "Colores del fondo" : "Paleta Ayu")
            simbolo: String.fromCodePoint(0xF0E09)
            onCerrar: sel.abierto = false
        }

        GridLayout {
            Layout.fillWidth: true
            columns: sel.horizontal ? 2 : 1
            columnSpacing: 16
            rowSpacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: sel.horizontal ? 54 : 1
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 8

                MarcoFondo {
                    id: portada
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(width * 9 / 16, sel.height * (sel.horizontal ? .43 : .25))
                    radio: EstiloPanel.rTarjeta

                    Rectangle { anchors.fill: parent; radius: EstiloPanel.rTarjeta; color: EstiloPanel.elevada }

                    Image {
                        anchors.fill: parent
                        source: sel.ruta ? archivos.get(rejilla.currentIndex, "fileUrl") : ""
                        sourceSize.width: 1200
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
                    }
                    Rectangle {
                        anchors { fill: parent; margins: 1 }
                        radius: EstiloPanel.rTarjeta
                        color: "transparent"
                        border { width: 1; color: Qt.alpha("white", .18) }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !sel.ruta
                        text: archivos.status === FolderListModel.Loading ? "Cargando imágenes…" : "La colección está vacía"
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 14 }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: sel.ruta ? sel.titulo(sel.nombre) : "Vista previa"
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 20; weight: Font.DemiBold }
                    }
                    Text {
                        visible: !!sel.ruta && sel.nombre === sel.actual
                        text: "✓ En uso"
                        color: Paleta.acento
                        font { family: Paleta.fuente; pixelSize: 12; bold: true }
                    }
                }
            }

            GridView {
                id: rejilla
                Layout.fillWidth: true
                Layout.preferredWidth: sel.horizontal ? 46 : 1
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: sel.horizontal ? portada.height
                    : Math.min(sel.height * .30, Math.min(2, Math.ceil(count / columnas)) * cellHeight)
                readonly property int columnas: width >= 380 ? 3 : 2
                readonly property int anchoUtil: Math.max(1, width - 12)
                cellWidth: Math.max(1, Math.floor(anchoUtil / columnas))
                cellHeight: sel.horizontal ? Math.max(40, Math.floor(portada.height / 3))
                    : Math.max(40, Math.min(Math.round(cellWidth * .67), Math.floor(sel.height * .15)))
                clip: true
                focus: true
                activeFocusOnTab: true
                keyNavigationEnabled: true
                keyNavigationWraps: true
                boundsBehavior: Flickable.StopAtBounds
                model: archivos
                ScrollBar.vertical: ScrollBar {
                    policy: rejilla.contentHeight > rejilla.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }

                Keys.onReturnPressed: event => { if (!event.isAutoRepeat) sel.poner(); }
                Keys.onEnterPressed: event => { if (!event.isAutoRepeat) sel.poner(); }

                delegate: Item {
                    id: celda
                    required property url fileUrl
                    required property string fileName
                    required property int index
                    readonly property bool esActual: fileName === sel.actual
                    readonly property bool marcada: GridView.isCurrentItem
                    width: rejilla.cellWidth
                    height: rejilla.cellHeight
                    Accessible.role: Accessible.Button
                    Accessible.name: sel.titulo(fileName) + (esActual ? ", en uso" : "")
                    Accessible.onPressAction: { rejilla.currentIndex = index; rejilla.forceActiveFocus(); }

                    MarcoFondo {
                        anchors { fill: parent; margins: 4 }
                        Rectangle { anchors.fill: parent; radius: EstiloPanel.rControl; color: EstiloPanel.elevada }
                        Image {
                            anchors.fill: parent
                            source: celda.fileUrl
                            sourceSize.width: 420
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            scale: cursor.containsMouse ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: EstiloPanel.rControl
                            color: Qt.alpha("black", celda.marcada || cursor.containsMouse ? 0 : .16)
                            border.width: celda.marcada ? 2 : 1
                            border.color: celda.marcada ? Paleta.acento : Qt.alpha("white", cursor.containsMouse ? .55 : .18)
                        }
                        Rectangle {
                            anchors { right: parent.right; top: parent.top; margins: 8 }
                            visible: celda.esActual
                            width: 22; height: width; radius: height / 2
                            color: Paleta.acento
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Paleta.sobreAcento
                                font { family: Paleta.fuente; pixelSize: 12; bold: true }
                            }
                        }
                    }

                    MouseArea {
                        id: cursor
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { rejilla.currentIndex = celda.index; rejilla.forceActiveFocus(); }
                        onDoubleClicked: { rejilla.currentIndex = celda.index; sel.poner(); }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: EstiloPanel.bordeFuerte }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            BotonCompacto {
                text: "Aplicar fondo"
                destacado: true
                enabled: !!sel.ruta
                onClicked: sel.poner()
            }
            BotonCompacto {
                text: "Aleatorio"
                enabled: archivos.count > 0
                onClicked: {
                    Quickshell.execDetached([sel.scripts + "wallpaper.sh", "aleatorio"]);
                    sel.abierto = false;
                }
            }
            BotonCompacto {
                text: "Colores y apariencia"
                destacado: ajustes.visible
                onClicked: ajustes.visible = !ajustes.visible
            }
        }

        AjustesApariencia { id: ajustes; visible: false; Layout.fillWidth: true }

        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            visible: sel.height >= 600 && implicitWidth <= galeria.width
            atajos: [["← ↑ ↓ →", "elegir"], ["↵", "aplicar"], ["Esc", "cerrar"]]
        }
    }
}
