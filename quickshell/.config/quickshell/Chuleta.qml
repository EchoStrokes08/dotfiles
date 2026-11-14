// Chuleta de atajos (SUPER+H): todos los atajos, agrupados y con buscador.
// NO tiene una lista propia: lee las tablas de docs/atajos.md (desde "### Atajos de teclado"
// hasta "### Comportamiento automático"). Así, al documentar un atajo nuevo en el manual, aparece aquí solo.
//   Al abrir muestra solo los esenciales (filas marcadas con ★ en el manual); al escribir busca entre todos.
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
    property bool todos: false     // «Ver todos»: sin buscar, todos los grupos en lugar de los esenciales

    onAbriendose: { readme.reload(); buscador.forceActiveFocus(); }
    onAbiertoChanged: if (!abierto) { buscador.text = ""; todos = false; }

    function buscar(t) { buscador.text = t; }
    function sinTildes(s) { return s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }

    FileView {
        id: readme
        path: Quickshell.env("HOME") + "/dotfiles/docs/atajos.md"
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
            const tecla = limpio(celdas[0]);
            grupo.filas.push({ tecla: tecla.replace(/^★\s*/, ""), texto: texto, esencial: tecla.startsWith("★") });
        }
        grupos = res.filter(g => g.filas.length > 0);
    }

    // Sin buscar: un solo grupo con los esenciales, en el orden del manual
    readonly property var esenciales: [{ titulo: "Los esenciales", filas: grupos.reduce((a, g) => a.concat(g.filas.filter(f => f.esencial)), []) }]
    readonly property int totalTodos: grupos.reduce((n, g) => n + g.filas.length, 0)
    readonly property var filtrados: {
        const q = sinTildes(buscador.text.trim());
        if (!q) return todos ? grupos : esenciales;
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
            implicitHeight: 42; radius: 12
            color: EstiloPanel.rellenoActivo
            border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.acento, 0.5) : "transparent" }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8
                Text { text: String.fromCodePoint(0xF030C); color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 16 } }
                TextInput {
                    id: buscador
                    Layout.fillWidth: true
                    color: Paleta.texto
                    clip: true
                    font { family: Paleta.fuente; pixelSize: 14 }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: "Buscar atajo… (p. ej. captura, workspace, volumen)"; color: Paleta.gris; font: parent.font }
                    Keys.onEscapePressed: ch.abierto = false
                    Keys.onPressed: (e) => { if (e.key === Qt.Key_T && (e.modifiers & Qt.ControlModifier)) { ch.todos = !ch.todos; e.accepted = true; } }
                }
                Text { text: buscador.text.trim() ? ch.total + " de " + ch.totalTodos + " atajos" : ch.todos ? ch.totalTodos + " atajos" : ch.total + " esenciales · " + ch.totalTodos + " en total"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                BotonCompacto {
                    visible: !buscador.text.trim()
                    text: ch.todos ? "Ver solo los esenciales" : "Ver los " + ch.totalTodos
                    destacado: ch.todos
                    Accessible.name: ch.todos ? "Ver solo los atajos esenciales" : "Ver todos los atajos"
                    onClicked: { ch.todos = !ch.todos; buscador.forceActiveFocus(); }
                }
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
                spacing: 16
                readonly property var reparto: {
                    const cols = [[], [], []], alto = [0, 0, 0];
                    // los esenciales son un solo grupo: se reparten sus filas en las 3 columnas
                    if (!buscador.text.trim() && !ch.todos) {
                        const f = ch.esenciales[0].filas, n = Math.ceil(f.length / 3);
                        return [0, 1, 2].map(i => [{ titulo: i === 0 ? "Los esenciales" : " ", filas: f.slice(i * n, (i + 1) * n) }]);
                    }
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
                        spacing: 12
                        Repeater {
                            model: columnas.reparto[index]
                            Column {
                                required property var modelData
                                width: parent.width
                                spacing: 2
                                Text {
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: modelData.titulo
                                    color: Paleta.acento
                                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                    bottomPadding: 2
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
                                            tinte: Paleta.aviso
                                            anchoMax: parent.width * 0.42
                                        }
                                        Text {
                                            width: parent.width - chip.width - 8
                                            text: modelData.texto
                                            wrapMode: Text.WordWrap
                                            color: EstiloPanel.secundario
                                            font { family: Paleta.fuente; pixelSize: 11 }
                                            topPadding: 2
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
            atajos: [["", "escribe para buscar entre todos"], ["Ctrl+T", ch.todos ? "solo esenciales" : "ver todos"], ["rueda", "desplazar"], ["Esc", "cerrar"]]
        }
    }
}
