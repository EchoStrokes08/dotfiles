// Agente (SUPER+O): le hablas al escritorio y él usa todo lo demás. 100 % local (scripts/agente.py + ollama).
//   · consulta y abre sin preguntar; lo que CAMBIA algo te lo propone y espera tu «Sí»
//   · «qué leí / dónde vi / qué hice…» busca en tu memoria (scripts/memoria.py) y cita las fuentes
//   · micrófono: habla en vez de escribir (dictado local con Whisper)
// Teclas: Enter enviar · Ctrl+L nueva conversación · Ctrl+Espacio micrófono · S / N en una confirmación · Esc cerrar
//   qs ipc call agente toggle · qs ipc call agente preguntar "¿qué tengo mañana?"
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: ag
    espacio: "agente"
    anchoTarjeta: Math.min(860, (screen?.width ?? 1280) - 40)
    alturaRelativa: 0.06
    opacidadTarjeta: 0.96

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    property var mensajes: []             // {rol: tu|asistente|paso|fuentes|confirmar|error, texto, lista, resuelto}
    property bool pensando: false
    property bool listo: false            // modelo cargado (la primera vez tarda ~1 min en esta CPU)
    property real calentadoEn: 0
    property bool escuchando: false
    property string pendienteTexto: ""    // lo que mandaste mientras el modelo despertaba

    function g(hex) { return String.fromCodePoint(parseInt(hex, 16)); }
    function agregar(m) { mensajes = [...mensajes, m]; Qt.callLater(() => lista.positionViewAtEnd()); }
    function ultimo() { return mensajes[mensajes.length - 1]; }
    function reemplazarUltimo(m) { const c = mensajes.slice(); c[c.length - 1] = m; mensajes = c; Qt.callLater(() => lista.positionViewAtEnd()); }

    function abrirYPreguntar(t) { abierto = true; if (t) enviar(t); }
    function enviar(t) {
        t = (t ?? "").trim();
        if (!t || proceso.running) return;
        agregar({ rol: "tu", texto: t });
        entrada.text = "";
        if (!listo && calentador.running) { pendienteTexto = t; agregar({ rol: "paso", texto: "Despertando al asistente (la primera vez tarda ~1 min)…" }); return; }
        correr(["turno", t]);
    }
    function correr(args) {
        pensando = true;
        proceso.command = [scripts + "agente.py", ...args];
        proceso.running = true;
    }
    function responder(si) {
        const c = mensajes.slice();
        for (let i = c.length - 1; i >= 0; i--) if (c[i].rol === "confirmar" && !c[i].resuelto) { c[i] = Object.assign({}, c[i], { resuelto: si ? "si" : "no" }); break; }
        mensajes = c;
        correr(["confirmar", si ? "si" : "no"]);
    }
    readonly property bool hayConfirmacion: mensajes.some(m => m.rol === "confirmar" && !m.resuelto)

    onAbriendose: {
        Qt.callLater(() => entrada.forceActiveFocus());
        if (Date.now() - calentadoEn > 15 * 60 * 1000 && !calentador.running) { listo = false; calentador.running = true; }
    }

    // ── procesos ─────────────────────────────────────────────────────────
    Process {
        id: calentador
        command: [ag.scripts + "agente.py", "precalentar"]
        onExited: { ag.listo = true; ag.calentadoEn = Date.now();
                    if (ag.pendienteTexto) { const t = ag.pendienteTexto; ag.pendienteTexto = ""; ag.correr(["turno", t]); } }
    }
    Process {
        id: proceso
        stdout: SplitParser {
            onRead: (linea) => {
                let e; try { e = JSON.parse(linea); } catch (x) { return; }
                const u = ag.ultimo();
                if (e.t === "texto") {
                    if (u && u.rol === "asistente" && !u.cerrado) ag.reemplazarUltimo({ rol: "asistente", texto: u.texto + e.d });
                    else ag.agregar({ rol: "asistente", texto: e.d.replace(/^\s+/, "") });
                } else if (e.t === "herramienta") ag.agregar({ rol: "paso", texto: e.resumen });
                else if (e.t === "fuentes") {
                    if (u && u.rol === "fuentes") ag.reemplazarUltimo({ rol: "fuentes", lista: e.lista });
                    else ag.agregar({ rol: "fuentes", lista: e.lista });
                } else if (e.t === "confirmar") ag.agregar({ rol: "confirmar", texto: e.descripcion });
                else if (e.t === "error") ag.agregar({ rol: "error", texto: e.mensaje });
                else if (e.t === "fin") { ag.pensando = false; ag.listo = true; ag.calentadoEn = Date.now();
                                          if (u && u.rol === "asistente") ag.reemplazarUltimo(Object.assign({}, u, { cerrado: true })); }
            }
        }
        onExited: ag.pensando = false
    }
    Process {
        id: microfono
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); if (t && !t.startsWith("\0")) { ag.escuchando = false; ag.enviar(t); } } }
        onExited: ag.escuchando = false
    }
    function alternarMicro() {
        if (escuchando) { microfono.command = [scripts + "dictado.sh", "texto"]; microfono.running = true; }
        else { Quickshell.execDetached([scripts + "dictado.sh", "texto"]); escuchando = true; }
    }

    // ── piezas ───────────────────────────────────────────────────────────
    component Boton: Button {
        id: bt
        property bool destacado: false
        property color acento: Paleta.naranja
        implicitHeight: 32
        leftPadding: 12; rightPadding: 12
        background: Rectangle {
            radius: 9
            color: Qt.alpha(bt.acento, bt.destacado ? (bt.hovered ? .34 : .22) : (bt.hovered ? .14 : .06))
            border { width: 1; color: Qt.alpha(bt.acento, bt.destacado || bt.activeFocus ? .7 : .2) }
        }
        contentItem: Text { text: bt.text; color: bt.enabled ? Paleta.texto : Paleta.gris; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font { family: Paleta.fuente; pixelSize: 12; bold: bt.destacado } }
    }

    Shortcut { sequence: "Ctrl+L"; enabled: ag.abierto; onActivated: { Quickshell.execDetached([ag.scripts + "agente.py", "nueva"]); ag.mensajes = []; } }
    Shortcut { sequence: "Ctrl+Space"; enabled: ag.abierto; onActivated: ag.alternarMicro() }
    Shortcut { sequence: "S"; enabled: ag.abierto && ag.hayConfirmacion && !entrada.activeFocus && !proceso.running; onActivated: ag.responder(true) }
    Shortcut { sequence: "N"; enabled: ag.abierto && ag.hayConfirmacion && !entrada.activeFocus && !proceso.running; onActivated: ag.responder(false) }

    ColumnLayout {
        width: parent.width; spacing: 12

        // ── cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Rectangle {
                implicitWidth: 48; implicitHeight: 48; radius: 24
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Paleta.morado, .5) }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.azul, .4) }
                }
                Text { anchors.centerIn: parent; text: "✦"; color: Paleta.texto; font { pixelSize: 22 }
                    RotationAnimation on rotation { running: ag.pensando || calentador.running; loops: Animation.Infinite; from: 0; to: 360; duration: 2400 } }
                // halo mientras piensa
                Rectangle {
                    anchors.centerIn: parent; width: parent.width + 10; height: width; radius: width / 2; color: "transparent"
                    border { width: 2; color: Qt.alpha(Paleta.morado, .6) }
                    visible: ag.pensando || calentador.running
                    SequentialAnimation on opacity { running: ag.pensando || calentador.running; loops: Animation.Infinite
                        NumberAnimation { to: .15; duration: 700 } NumberAnimation { to: .8; duration: 700 } }
                }
            }
            ColumnLayout {
                spacing: 1
                Text { text: "ASISTENTE · EN TU EQUIPO"; color: Paleta.morado; font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1.6 } }
                Text { text: "¿En qué te ayudo?"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 22; bold: true } }
                Text {
                    color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                    text: calentador.running ? "Despertando al asistente… la primera vez tarda alrededor de un minuto"
                        : ag.pensando ? "Pensando…" : ag.escuchando ? "Escuchando… pulsa el micrófono para terminar"
                        : "Listo · sin internet · lo que cambie algo te lo pregunto antes"
                }
            }
            Item { Layout.fillWidth: true }
            Boton { text: "Nueva"; acento: Paleta.gris; onClicked: { Quickshell.execDetached([ag.scripts + "agente.py", "nueva"]); ag.mensajes = []; entrada.forceActiveFocus(); } }
            Boton { text: "Esc"; implicitWidth: 52; onClicked: ag.abierto = false }
        }

        // ── conversación ─────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; implicitHeight: 440
            ListView {
                id: lista
                anchors.fill: parent; clip: true; spacing: 10
                boundsBehavior: Flickable.StopAtBounds
                model: ag.mensajes
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Item {
                    id: msj
                    required property var modelData
                    required property int index
                    width: ListView.view.width - 12
                    implicitHeight: contenido.implicitHeight
                    opacity: 0
                    Component.onCompleted: entra.start()
                    NumberAnimation { id: entra; target: msj; property: "opacity"; to: 1; duration: 200 }

                    Loader {
                        id: contenido
                        width: parent.width
                        sourceComponent: ({ tu: burbujaTu, asistente: burbujaAsistente, paso: paso, fuentes: fuentes, confirmar: confirmar, error: error })[msj.modelData.rol] ?? paso
                        property var m: msj.modelData
                    }
                }
            }
            // vacío: ideas para empezar
            ColumnLayout {
                anchors.centerIn: parent; width: parent.width - 60; spacing: 14
                visible: ag.mensajes.length === 0
                Text { Layout.alignment: Qt.AlignHCenter; text: "Pregúntame o pídeme algo, como se lo dirías a alguien"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 13 } }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: ["¿Qué tengo mañana?", "¿Qué estuve leyendo sobre el método de dos fases?", "Prepárame para estudiar",
                                "¿Cómo está el equipo?", "¿Qué hice ayer por la tarde?", "Ponme concentración de 50 minutos",
                                "¿Tengo mensajes en el móvil?", "Busca mis apuntes de redes"]
                        Rectangle {
                            required property string modelData
                            implicitHeight: 34; implicitWidth: sug.implicitWidth + 26; radius: 17
                            color: Qt.alpha(Paleta.morado, zs.containsMouse ? .2 : .08); border { width: 1; color: Qt.alpha(Paleta.morado, .3) }
                            Text { id: sug; anchors.centerIn: parent; text: parent.modelData; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
                            MouseArea { id: zs; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.enviar(parent.modelData) }
                        }
                    }
                }
            }
        }

        // ── entrada ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 46; radius: 23
                color: Qt.alpha(Paleta.texto, .05)
                border { width: 1; color: Qt.alpha(Paleta.morado, entrada.activeFocus ? .6 : .15) }
                TextField {
                    id: entrada
                    anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
                    placeholderText: ag.hayConfirmacion ? "Responde arriba (S / N) o escribe otra cosa…" : "Escribe aquí… (Enter para enviar)"
                    color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14 }
                    background: null
                    Keys.onReturnPressed: ag.enviar(text)
                    Keys.onEnterPressed: ag.enviar(text)
                }
            }
            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: 23
                color: ag.escuchando ? Qt.alpha(Paleta.rojo, .35) : Qt.alpha(Paleta.texto, zm.containsMouse ? .1 : .05)
                border { width: 1; color: Qt.alpha(ag.escuchando ? Paleta.rojo : Paleta.morado, .4) }
                Text { anchors.centerIn: parent; text: ag.g(ag.escuchando ? "f036d" : "f036c"); color: ag.escuchando ? Paleta.rojo : Paleta.texto; font { family: Paleta.fuente; pixelSize: 18 } }
                SequentialAnimation on scale { running: ag.escuchando; loops: Animation.Infinite; NumberAnimation { to: 1.08; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
                MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.alternarMicro() }
            }
            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: 23
                color: Qt.alpha(Paleta.morado, entrada.text.trim() && !ag.pensando ? (ze.containsMouse ? .5 : .35) : .08)
                Text { anchors.centerIn: parent; text: ag.g("f048a"); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 18 } }
                MouseArea { id: ze; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.enviar(entrada.text) }
            }
        }
    }

    // ── tipos de mensaje ─────────────────────────────────────────────────
    Component {
        id: burbujaTu
        Item {
            implicitHeight: bt.implicitHeight
            Rectangle {
                id: bt
                anchors.right: parent.right
                width: Math.min(parent.width * .75, tt.implicitWidth + 28); implicitHeight: tt.implicitHeight + 18; radius: 16
                color: Qt.alpha(Paleta.naranja, .16); border { width: 1; color: Qt.alpha(Paleta.naranja, .3) }
                Text { id: tt; anchors { fill: parent; margins: 9; leftMargin: 14; rightMargin: 14 } wrapMode: Text.Wrap; text: parent.parent.parent.m.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13 } }
            }
        }
    }
    Component {
        id: burbujaAsistente
        RowLayout {
            spacing: 10
            Text { text: "✦"; color: Paleta.morado; font.pixelSize: 15; Layout.alignment: Qt.AlignTop; Layout.topMargin: 2 }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.MarkdownText
                text: parent.parent.m.texto; color: Paleta.texto; lineHeight: 1.2
                font { family: Paleta.fuente; pixelSize: 13 }
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }
        }
    }
    Component {
        id: paso
        RowLayout {
            spacing: 8
            Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: Paleta.azul; Layout.leftMargin: 26 }
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: parent.parent.m.texto; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11; italic: true } }
        }
    }
    Component {
        id: fuentes
        Flow {
            spacing: 6; leftPadding: 26
            Repeater {
                model: parent.parent.m.lista ?? []
                Rectangle {
                    id: fu
                    required property var modelData
                    required property int index
                    implicitHeight: 26; implicitWidth: Math.min(300, ft.implicitWidth + 20); radius: 13
                    color: Qt.alpha(Paleta.azul, zf.containsMouse ? .2 : .08); border { width: 1; color: Qt.alpha(Paleta.azul, .3) }
                    Text { id: ft; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        text: `[${fu.index + 1}] ` + ag.g(({ documento: "f0219", web: "f059f", linea: "f0954" })[fu.modelData.tipo] ?? "f0219") + " " + fu.modelData.titulo
                        color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 10 } }
                    MouseArea {
                        id: zf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const r = fu.modelData.ref;
                            if (fu.modelData.tipo === "linea") Quickshell.execDetached(["qs", "ipc", "call", "brujula", "dia", r]);
                            else Quickshell.execDetached(["xdg-open", r]);
                            ag.abierto = false;
                        }
                    }
                    ToolTip.visible: zf.containsMouse; ToolTip.delay: 300; ToolTip.text: fu.modelData.ref
                }
            }
        }
    }
    Component {
        id: confirmar
        Rectangle {
            readonly property var m: parent.m
            implicitHeight: cc.implicitHeight + 24; radius: 14
            color: Qt.alpha(m.resuelto === "no" ? Paleta.gris : Paleta.verde, .08)
            border { width: 1; color: Qt.alpha(m.resuelto === "no" ? Paleta.gris : Paleta.verde, m.resuelto ? .2 : .55) }
            RowLayout {
                id: cc
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 } spacing: 12
                Text { text: ag.g(parent.parent.m.resuelto === "si" ? "f012c" : parent.parent.m.resuelto === "no" ? "f0156" : "f02d7"); color: parent.parent.m.resuelto === "no" ? Paleta.gris : Paleta.verde; font { family: Paleta.fuente; pixelSize: 20 } }
                ColumnLayout { Layout.fillWidth: true; spacing: 1
                    Text { text: parent.parent.parent.m.resuelto === "si" ? "HECHO" : parent.parent.parent.m.resuelto === "no" ? "NO SE HIZO" : "¿LO HAGO?"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 9; bold: true; letterSpacing: 1.4 } }
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: parent.parent.parent.m.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                }
                Boton { visible: !parent.parent.m.resuelto; text: "Sí, hazlo  S"; destacado: true; acento: Paleta.verde; enabled: !proceso.running; onClicked: ag.responder(true) }
                Boton { visible: !parent.parent.m.resuelto; text: "No  N"; acento: Paleta.gris; enabled: !proceso.running; onClicked: ag.responder(false) }
            }
        }
    }
    Component {
        id: error
        Text { wrapMode: Text.Wrap; leftPadding: 26; text: "⚠ " + parent.m.texto; color: Paleta.rojo; font { family: Paleta.fuente; pixelSize: 12 } }
    }
}
