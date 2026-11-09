// Música: lo que suena en cualquier reproductor MPRIS (Spotify, Firefox, mpv…).
// Con mostrarLetras: true (el dashboard) enseña la letra sincronizada de lrclib.net (gratis, sin cuenta):
// la línea actual resaltada entre la anterior y la siguiente. Se busca una vez por canción.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

RowLayout {
    id: musica
    spacing: 16
    property bool mostrarLetras: false

    // El que esté sonando; si ninguno, el primero que haya
    readonly property var jugador: {
        const lista = Mpris.players.values;
        return lista.find(p => p.isPlaying) ?? lista[0] ?? null;
    }

    // La posición no se actualiza sola: se le avisa cada segundo mientras suena
    Timer {
        interval: 1000; repeat: true
        running: musica.visible && musica.jugador !== null && musica.jugador.isPlaying
        onTriggered: musica.jugador.positionChanged()
    }

    // ── Letras ──────────────────────────────────────────────────────────
    property var letra: []                    // [{ t: segundos, txt }]
    property var cacheLetras: ({})            // "artista|título" → letra ([] = no hay)
    readonly property string clave: jugador ? (jugador.trackArtist + "|" + jugador.trackTitle) : ""
    onClaveChanged: buscarLetra()
    onMostrarLetrasChanged: buscarLetra()
    function buscarLetra() {
        letra = [];
        if (!mostrarLetras || !jugador || !jugador.trackTitle) return;
        if (cacheLetras[clave] !== undefined) { letra = cacheLetras[clave]; return; }
        pedirLetra.clave = clave;
        pedirLetra.command = ["curl", "-sf", "--max-time", "15", "-A", "dashboard-quickshell (github.com/EchoStrokes08/dotfiles)", "-G",
            "https://lrclib.net/api/get", "--data-urlencode", "artist_name=" + (jugador.trackArtist || ""),
            "--data-urlencode", "track_name=" + jugador.trackTitle,
            ...(jugador.length > 0 ? ["--data-urlencode", "duration=" + Math.round(jugador.length)] : [])];
        pedirLetra.running = true;
    }
    Process {
        id: pedirLetra
        property string clave: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let l = [];
                try {
                    const sinc = JSON.parse(this.text).syncedLyrics ?? "";
                    for (const linea of sinc.split("\n")) {
                        const m = linea.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
                        if (m) l.push({ t: +m[1] * 60 + +m[2], txt: m[3] || "♪" });
                    }
                } catch (e) { }
                const c = Object.assign({}, musica.cacheLetras); c[pedirLetra.clave] = l; musica.cacheLetras = c;
                if (pedirLetra.clave === musica.clave) musica.letra = l;
            }
        }
    }
    // índice de la línea que suena (la última cuyo tiempo ya pasó)
    property real posicion: 0
    Timer {   // la letra necesita más precisión que la barra de progreso
        interval: 250; repeat: true
        running: musica.mostrarLetras && musica.letra.length > 0 && (musica.jugador?.isPlaying ?? false)
        onTriggered: { musica.jugador.positionChanged(); musica.posicion = musica.jugador.position; }
    }
    readonly property int lineaActual: {
        let i = -1;
        for (let k = 0; k < letra.length; k++) { if (letra[k].t <= posicion + 0.3) i = k; else break; }
        return i;
    }

    function mmss(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // Carátula (o una nota si no hay)
    ClippingRectangle {
        Layout.preferredWidth: 84
        Layout.preferredHeight: 84
        radius: 12
        color: Paleta.seleccion
        Text {
            anchors.centerIn: parent
            visible: caratula.status !== Image.Ready
            text: ""; color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 30 }
        }
        Image {
            id: caratula
            anchors.fill: parent
            source: musica.jugador?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: musica.jugador?.trackTitle || "Nada sonando"
            color: Paleta.texto
            elide: Text.ElideRight
            font { family: Paleta.fuente; pixelSize: 15; bold: true }
        }
        Text {
            Layout.fillWidth: true
            text: musica.jugador ? (musica.jugador.trackArtist || musica.jugador.identity) : "pon algo en Spotify o Firefox"
            color: Paleta.gris
            elide: Text.ElideRight
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }

        // Controles: anterior · reproducir/pausa · siguiente
        RowLayout {
            spacing: 22
            opacity: musica.jugador ? 1 : 0.35
            Repeater {
                model: [
                    { icono: "", accion: () => musica.jugador?.previous() },
                    { icono: musica.jugador?.isPlaying ? "" : "", accion: () => musica.jugador?.togglePlaying() },
                    { icono: "", accion: () => musica.jugador?.next() }
                ]
                Text {
                    text: modelData.icono
                    color: zona.containsMouse ? Paleta.naranja : Paleta.texto
                    font { family: Paleta.fuente; pixelSize: index === 1 ? 20 : 15 }
                    MouseArea {
                        id: zona
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true
                        onClicked: modelData.accion()
                    }
                }
            }
        }

        // Barra de progreso
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: (musica.jugador?.lengthSupported ?? false) && musica.jugador.length > 0
            Text {
                text: musica.mmss(musica.jugador?.position ?? 0)
                color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: 2
                color: Qt.alpha(Paleta.texto, 0.12)
                Rectangle {
                    height: parent.height; radius: 2
                    color: Paleta.naranja
                    width: parent.width * Math.min(1, (musica.jugador?.position ?? 0) / Math.max(1, musica.jugador?.length ?? 1))
                    Behavior on width { NumberAnimation { duration: 900 } }
                }
            }
            Text {
                text: musica.mmss(musica.jugador?.length ?? 0)
                color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
            }
        }
    }

    // Letra: anterior · ACTUAL · siguiente
    ColumnLayout {
        visible: musica.mostrarLetras && musica.letra.length > 0
        Layout.preferredWidth: 340
        Layout.maximumWidth: 340
        spacing: 6
        Repeater {
            model: [-1, 0, 1]
            Text {
                required property int modelData
                readonly property int i: musica.lineaActual + modelData
                Layout.fillWidth: true
                text: i >= 0 && i < musica.letra.length ? musica.letra[i].txt : ""
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: modelData === 0 ? Paleta.naranja : Qt.alpha(Paleta.texto, 0.45)
                font { family: Paleta.fuente; pixelSize: modelData === 0 ? 14 : 11; bold: modelData === 0 }
            }
        }
    }
}
