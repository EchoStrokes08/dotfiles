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
    property bool copiado: false
    // Acciones solo cuando interesan: al pasar el ratón o con el foco en ellas (ORION 5.6)
    readonly property bool activo: sobre.hovered || botonCopiar.activeFocus || botonOriginal.activeFocus
    // Enlaces citados en el texto, como chips con el dominio (sin repetir y como mucho cuatro)
    readonly property var enlaces: {
        const vistos = [];
        for (const m of (texto.match(/https?:\/\/[^\s<>()\[\]"'`]+/g) || [])) {
            const u = m.replace(/[.,;:!?]+$/, "");
            if (!vistos.includes(u)) vistos.push(u);
        }
        return vistos.slice(0, 4);
    }
    function dominio(u) { const m = u.match(/^https?:\/\/([^\/?#]+)/i); return m ? m[1].replace(/^www\./, "") : u; }
    readonly property string firma: JSON.stringify({texto: texto, color: Paleta.texto.toString(), ancho: Math.floor(width)})
    signal enlace(string url)
    spacing: 4
    HoverHandler { id: sobre }
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
    Flow {
        Layout.fillWidth: true
        visible: raiz.enlaces.length > 0
        spacing: 4
        Repeater {
            model: raiz.enlaces
            Rectangle {
                id: chip
                required property string modelData
                implicitHeight: 24; implicitWidth: Math.min(260, etiquetaChip.implicitWidth + 20); radius: height / 2
                color: zonaChip.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                border { width: 1; color: zonaChip.containsMouse ? EstiloPanel.bordeSeleccion : EstiloPanel.bordeFuerte }
                Text {
                    id: etiquetaChip
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                    text: String.fromCodePoint(0xF059F) + "  " + raiz.dominio(chip.modelData)
                    color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 }
                }
                MouseArea { id: zonaChip; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: raiz.enlace(chip.modelData) }
                ToolTip.visible: zonaChip.containsMouse; ToolTip.delay: 400; ToolTip.text: chip.modelData
                Accessible.role: Accessible.Link; Accessible.name: "Abrir " + raiz.dominio(chip.modelData)
            }
        }
    }
    RowLayout {
        spacing: 4
        opacity: raiz.activo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
        BotonCompacto {
            id: botonCopiar
            text: raiz.copiado ? "Copiado" : "Copiar"
            onClicked: { copia.running = true; raiz.copiado = true; olvidarCopia.restart(); }
        }
        BotonCompacto {
            id: botonOriginal
            visible: raiz.html !== ""
            text: raiz.mostrandoOriginal ? "Ver formato" : "Ver original"
            onClicked: raiz.mostrandoOriginal = !raiz.mostrandoOriginal
        }
    }
    Timer { id: olvidarCopia; interval: 1500; onTriggered: raiz.copiado = false }
    Process {
        id: copia; command: ["wl-copy"]; stdinEnabled: true
        onStarted: { write(raiz.texto); stdinEnabled = false; }
        onExited: stdinEnabled = true
    }
}
