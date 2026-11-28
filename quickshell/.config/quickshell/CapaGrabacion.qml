// CapaGrabacion: la grabación de pantalla con estudio (grabar.sh).
//   · grabando una región: un marco rojo justo por fuera de lo que se graba (no sale en el vídeo) con
//     una etiqueta «● REC 0:12»; así se ve qué entra en el vídeo. Pantalla completa: solo el punto de la barra.
//   · al parar cae desde la isla una tarjeta con el vídeo reproduciéndose en silencio (el GIF animado),
//     cuánto dura, la resolución, lo que pesa y si lleva audio; arrastrar la vista previa suelta el archivo
//     en cualquier app, y los botones Borrar, Carpeta y Abrir. Se va sola a los 8 s (se queda con el ratón encima).
// Con privacidad la tarjeta no enseña el vídeo.
//   qs ipc call grabacion marco "x,y WxH" · grabacion parar · grabacion lista <archivo> <modo> · grabacion muestra
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: g

    IpcHandler {
        target: "grabacion"
        function marco(geo: string): void {
            const m = geo.match(/(-?\d+),(-?\d+)\s+(\d+)x(\d+)/);
            if (!m) return;
            const x = +m[1], y = +m[2];
            const pant = Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) ?? Quickshell.screens[0];
            marcoCapa.screen = pant;
            marcoCapa.zona = Qt.rect(x - pant.x, y - pant.y, +m[3], +m[4]);
            marcoCapa.inicio = Date.now();
            marcoCapa.activo = true;
        }
        function parar(): void { marcoCapa.activo = false; }
        function lista(archivo: string, modo: string): void {
            marcoCapa.activo = false;
            c.abrir(archivo, modo);
        }
        function muestra(): void {
            c.abrir("", "region-audio");
        }
    }

    // ── el marco mientras graba ───────────────────────────────────────────────────────────────────
    PanelWindow {
        id: marcoCapa
        property rect zona: Qt.rect(0, 0, 0, 0)
        property real inicio: 0
        property bool activo: false
        property int segundos: 0
        visible: activo || borde.opacity > 0
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-grabacion-marco"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: nada }          // los clics atraviesan: se sigue trabajando dentro
        Item { id: nada; width: 0; height: 0 }

        Timer {
            interval: 1000; repeat: true; running: marcoCapa.activo; triggeredOnStart: true
            onTriggered: marcoCapa.segundos = Math.floor((Date.now() - marcoCapa.inicio) / 1000)
        }

        // 4 px por fuera de la región: lo que se graba queda limpio
        Rectangle {
            id: borde
            x: marcoCapa.zona.x - 4; y: marcoCapa.zona.y - 4
            width: marcoCapa.zona.width + 8; height: marcoCapa.zona.height + 8
            radius: 4
            color: "transparent"
            border { width: 2; color: Paleta.peligro }
            opacity: marcoCapa.activo ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
            // al empezar, un pulso que se cierra sobre la región
            Rectangle {
                id: pulso
                anchors.centerIn: parent
                property real k: 0
                width: parent.width + 48 * (1 - k); height: parent.height + 48 * (1 - k)
                radius: 12
                color: "transparent"
                border { width: 2; color: Paleta.peligro }
                opacity: marcoCapa.activo && EstiloPanel.movimiento ? (1 - k) * .8 : 0
                NumberAnimation on k { id: cierre; from: 0; to: 1; duration: EstiloPanel.lento * 2; easing.type: Easing.OutCubic }
            }
        }
        onActivoChanged: if (activo) cierre.restart()

        // «● REC 0:12»: encima del marco si cabe, si no debajo
        Rectangle {
            readonly property bool arriba: marcoCapa.zona.y > height + 12
            x: Math.max(4, Math.min(marcoCapa.width - width - 4, borde.x))
            y: arriba ? borde.y - height - 4 : Math.min(marcoCapa.height - height - 4, borde.y + borde.height + 4)
            width: filaRec.implicitWidth + 16; height: 24
            radius: height / 2
            color: Paleta.peligro
            opacity: borde.opacity
            visible: marcoCapa.zona.width > 120
            Row {
                id: filaRec
                anchors.centerIn: parent
                spacing: 4
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: height / 2
                    color: Paleta.fondo
                    opacity: marcoCapa.segundos % 2 ? .4 : 1
                    Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC " + g.reloj(marcoCapa.segundos)
                    color: Paleta.fondo
                    font { family: Paleta.mono; pixelSize: 11; bold: true }
                }
            }
        }
    }

    function reloj(s) {
        s = Math.max(0, Math.round(s));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, ss = String(s % 60).padStart(2, "0");
        return h ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }
    function tam(b) {
        return b >= 1e9 ? (b / 1e9).toFixed(1).replace(".", ",") + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1).replace(".", ",") + " MB"
             : b >= 1e3 ? Math.round(b / 1e3) + " KB" : b + " B";
    }

    // ── la tarjeta al terminar ────────────────────────────────────────────────────────────────────
    PanelWindow {
        id: c
        property string ruta: ""
        property string modo: ""
        property real bytes: 0
        readonly property bool gif: /\.gif$/i.test(ruta) || modo === "gif"
        readonly property bool demo: ruta === ""
        readonly property bool privado: EstadoEscritorio.privacidad
        property bool abierta: false
        property real p: 0

        function abrir(archivo, m) {
            ruta = archivo; modo = m; bytes = archivo ? 0 : 14.2e6;
            if (archivo) { peso.command = ["stat", "-c", "%s", archivo]; peso.running = true; }
            screen = Quickshell.screens.find(s => s.name === Isla.enfocado) ?? Quickshell.screens[0];
            abierta = true;
            visible = true;
            fin.restart();
        }
        function cerrar() { abierta = false; }
        Process {
            id: peso
            stdout: StdioCollector { onStreamFinished: c.bytes = Number(text.trim()) || 0 }
        }

        Timer { id: fin; interval: 8000; onTriggered: if (zona.containsMouse || arrastre.drag.active) restart(); else c.abierta = false }
        Behavior on p { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.lento : 0; easing.type: c.abierta ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.2 } }
        Binding { target: c; property: "p"; value: c.abierta ? 1 : 0 }
        onPChanged: if (p === 0 && !abierta) { visible = false; ruta = ""; }

        visible: false
        color: "transparent"
        anchors.top: true
        implicitWidth: 520
        implicitHeight: 200
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-grabacion"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: tarjeta }

        Rectangle {
            id: tarjeta
            width: parent.width - 16; height: 136
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46 + (1 - c.p) * -40
            opacity: Math.min(1, c.p * 1.6)
            scale: .7 + .3 * c.p
            transformOrigin: Item.Top
            radius: EstiloPanel.rPanel
            color: EstiloPanel.superficie
            border { width: 1; color: EstiloPanel.borde }

            MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true }

            // la vista previa: el vídeo en bucle y sin sonido (16:9)
            Rectangle {
                id: vista
                width: 176; height: 99
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                radius: EstiloPanel.rTarjeta
                color: Qt.alpha(Paleta.peligro, .12)
                border { width: 1; color: Qt.alpha(Paleta.peligro, .3) }
                clip: true
                readonly property bool enVivo: c.visible && !c.privado && !c.demo

                Video {
                    id: video
                    anchors.fill: parent
                    visible: !c.gif && vista.enVivo
                    source: visible ? "file://" + c.ruta : ""
                    fillMode: VideoOutput.PreserveAspectCrop
                    muted: true
                    loops: MediaPlayer.Infinite
                    autoPlay: true
                }
                AnimatedImage {
                    id: animado
                    anchors.fill: parent
                    visible: c.gif && vista.enVivo
                    source: visible ? "file://" + c.ruta : ""
                    fillMode: Image.PreserveAspectCrop
                    playing: visible
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !vista.enVivo
                    text: String.fromCodePoint(c.gif ? 0xF0D78 : 0xF0567)
                    color: Paleta.peligro
                    font { family: Paleta.mono; pixelSize: 36 }
                }
                // duración, abajo a la derecha, como en una galería
                Rectangle {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
                    visible: !c.gif && (video.duration > 0 || c.demo)
                    width: dur.implicitWidth + 12; height: 20; radius: height / 2
                    color: Qt.alpha(Paleta.fondo, .75)
                    Text {
                        id: dur
                        anchors.centerIn: parent
                        text: g.reloj(c.demo ? 42 : video.duration / 1000)
                        color: Paleta.texto
                        font { family: Paleta.mono; pixelSize: 11; bold: true }
                    }
                }
                // la pista de avance
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom }
                    height: 2
                    width: video.duration > 0 ? parent.width * video.position / video.duration : 0
                    color: Paleta.peligro
                    visible: video.visible
                }

                MouseArea {
                    id: arrastre
                    anchors.fill: parent
                    enabled: !c.demo
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: fantasma
                    drag.threshold: 8
                    onPressed: fantasma.x = 0, fantasma.y = 0
                    onClicked: if (!drag.active) { Quickshell.execDetached(["xdg-open", c.ruta]); c.cerrar(); }
                }
                // lo que se arrastra a otra app: el archivo
                Item {
                    id: fantasma
                    width: 1; height: 1
                    Drag.active: arrastre.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(c.ruta) + "\r\n", "text/plain": c.ruta })
                    Drag.onDragFinished: dropAction => { if (dropAction === Qt.CopyAction) c.cerrar(); }
                }
            }

            Column {
                anchors { left: vista.right; leftMargin: 16; right: parent.right; rightMargin: 24; top: parent.top; topMargin: 16 }
                spacing: 4
                Text {
                    text: c.gif ? "GIF listo" : "Grabación guardada"
                    color: Paleta.peligro
                    font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1 }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: c.gif ? "GIF de la pantalla"
                        : (/^pantalla/.test(c.modo) ? "Toda la pantalla" : "Una región") + (c.demo || video.duration > 0 ? " · " + g.reloj(c.demo ? 42 : video.duration / 1000) : "")
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    readonly property size res: c.demo ? Qt.size(1280, 720)
                        : c.gif ? Qt.size(animado.sourceSize.width, animado.sourceSize.height)
                        : video.metaData.value(MediaMetaData.Resolution) ?? Qt.size(0, 0)
                    text: [res.width > 0 ? res.width + "×" + res.height : "",
                           c.bytes > 0 ? g.tam(c.bytes) : "",
                           c.gif ? "" : /audio/.test(c.modo) ? "con sonido" : "sin sonido"].filter(x => x).join(" · ")
                    color: EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 12 }
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 16; bottom: parent.bottom; bottomMargin: 16 }
                spacing: 8
                Boton {
                    glifo: 0xF0A7A; texto: "Borrar"; peligro: true
                    onPulsado: {
                        if (c.ruta) Quickshell.execDetached(["sh", "-c", 'gio trash "$1"; wl-copy --clear', "_", c.ruta]);
                        Isla.mostrar(String.fromCodePoint(0xF0A7A), -1, "Grabación en la papelera");
                        c.cerrar();
                    }
                }
                Boton {
                    glifo: 0xF0770; texto: "Carpeta"
                    onPulsado: { Quickshell.execDetached(["thunar", c.ruta ? c.ruta.replace(/\/[^/]*$/, "") : Quickshell.env("HOME") + "/Videos/Grabaciones"]); c.cerrar(); }
                }
                Boton {
                    glifo: 0xF040A; texto: "Abrir"; principal: true
                    onPulsado: { if (c.ruta) Quickshell.execDetached(["xdg-open", c.ruta]); c.cerrar(); }
                }
            }
        }
    }

    component Boton: Rectangle {
        id: b
        property int glifo: 0
        property string texto: ""
        property bool principal: false
        property bool peligro: false
        signal pulsado()
        readonly property color tono: peligro ? Paleta.peligro : Paleta.acento
        width: filaB.implicitWidth + 24; height: 32
        radius: height / 2
        color: principal || (peligro && zonaB.containsMouse) ? Qt.alpha(tono, zonaB.containsMouse ? .3 : .2)
                         : zonaB.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
        border { width: 1; color: principal ? Qt.alpha(tono, .45) : EstiloPanel.borde }
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Row {
            id: filaB
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(b.glifo)
                color: b.principal || b.peligro ? b.tono : Paleta.texto
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
