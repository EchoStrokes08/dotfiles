// IA: panel del asistente local (ollama, sin internet). La respuesta aparece según se genera.
//   SUPER+ALT+A        menú sobre el texto seleccionado: resumir, corregir, mejorar, explicar, traducir, preguntar
//   lanzador: «ia …»   pregunta directa
//   qs ipc call ia abrir <accion> "<pregunta>"     (lo llama scripts/ia.sh, que guarda antes la selección)
// Teclas: Enter (con el campo vacío) copia la respuesta y cierra · Enter (con texto) pregunta eso
//         sobre el mismo texto · Ctrl+Enter escribe la respuesta donde estabas · Esc cierra.
// El trabajo lo hace scripts/ia.py; el modelo está en ~/.config/ia/modelo.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: ia
    espacio: "ia"
    anchoTarjeta: 700
    alturaRelativa: 0.11

    property string accion: "preguntar"
    property string respuesta: ""
    property string error: ""
    property bool pensando: false
    readonly property var titulos: ({ resumir: "Resumen", corregir: "Texto corregido", mejorar: "Mejor redactado",
                                      explicar: "Explicación", traducir: "Traducción", preguntar: "Asistente" })

    function abrirCon(a, pregunta) {
        accion = titulos[a] ? a : "preguntar";
        respuesta = ""; error = ""; pensando = false;
        campo.text = accion === "preguntar" ? pregunta : "";
        abierto = true;
        campo.forceActiveFocus();
        if (accion !== "preguntar" || pregunta !== "") lanzar(pregunta);
    }
    function lanzar(pregunta) {
        proc.running = false;
        respuesta = ""; error = ""; pensando = true;
        proc.command = ["sh", "-c", '"$HOME/.config/hypr/scripts/ia.py" "$1" "$2" < "${XDG_RUNTIME_DIR:-/tmp}/ia-entrada.txt"', "_", accion, pregunta];
        proc.running = true;
    }
    function copiar() { if (respuesta) Quickshell.execDetached(["wl-copy", "--", respuesta.trim()]); }
    function escribir() {   // cierra y teclea la respuesta donde estaba el cursor (sustituye lo seleccionado)
        if (!respuesta) return;
        const t = respuesta.trim();
        abierto = false;
        Quickshell.execDetached(["sh", "-c", 'sleep 0.4; wtype -- "$1"', "_", t]);
    }
    onAbiertoChanged: if (!abierto) proc.running = false

    Process {
        id: proc
        stdout: SplitParser { splitMarker: ""; onRead: d => { ia.respuesta += d; } }
        stderr: StdioCollector { onStreamFinished: { if (this.text.trim() !== "") ia.error = this.text.trim().split("\n").pop(); } }
        onExited: ia.pensando = false
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6; Layout.rightMargin: 6
            Text { text: String.fromCodePoint(0xF06A9); color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 16 } }
            Text {
                Layout.fillWidth: true
                text: ia.titulos[ia.accion] ?? "Asistente"
                color: Paleta.gris
                font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1; capitalization: Font.AllUppercase }
            }
            Text {
                visible: ia.pensando
                text: ia.respuesta === "" ? "pensando…" : "escribiendo…"
                color: Paleta.azul
                font { family: Paleta.fuente; pixelSize: 11; italic: true }
                SequentialAnimation on opacity { running: ia.pensando; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
            }
        }

        // Campo: pregunta nueva (o de seguimiento sobre el mismo texto)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 11
            color: Qt.alpha(Paleta.texto, 0.06)
            border { width: 1; color: campo.activeFocus ? Qt.alpha(Paleta.naranja, 0.5) : "transparent" }
            TextInput {
                id: campo
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                verticalAlignment: TextInput.AlignVCenter
                color: Paleta.texto
                selectionColor: Qt.alpha(Paleta.naranja, 0.4)
                font { family: Paleta.fuente; pixelSize: 14 }
                clip: true
                focus: true
                Keys.onPressed: (e) => {
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) return;
                    e.accepted = true;
                    if (e.modifiers & Qt.ControlModifier) ia.escribir();
                    else if (text.trim() !== "") { ia.accion = "preguntar"; ia.lanzar(text.trim()); text = ""; }
                    else { ia.copiar(); ia.abierto = false; }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: campo.text === ""
                    text: ia.respuesta !== "" || ia.pensando ? "Pregunta algo más sobre ese texto…" : "Pregunta lo que quieras…"
                    color: Paleta.gris
                    font: campo.font
                }
            }
        }

        // Respuesta
        Flickable {
            id: vista
            Layout.fillWidth: true
            Layout.leftMargin: 6; Layout.rightMargin: 6
            visible: ia.respuesta !== "" || ia.error !== ""
            implicitHeight: Math.min(texto.implicitHeight, 400)
            contentHeight: texto.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: if (ia.pensando) contentY = Math.max(0, contentHeight - height)   // sigue al texto nuevo
            Text {
                id: texto
                width: vista.width
                text: ia.error !== "" && ia.respuesta === "" ? ia.error : ia.respuesta
                textFormat: ia.error !== "" && ia.respuesta === "" ? Text.PlainText : Text.MarkdownText
                wrapMode: Text.Wrap
                color: ia.error !== "" && ia.respuesta === "" ? Paleta.rojo : Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13 }
                lineHeight: 1.2
            }
        }

        Text {
            Layout.leftMargin: 6
            visible: ia.respuesta !== "" && !ia.pensando
            text: "Enter: copiar y cerrar  ·  Ctrl+Enter: escribirla donde estabas  ·  Esc: cerrar"
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 10 }
        }
    }
}
