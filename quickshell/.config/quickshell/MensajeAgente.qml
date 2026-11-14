// Markdown y fórmulas locales. Mientras llega el formato, el texto sigue disponible.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: raiz
    property string texto: ""
    property string html: ""
    property string aviso: ""
    property string procesado: ""
    property string solicitud: ""
    property bool terminado: true
    property bool mostrandoOriginal: false
    readonly property string firma: JSON.stringify({texto: texto, color: Paleta.texto.toString(), ancho: Math.floor(width)})
    signal enlace(string url)
    spacing: 4
    onFirmaChanged: demora.restart()
    onTerminadoChanged: demora.restart()
    Timer { id: demora; interval: raiz.terminado ? 100 : 650; onTriggered: raiz.preparar() }
    function preparar() {
        if (!texto || width < 40 || render.running || firma === procesado) return;
        solicitud = firma;
        render.running = true;
    }
    Process {
        id: render
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/agente_render.py"]
        stdinEnabled: true
        onStarted: write(raiz.solicitud + "\n")
        stdout: StdioCollector {
            onStreamFinished: {
                if (raiz.solicitud !== raiz.firma) return;
                try {
                    const d = JSON.parse(text);
                    raiz.html = d.html || "";
                    raiz.aviso = d.error || (d.avisos || []).join(" · ");
                    raiz.procesado = raiz.solicitud;
                } catch (e) { raiz.aviso = "No se pudo dar formato. El texto original sigue disponible."; }
            }
        }
        onExited: { if (raiz.firma !== raiz.solicitud) demora.restart(); }
    }
    Component.onCompleted: demora.restart()
    Component.onDestruction: render.running = false
    TextEdit {
        id: contenido
        Layout.fillWidth: true
        Layout.preferredHeight: contentHeight
        readOnly: true; selectByMouse: true
        wrapMode: TextEdit.Wrap
        textFormat: raiz.html && !raiz.mostrandoOriginal ? TextEdit.RichText : TextEdit.PlainText
        text: raiz.html && !raiz.mostrandoOriginal ? raiz.html : raiz.texto
        color: Paleta.texto; selectionColor: Qt.alpha(Paleta.acento,.4)
        selectedTextColor: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14 }
        onLinkActivated: (url) => { if (/^(https?:|mailto:)/i.test(url)) raiz.enlace(url); }
        HoverHandler { cursorShape: contenido.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
    }
    Text {
        Layout.fillWidth: true; visible: text !== ""
        text: raiz.aviso; color: Paleta.peligro; wrapMode: Text.Wrap; font.pixelSize: 11
    }
    RowLayout {
        spacing: 8
        BotonCompacto {
            text: "Copiar texto"; onClicked: { copia.running = true; }
        }
        BotonCompacto {
            text: raiz.mostrandoOriginal ? "Ver formato" : "Ver original"
            onClicked: raiz.mostrandoOriginal = !raiz.mostrandoOriginal
        }
    }
    Process {
        id: copia; command: ["wl-copy"]; stdinEnabled: true
        onStarted: { write(raiz.texto); stdinEnabled = false; }
        onExited: stdinEnabled = true
    }
}
