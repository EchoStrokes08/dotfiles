// Historial del portapapeles (SUPER+SHIFT+V), sobre cliphist.
//   escribe para filtrar · ↑↓ · Enter copia · Supr borra la entrada · las imágenes se ven en miniatura
import QtQuick
import QtQuick.Effects
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

    onAbriendose: { confirmarBorrado = false; buscador.text = ""; lista.currentIndex = 0; leer.running = true; buscador.forceActiveFocus(); }

    // «Borrar todo» vacía el historial: el primer clic pide confirmar y la petición caduca sola a los 4 s
    property bool confirmarBorrado: false
    Timer { running: pp.confirmarBorrado; interval: 4000; onTriggered: pp.confirmarBorrado = false }

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
                BotonCompacto {   // borrar todo: dos clics (el primero pide confirmar)
                    implicitHeight: 28
                    text: pp.confirmarBorrado ? "¿Borrar todo?" : "Borrar todo"
                    confirmando: pp.confirmarBorrado
                    focusPolicy: Qt.NoFocus
                    onClicked: {
                        if (!pp.confirmarBorrado) { pp.confirmarBorrado = true; return; }
                        pp.confirmarBorrado = false;
                        pp.sh("cliphist wipe"); pp.entradas = [];
                    }
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
            highlightMoveDuration: EstiloPanel.rapido
            keyNavigationWraps: true
            // la misma selección luminosa que el lanzador y los menús
            highlight: FondoSeleccion { radius: EstiloPanel.rControl; marca: true }

            delegate: Item {
                id: fila
                required property var modelData
                required property int index
                readonly property bool actual: lista.currentIndex === index
                readonly property var clase: modelData.imagen ? ({}) : pp.clase(modelData.texto)
                readonly property string dominio: (String(modelData.texto).trim().match(/^(?:https?:\/\/)?(?:www\.)?([^\/\s?#]+)/i) ?? [])[1] ?? ""
                readonly property bool esEnlace: !modelData.imagen && clase.tinte === Paleta.acento2 && dominio !== ""
                width: lista.width
                height: modelData.imagen ? 84 : esEnlace ? 52 : 44

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                    spacing: 12
                    Item {   // miniatura: brilla con sus colores cuando está elegida
                        visible: fila.modelData.imagen
                        implicitWidth: 120; implicitHeight: 70
                        MultiEffect {
                            anchors.centerIn: parent
                            width: parent.width + 24; height: parent.height + 24
                            visible: EstiloPanel.profundidad && fila.actual && mini.status === Image.Ready
                            source: mini
                            blurEnabled: true; blur: 1; blurMax: 40
                            saturation: .4; brightness: .15
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: EstiloPanel.rChip
                            color: EstiloPanel.elevada
                            border { width: 1; color: fila.actual ? Qt.alpha(Paleta.acento, .6) : EstiloPanel.borde }
                            scale: fila.actual ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                            Image {
                                id: mini
                                anchors.fill: parent
                                source: fila.modelData.imagen ? "file://" + pp.cacheMinis + "/" + fila.modelData.id + "?" + pp.version : ""
                                sourceSize { width: 240; height: 140 }
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }
                            Column {   // la imagen no se pudo leer (formato raro o borrada): aviso en vez de un hueco
                                anchors.centerIn: parent
                                visible: mini.status === Image.Error
                                spacing: 2
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xF0976); color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 20 } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sin vista previa"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                            }
                        }
                    }
                    // Qué es cada entrada de un vistazo: enlace, ruta, comando, color o texto
                    Rectangle {
                        visible: !fila.modelData.imagen
                        implicitWidth: 30; implicitHeight: 30; radius: EstiloPanel.rChip
                        color: fila.clase.color ? fila.clase.color : Qt.alpha(fila.clase.tinte, fila.actual ? .20 : .11)
                        border.width: 1
                        border.color: fila.clase.color ? EstiloPanel.bordeFuerte : Qt.alpha(fila.clase.tinte, fila.actual ? .45 : .2)
                        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                        RectangularShadow {   // un color copiado brilla con su propio color
                            anchors.fill: parent; z: -1
                            visible: EstiloPanel.profundidad && (!!fila.clase.color || fila.actual)
                            radius: parent.radius; blur: 12; spread: -2
                            color: Qt.alpha(fila.clase.color ? fila.clase.color : fila.clase.tinte, .5)
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !fila.clase.color
                            text: String.fromCodePoint(fila.clase.glifo ?? 0xF039A)
                            color: fila.clase.tinte ?? EstiloPanel.tenue
                            font { family: Paleta.mono; pixelSize: 14 }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0
                        Text {   // imagen: «Imagen» y sus medidas; enlace: el dominio destacado
                            Layout.fillWidth: true
                            visible: fila.modelData.imagen || fila.esEnlace
                            text: fila.modelData.imagen ? "Imagen" : fila.dominio
                            color: fila.actual ? Paleta.texto : EstiloPanel.secundario
                            elide: Text.ElideRight
                            font { family: Paleta.fuente; pixelSize: 13; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: fila.modelData.imagen
                                  ? (fila.modelData.texto.match(/(\d+x\d+)/)?.[1] ?? "").replace("x", " × ") + " px"
                                  : fila.modelData.texto.replace(/\s+/g, " ").trim()
                            color: fila.modelData.imagen || fila.esEnlace ? EstiloPanel.tenue
                                 : fila.actual ? Paleta.texto : EstiloPanel.secundario
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font { family: fila.clase.color ? Paleta.mono : Paleta.fuente; pixelSize: fila.modelData.imagen || fila.esEnlace ? 11 : 12 }
                        }
                    }
                    Rectangle {   // borrar esta entrada
                        visible: zonaFila.containsMouse || zonaBorrar.containsMouse
                        implicitWidth: 28; implicitHeight: 28; radius: height / 2
                        color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.peligro, .18) : "transparent"
                        border { width: 1; color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.peligro, .5) : "transparent" }
                        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                        Text {
                            anchors.centerIn: parent
                            text: "\uf1f8"
                            color: zonaBorrar.containsMouse ? Paleta.peligro : Paleta.gris
                            font { family: Paleta.fuente; pixelSize: 12 }
                        }
                        MouseArea { id: zonaBorrar; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pp.borrar(fila.modelData) }
                        Accessible.role: Accessible.Button
                        Accessible.name: "Borrar esta entrada"
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
