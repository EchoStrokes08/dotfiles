// Nota rápida (SUPER+SHIFT+O): un cuadro de una línea. Enter la guarda con fecha y hora al final de
// ~/Documents/notas.md (el archivo del scratchpad SUPER+CTRL+SHIFT+O) y se cierra. Esc cancela.
//   qs ipc call nota abrir          También: «nota …» en el lanzador y SUPER+ALT+O (guarda la selección)
import QtQuick
import QtQuick.Layouts
import Quickshell

Superpuesta {
    id: nota
    espacio: "nota"
    anchoTarjeta: 520
    alturaRelativa: 0.3

    onAbriendose: { campo.text = ""; campo.forceActiveFocus(); }

    RowLayout {
        width: parent.width
        spacing: 12
        Text { Layout.leftMargin: 8; text: String.fromCodePoint(0xF039A); color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 18 } }
        TextInput {
            id: campo
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            verticalAlignment: TextInput.AlignVCenter
            color: Paleta.texto
            selectionColor: Qt.alpha(Paleta.naranja, 0.4)
            font { family: Paleta.fuente; pixelSize: 15 }
            clip: true
            focus: true
            function guardar() {
                if (text.trim() !== "")
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/nota.sh", text.trim()]);
                nota.abierto = false;
            }
            Keys.onReturnPressed: guardar()
            Keys.onEnterPressed: guardar()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: campo.text === ""
                text: "Anota algo y pulsa Enter…"
                color: Paleta.gris
                font: campo.font
            }
        }
    }
}
