// Chuleta de atajos (SUPER+H): todos los atajos, agrupados y con buscador.
// NO tiene una lista propia: lee las tablas del manual de usuario (desde "### Atajos de teclado"
// hasta "### Comportamiento automático"). Así, al documentar un atajo nuevo en el manual, aparece aquí solo.
//   escribe para filtrar (busca en tecla y descripción, sin tildes) · Esc cierra
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: ch
    espacio: "chuleta"
    anchoTarjeta: 1100
    alturaRelativa: 0.06

    property var grupos: []        // [{ titulo, filas: [{ tecla, texto }] }]

    onAbriendose: { readme.reload(); buscador.forceActiveFocus(); }
    onAbiertoChanged: if (!abierto) buscador.text = ""

    function buscar(t) { buscador.text = t; }
    function sinTildes(s) { return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }

    FileView {
        id: readme
        path: Quickshell.env("HOME") + "/dotfiles/docs/manual.md"
        onLoaded: ch.leer(text())
    }

    function leer(md) {
        const lineas = md.split("\n");
        const res = [];
        let dentro = false, grupo = null, cabeceras = null;
        for (const l of lineas) {
            if (l.startsWith("### Atajos de teclado")) { dentro = true; continue; }
            if (!dentro) continue;
            if (l.startsWith("### Comportamiento automático")) break;
            const h = l.match(/^#{3,4}\s+(.*)$/);
            if (h) { grupo = { titulo: h[1].replace(/\s*\(`[^`]*`\)/, "").replace(/`/g, ""), filas: [] }; res.push(grupo); cabeceras = null; continue; }
            if (!l.startsWith("|") || !grupo) continue;
            // celdas: partir por | que no esté escapado (\|)
            const celdas = l.replace(/\\\|/g, "\u0000").split("|").slice(1, -1).map(c => c.replace(/\u0000/g, "|").trim());
            if (celdas.every(c => /^-+$/.test(c))) continue;          // |---|---|
            if (!cabeceras) { cabeceras = celdas; continue; }          // primera fila = cabecera
            const limpio = s => s.replace(/`/g, "").replace(/\*\*/g, "");
            // tablas de más de 2 columnas (layouts): "dwindle: …  ·  master: …"
            const texto = celdas.length > 2
                ? celdas.slice(1).map((c, i) => c && c !== "—" ? `${cabeceras[i + 1]}: ${limpio(c)}` : "").filter(x => x).join("  ·  ")
                : limpio(celdas[1] ?? "");
            grupo.filas.push({ tecla: limpio(celdas[0]), texto: texto });
        }
        grupos = res.filter(g => g.filas.length > 0);
    }

    readonly property var filtrados: {
        const q = sinTildes(buscador.text.trim());
        if (!q) return grupos;
        return grupos.map(g => ({ titulo: g.titulo, filas: g.filas.filter(f => sinTildes(f.tecla + " " + f.texto + " " + g.titulo).includes(q)) }))
                     .filter(g => g.filas.length > 0);
    }
    readonly property int total: filtrados.reduce((n, g) => n + g.filas.length, 0)

    ColumnLayout {
        width: parent.width
        spacing: 12

        // Buscador
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42; radius: 11
            color: Qt.alpha(Paleta.texto, 0.06)
            border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.naranja, 0.5) : "transparent" }
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 10
                Text { text: String.fromCodePoint(0xF030C); color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 16 } }
                TextInput {
                    id: buscador
                    Layout.fillWidth: true
                    color: Paleta.texto
                    clip: true
                    font { family: Paleta.fuente; pixelSize: 14 }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: "Buscar atajo… (p. ej. captura, workspace, volumen)"; color: Paleta.gris; font: parent.font }
                    Keys.onEscapePressed: ch.abierto = false
                }
                Text { text: ch.total + " atajos"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
            }
        }

        Flickable {
            Layout.fillWidth: true
            implicitHeight: Math.min(columnas.implicitHeight, (ch.screen?.height ?? 1000) * 0.78)
            contentHeight: columnas.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Grupos repartidos en 3 columnas (cada grupo entero en una columna, rellenando la más corta)
            Row {
                id: columnas
                width: parent.width
                spacing: 18
                readonly property var reparto: {
                    const cols = [[], [], []], alto = [0, 0, 0];
                    for (const g of ch.filtrados) {
                        const i = alto.indexOf(Math.min(...alto));
                        cols[i].push(g); alto[i] += g.filas.length + 2.5;
                    }
                    return cols;
                }
                Repeater {
                    model: 3
                    Column {
                        required property int index
                        width: (columnas.width - 36) / 3
                        spacing: 14
                        Repeater {
                            model: columnas.reparto[index]
                            Column {
                                required property var modelData
                                width: parent.width
                                spacing: 3
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: modelData.titulo
                                    color: Paleta.naranja
                                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                    bottomPadding: 3
                                }
                                Repeater {
                                    model: modelData.filas
                                    Row {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 8
                                        Tecla {
                                            id: chip
                                            texto: modelData.tecla
                                            tinte: Paleta.amarillo
                                            anchoMax: parent.width * 0.42
                                        }
                                        Text {
                                            width: parent.width - chip.width - 8
                                            text: modelData.texto
                                            wrapMode: Text.WordWrap
                                            color: Qt.alpha(Paleta.texto, 0.85)
                                            font { family: Paleta.fuente; pixelSize: 10 }
                                            topPadding: 3
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: ch.total === 0
            text: "Ningún atajo coincide"
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }
        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            atajos: [["", "escribe para buscar"], ["rueda", "desplazar"], ["Esc", "cerrar"], ["", "sale del manual de usuario"]]
        }
    }
}
