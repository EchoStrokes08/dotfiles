// Historial del portapapeles (SUPER+SHIFT+V), sobre cliphist.
//   escribe para filtrar · ↑↓ · Enter copia · Supr borra la entrada · las imágenes se ven en miniatura
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Superpuesta {
    id: pp
    espacio: "portapapeles"
    anchoTarjeta: 600

    property var entradas: []       // [{ id, texto, imagen }]
    readonly property string cacheMinis: Quickshell.env("HOME") + "/.cache/quickshell/cliphist"
    property int version: 0         // sube cuando hay miniaturas nuevas (para recargarlas)

    onAbriendose: { buscador.text = ""; lista.currentIndex = 0; leer.running = true; buscador.forceActiveFocus(); }

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    // cliphist list → "id<TAB>vista previa"; las imágenes salen como "[[ binary data … png 1920x1080 ]]"
    Process {
        id: leer
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const res = [];
                for (const l of this.text.split("\n")) {
                    const tab = l.indexOf("\t");
                    if (tab < 0) continue;
                    const texto = l.slice(tab + 1);
                    res.push({ id: l.slice(0, tab), texto: texto, imagen: /^\[\[ binary data .* (png|jpe?g|webp|bmp|gif)/i.test(texto) });
                }
                pp.entradas = res;
                // miniaturas de las imágenes que aún no tengan (en segundo plano)
                const ids = res.filter(e => e.imagen).map(e => e.id).join(" ");
                if (ids) { minis.command = ["sh", "-c", `mkdir -p ${pp.cacheMinis}; for i in ${ids}; do f=${pp.cacheMinis}/$i; [ -s "$f" ] || cliphist decode "$i" > "$f"; done`]; minis.running = true; }
            }
        }
    }
    Process { id: minis; onExited: pp.version++ }

    readonly property var filtradas: {
        const q = buscador.text.toLowerCase();
        return q === "" ? entradas : entradas.filter(e => !e.imagen && e.texto.toLowerCase().includes(q));
    }

    function clase(t) {
        const s = String(t || "").trim();
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s)) return { glifo: 0xF03D8, tinte: Paleta.acento, color: s };
        if (/^(https?:\/\/|www\.)\S+$/i.test(s)) return { glifo: 0xF0339, tinte: Paleta.acento2 };
        if (/^(~\/|\/[\w.-]|file:\/\/)[^\n*]*$/.test(s) && s.length < 200 && !/\s{2}/.test(s)) return { glifo: 0xF024B, tinte: Paleta.aviso };
        if (/^(\$ |sudo |cd |git |npm |python3? |paru |pacman |systemctl |hyprctl |qs |\.\/)/.test(s) || /[|&]{2}|\|\s*\w/.test(s) && !/\s{3}/.test(s) && s.length < 300)
            return { glifo: 0xF018D, tinte: Paleta.exito };
        return { glifo: 0xF039A, tinte: EstiloPanel.tenue };
    }
    function copiar(e) {
        if (!e) return;
        sh(`cliphist decode ${e.id} | wl-copy`);
        abierto = false;
    }
    function borrar(e) {
        if (!e) return;
        sh(`cliphist list | awk -F'\\t' '$1 == "${e.id}"' | cliphist delete`);
        entradas = entradas.filter(x => x.id !== e.id);
    }

    ColumnLayout {
        width: parent.width
        spacing: 8

        // Buscador
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42; radius: 12
            color: EstiloPanel.rellenoActivo
            border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.acento, 0.5) : "transparent" }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 8
                Text { text: String.fromCodePoint(0xF0147); color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 16 } }
                TextInput {
                    id: buscador
                    Layout.fillWidth: true
                    color: Paleta.texto
                    clip: true
                    font { family: Paleta.fuente; pixelSize: 14 }
                    onTextChanged: lista.currentIndex = 0
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: "Buscar en el portapapeles…"; color: Paleta.gris; font: parent.font }
                    Keys.onReturnPressed: pp.copiar(pp.filtradas[lista.currentIndex])
                    Keys.onEnterPressed: pp.copiar(pp.filtradas[lista.currentIndex])
                    Keys.onDownPressed: lista.incrementCurrentIndex()
                    Keys.onUpPressed: lista.decrementCurrentIndex()
                    Keys.onTabPressed: lista.incrementCurrentIndex()
                    Keys.onDeletePressed: (e) => {
                        if (text === "" || cursorPosition === text.length) pp.borrar(pp.filtradas[lista.currentIndex]);
                        else e.accepted = false;
                    }
                }
                Rectangle {   // borrar todo
                    implicitWidth: 92; implicitHeight: 26; radius: 8
                    color: zonaWipe.containsMouse ? Qt.alpha(Paleta.peligro, 0.25) : EstiloPanel.rellenoActivo
                    Text { anchors.centerIn: parent; text: "Borrar todo"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                    MouseArea { id: zonaWipe; anchors.fill: parent; hoverEnabled: true; onClicked: { pp.sh("cliphist wipe"); pp.entradas = []; } }
                }
            }
        }

        ListView {
            id: lista
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 430)
            clip: true
            spacing: 4
            model: pp.filtradas
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            keyNavigationWraps: true
            highlight: Rectangle {
                radius: 12
                color: Qt.alpha(Paleta.acento, 0.13)
                Rectangle { width: 3; height: parent.height - 14; radius: 4; color: Paleta.acento
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } }
            }

            delegate: Item {
                id: fila
                required property var modelData
                required property int index
                width: lista.width
                height: modelData.imagen ? 84 : 44

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                    spacing: 12
                    ClippingRectangle {
                        visible: fila.modelData.imagen
                        implicitWidth: 120; implicitHeight: 70; radius: 8
                        color: Paleta.seleccion
                        Image {
                            anchors.fill: parent
                            source: fila.modelData.imagen ? "file://" + pp.cacheMinis + "/" + fila.modelData.id + "?" + pp.version : ""
                            sourceSize { width: 240; height: 140 }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                    }
                    // Qué es cada entrada de un vistazo: enlace, ruta, comando, color o texto
                    Rectangle {
                        visible: !fila.modelData.imagen
                        readonly property var clase: pp.clase(fila.modelData.texto)
                        implicitWidth: 28; implicitHeight: 28; radius: EstiloPanel.rChip
                        color: clase.color ? clase.color : Qt.alpha(clase.tinte, lista.currentIndex === fila.index ? .20 : .11)
                        border.width: clase.color ? 1 : 0
                        border.color: EstiloPanel.bordeFuerte
                        Text {
                            anchors.centerIn: parent
                            visible: !parent.clase.color
                            text: String.fromCodePoint(parent.clase.glifo)
                            color: parent.clase.tinte
                            font { family: Paleta.mono; pixelSize: 14 }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: fila.modelData.imagen
                              ? "Imagen  " + (fila.modelData.texto.match(/(\d+x\d+)/)?.[1] ?? "")
                              : fila.modelData.texto.replace(/\s+/g, " ")
                        color: lista.currentIndex === fila.index ? Paleta.texto : EstiloPanel.secundario
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font { family: Paleta.fuente; pixelSize: 12; italic: fila.modelData.imagen }
                    }
                    Text {   // borrar esta entrada
                        text: ""
                        visible: zonaFila.containsMouse
                        color: zonaBorrar.containsMouse ? Paleta.peligro : Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 12 }
                        MouseArea { id: zonaBorrar; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: pp.borrar(fila.modelData) }
                    }
                }
                MouseArea {
                    id: zonaFila
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    onEntered: lista.currentIndex = fila.index
                    onClicked: pp.copiar(fila.modelData)
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: pp.filtradas.length === 0
            text: pp.entradas.length === 0 ? "El portapapeles está vacío" : "Nada coincide"
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }
        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            atajos: [["↵", "copiar"], ["Supr", "borrar"], ["Esc", "cerrar"]]
        }
    }
}
