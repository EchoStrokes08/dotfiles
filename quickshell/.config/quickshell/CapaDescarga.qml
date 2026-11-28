// CapaDescarga: cuando termina una descarga (el navegador renombra el .crdownload / .part al nombre final
// en ~/Downloads), cae desde la isla una tarjeta con la miniatura si es una imagen o un icono según el
// tipo, el nombre y el tamaño, y los botones Abrir y Ver en carpeta. Se va sola a los 6 s (se queda con el
// ratón encima). Lo ve inotifywait (el aviso llega al instante, también con descargas de un segundo).
// La burbuja de «descargando» sigue en la isla (Actividades.qml); esta es la de «ya está».
// Con privacidad no enseña ni el nombre ni la miniatura.
//   qs ipc call descarga muestra
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: c
    readonly property string carpeta: Quickshell.env("HOME") + "/Downloads"

    Process {
        running: true
        command: ["inotifywait", "-mq", "-e", "moved_to", "--format", "%f", c.carpeta]
        stdout: SplitParser {
            onRead: (nombre) => {
                if (!nombre || nombre.startsWith(".") || /\.(crdownload|part|tmp|download)$/i.test(nombre)) return;
                if (nombre === c.ultimo && Date.now() - c.cuando < 3000) return;    // el mismo, dos veces
                c.ultimo = nombre; c.cuando = Date.now();
                tamano.ruta = c.carpeta + "/" + nombre;
                tamano.command = ["stat", "-c", "%s", tamano.ruta];
                tamano.running = true;
            }
        }
    }
    property string ultimo: ""
    property real cuando: 0
    Process {
        id: tamano
        property string ruta: ""
        stdout: StdioCollector {
            onStreamFinished: {
                c.datos = { ruta: tamano.ruta, nombre: tamano.ruta.split("/").pop(), bytes: Number(text.trim()) || 0 };
                c.mostrar();
            }
        }
    }
    IpcHandler {
        target: "descarga"
        function muestra(): void {
            c.datos = { ruta: "", nombre: "Guía de estudio — Français III.pdf", bytes: 2.4e6 };
            c.mostrar();
        }
    }

    // ── tipo ──────────────────────────────────────────────────────────────────────────────────────
    readonly property string ext: (datos.nombre.match(/\.([^.]+)$/)?.[1] ?? "").toLowerCase()
    readonly property bool imagen: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].includes(ext)
    readonly property int glifo: ext === "pdf" ? 0xF0226
        : ["zip", "rar", "7z", "tar", "gz", "xz", "zst", "bz2"].includes(ext) ? 0xF05C4
        : ["xls", "xlsx", "ods", "csv"].includes(ext) ? 0xF021B
        : ["doc", "docx", "odt", "txt", "md", "ppt", "pptx", "odp", "rtf"].includes(ext) ? 0xF0219
        : ["mp4", "mkv", "webm", "mov", "avi"].includes(ext) ? 0xF0381
        : ["mp3", "flac", "ogg", "wav", "m4a", "opus"].includes(ext) ? 0xF0388
        : 0xF0214
    readonly property color tono: ext === "pdf" ? Paleta.peligro : glifo === 0xF021B ? Paleta.exito : glifo === 0xF05C4 ? Paleta.aviso : Paleta.acento
    function tam(b) {
        return b >= 1e9 ? (b / 1e9).toFixed(1).replace(".", ",") + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1).replace(".", ",") + " MB"
             : b >= 1e3 ? Math.round(b / 1e3) + " KB" : b + " B";
    }

    // ── mostrar ───────────────────────────────────────────────────────────────────────────────────
    property var datos: ({ ruta: "", nombre: "", bytes: 0 })
    readonly property bool privado: EstadoEscritorio.privacidad
    property bool abierta: false
    property real p: 0
    function mostrar() {
        screen = Quickshell.screens.find(s => s.name === Isla.enfocado) ?? Quickshell.screens[0];
        abierta = true;
        visible = true;
        fin.restart();
    }
    Timer { id: fin; interval: 6000; onTriggered: if (zona.containsMouse) restart(); else c.abierta = false }
    Behavior on p { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.lento : 0; easing.type: c.abierta ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.2 } }
    Binding { target: c; property: "p"; value: c.abierta ? 1 : 0 }
    onPChanged: if (p === 0 && !abierta) visible = false

    visible: false
    color: "transparent"
    anchors.top: true
    implicitWidth: 440
    implicitHeight: 180
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-descarga"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: tarjeta }

    Rectangle {
        id: tarjeta
        width: parent.width - 16; height: 120
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46 + (1 - c.p) * -40
        opacity: Math.min(1, c.p * 1.6)
        scale: .7 + .3 * c.p
        transformOrigin: Item.Top
        radius: EstiloPanel.rPanel
        color: EstiloPanel.superficie
        border { width: 1; color: EstiloPanel.borde }

        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true }

        // miniatura o icono del tipo
        Rectangle {
            id: vista
            width: 72; height: 72
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            radius: EstiloPanel.rTarjeta
            color: Qt.alpha(c.tono, .14)
            border { width: 1; color: Qt.alpha(c.tono, .3) }
            clip: true
            Image {
                id: mini
                anchors.fill: parent
                visible: c.imagen && !c.privado && status === Image.Ready
                source: c.imagen && !c.privado && c.datos.ruta ? "file://" + c.datos.ruta : ""
                sourceSize: Qt.size(144, 144)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !mini.visible
                text: String.fromCodePoint(c.imagen ? 0xF021F : c.glifo)
                color: c.tono
                font { family: Paleta.mono; pixelSize: 36 }
            }
            // la flecha de «descargado» que baja una vez
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
                width: 20; height: 20; radius: height / 2
                color: Paleta.exito
                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF012C)
                    color: Paleta.fondo
                    font { family: Paleta.mono; pixelSize: 12 }
                }
                scale: c.p
            }
        }

        Column {
            anchors { left: vista.right; leftMargin: 16; right: parent.right; rightMargin: 24; top: parent.top; topMargin: 16 }
            spacing: 4
            Text {
                text: "Descarga completa"
                color: Paleta.exito
                font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1 }
            }
            Text {
                width: parent.width; elide: Text.ElideMiddle
                text: c.privado ? "Archivo descargado" : c.datos.nombre
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 14; bold: true }
            }
            Text {
                text: c.tam(c.datos.bytes) + (c.ext ? " · " + c.ext.toUpperCase() : "")
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 16 }
            spacing: 8
            Boton {
                glifo: 0xF0770; texto: "Carpeta"
                onPulsado: { Quickshell.execDetached(["thunar", c.datos.ruta || c.carpeta]); c.abierta = false; }
            }
            Boton {
                glifo: 0xF03CC; texto: "Abrir"; principal: true
                onPulsado: { if (c.datos.ruta) Quickshell.execDetached(["xdg-open", c.datos.ruta]); c.abierta = false; }
            }
        }
    }

    component Boton: Rectangle {
        id: b
        property int glifo: 0
        property string texto: ""
        property bool principal: false
        signal pulsado()
        width: filaB.implicitWidth + 24; height: 32
        radius: height / 2
        color: principal ? Qt.alpha(Paleta.acento, zonaB.containsMouse ? .3 : .2)
                         : zonaB.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
        border { width: 1; color: principal ? Qt.alpha(Paleta.acento, .45) : EstiloPanel.borde }
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Row {
            id: filaB
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(b.glifo)
                color: b.principal ? Paleta.acento : Paleta.texto
                font { family: Paleta.mono; pixelSize: 13 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.texto
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
            }
        }
        MouseArea { id: zonaB; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.pulsado() }
    }
}
