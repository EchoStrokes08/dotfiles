// Agente (SUPER+O): le hablas al escritorio y él usa todo lo demás. 100 % local (scripts/agente.py + ollama).
//   · consulta y abre sin preguntar; lo que CAMBIA algo te lo propone y espera tu «Sí»
//   · «qué leí / dónde vi / qué hice…» busca en tu memoria (scripts/memoria.py) y cita las fuentes
//   · micrófono: habla en vez de escribir (dictado local con Whisper)
//   · historial a la izquierda: tus conversaciones guardadas; clic = retomarla donde la dejaste
// Teclas: Enter enviar · Ctrl+L nueva conversación · Ctrl+↑/↓ conversación anterior/siguiente · Ctrl+Espacio micrófono
//         S / N en una confirmación · Esc cerrar
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
    anchoTarjeta: Math.min(1120, (screen?.width ?? 1280) - 40)
    alturaRelativa: 0.06
    opacidadTarjeta: 0.96
    acentoPanel: Paleta.morado

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    property var mensajes: []             // {rol: tu|asistente|paso|fuentes|confirmar|error, texto, lista, resuelto}
    property bool pensando: false
    property bool listo: false            // modelo cargado (la primera vez tarda ~1 min en esta CPU)
    property real calentadoEn: 0
    property bool escuchando: false
    property string pendienteTexto: ""    // lo que mandaste mientras el modelo despertaba
    property var historial: []            // [{id, titulo, actualizada, n}] más reciente primero
    property string idActual: ""
    readonly property bool privado: EstadoEscritorio.privacidad

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

    // ── historial ────────────────────────────────────────────────────────
    function refrescarHistorial() { pHistorial.running = true; }
    function nuevaConversacion() {
        if (proceso.running) return;
        mensajes = []; idActual = "";
        pOrden.command = [scripts + "agente.py", "nueva"]; pOrden.running = true;
        entrada.forceActiveFocus();
    }
    function abrirConversacion(id) {
        if (proceso.running || !id || (id === idActual && mensajes.length)) return;
        pCargar.command = [scripts + "agente.py", "abrir", id]; pCargar.running = true;
    }
    function borrarConversacion(id) {
        if (proceso.running) return;
        if (id === idActual) { mensajes = []; idActual = ""; }
        historial = historial.filter(c => c.id !== id);          // respuesta inmediata
        pOrden.command = [scripts + "agente.py", "borrar", id]; pOrden.running = true;
    }
    function moverConversacion(paso) {
        if (!historial.length) return;
        const i = historial.findIndex(c => c.id === idActual);
        const j = Math.max(0, Math.min(historial.length - 1, (i < 0 ? -1 : i) + paso));
        abrirConversacion(historial[j].id);
    }
    function cargarVista(d) {
        idActual = d.id || "";
        mensajes = (d.vista || []).map(v => v.rol === "asistente" ? Object.assign({}, v, { cerrado: true }) : v);
        Qt.callLater(() => lista.positionViewAtEnd());
    }
    // «Hoy», «Ayer», «Últimos 7 días», «Anteriores»
    function grupoDe(ts) {
        const d = new Date(ts * 1000), hoy = new Date(); hoy.setHours(0, 0, 0, 0);
        const dias = Math.floor((hoy - new Date(d.getFullYear(), d.getMonth(), d.getDate())) / 86400000);
        return dias <= 0 ? "Hoy" : dias === 1 ? "Ayer" : dias < 7 ? "Últimos 7 días" : "Anteriores";
    }
    function cuandoFue(ts) {
        const d = new Date(ts * 1000), g = grupoDe(ts);
        return g === "Hoy" ? Qt.formatTime(d, "HH:mm") : g === "Ayer" ? "ayer " + Qt.formatTime(d, "HH:mm")
             : d.toLocaleDateString(Qt.locale("es_ES"), g === "Anteriores" ? "d MMM" : "dddd");
    }

    onAbriendose: {
        Qt.callLater(() => entrada.forceActiveFocus());
        refrescarHistorial();
        if (mensajes.length === 0 && !proceso.running) { pCargar.command = [scripts + "agente.py", "actual"]; pCargar.running = true; }
        if (Date.now() - calentadoEn > 15 * 60 * 1000 && !calentador.running) { listo = false; calentador.running = true; }
    }

    // ── procesos ─────────────────────────────────────────────────────────
    Process {
        id: pHistorial
        command: [ag.scripts + "agente.py", "historial"]
        stdout: StdioCollector { onStreamFinished: { try { ag.historial = JSON.parse(text).lista || []; } catch (e) {} } }
    }
    Process {
        id: pCargar
        stdout: StdioCollector { onStreamFinished: { try { ag.cargarVista(JSON.parse(text)); } catch (e) {} } }
    }
    Process {
        id: pOrden
        onExited: ag.refrescarHistorial()
    }
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
                else if (e.t === "fin") { ag.pensando = false; ag.listo = true; ag.calentadoEn = Date.now(); ag.refrescarHistorial();
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
        implicitHeight: 34
        leftPadding: 14; rightPadding: 14
        hoverEnabled: true
        scale: down ? .96 : 1
        Behavior on scale { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }
        background: FondoBoton { tinte: bt.acento; destacado: bt.destacado; encima: bt.hovered; pulsado: bt.down; foco: bt.activeFocus; radio: 10 }
        contentItem: Text { text: bt.text; color: !bt.enabled ? Paleta.gris : bt.destacado || bt.hovered ? Paleta.texto : Qt.tint(Paleta.texto, Qt.alpha(Paleta.fondo, .2)); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; font { family: Paleta.fuente; pixelSize: 12; bold: bt.destacado } }
    }

    Shortcut { sequence: "Ctrl+L"; enabled: ag.abierto; onActivated: ag.nuevaConversacion() }
    Shortcut { sequence: "Ctrl+Up"; enabled: ag.abierto; onActivated: ag.moverConversacion(-1) }
    Shortcut { sequence: "Ctrl+Down"; enabled: ag.abierto; onActivated: ag.moverConversacion(1) }
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
            Boton { text: "󰅖"; Accessible.name: "Cerrar"; implicitWidth: 38; implicitHeight: 38; leftPadding: 0; rightPadding: 0; onClicked: ag.abierto = false; background: FondoBoton { tinte: Paleta.rojo; encima: parent.hovered; foco: parent.activeFocus; radio: 19 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            // ── historial de conversaciones ──────────────────────────────
            Rectangle {
                id: lateral
                Layout.preferredWidth: 264
                Layout.fillHeight: true
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(Paleta.morado, .5)), .06) }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.texto, .02) }
                }
                border { width: 1; color: Qt.alpha(Paleta.texto, .075) }

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4; Layout.topMargin: 2
                        Text { text: "CONVERSACIONES"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1.6 } }
                        Rectangle {
                            visible: ag.historial.length > 0
                            implicitWidth: Math.max(20, cuentaHist.implicitWidth + 12); implicitHeight: 18; radius: 9
                            color: Qt.alpha(Paleta.morado, .2)
                            Text { id: cuentaHist; anchors.centerIn: parent; text: ag.historial.length; color: Paleta.morado; font { family: Paleta.fuente; pixelSize: 10; bold: true } }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Boton {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        text: ag.g("f0415") + "  Nueva conversación   ⌃L"
                        acento: Paleta.morado
                        destacado: ag.mensajes.length === 0
                        enabled: !proceso.running
                        onClicked: ag.nuevaConversacion()
                    }

                    ListView {
                        id: listaHist
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: ag.historial
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Item {
                            id: conv
                            required property var modelData
                            required property int index
                            readonly property string grupo: ag.grupoDe(modelData.actualizada)
                            readonly property bool cabecera: index === 0 || ag.grupoDe(ag.historial[index - 1]?.actualizada ?? 0) !== grupo
                            readonly property bool actual: modelData.id === ag.idActual
                            width: ListView.view.width - 6
                            height: 52 + (cabecera ? 26 : 0)

                            Text {
                                visible: conv.cabecera
                                anchors { left: parent.left; leftMargin: 8; top: parent.top; topMargin: conv.index === 0 ? 4 : 10 }
                                text: conv.grupo
                                color: Qt.alpha(Paleta.texto, .55)
                                font { family: Paleta.fuente; pixelSize: 10; bold: true }
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 50; radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: conv.actual ? Qt.alpha(Paleta.morado, .26) : Qt.alpha(Paleta.texto, zonaConv.containsMouse ? .07 : 0) }
                                    GradientStop { position: 1; color: conv.actual ? Qt.alpha(Paleta.morado, .07) : Qt.alpha(Paleta.texto, zonaConv.containsMouse ? .03 : 0) }
                                }
                                border { width: conv.actual ? 1 : 0; color: Qt.alpha(Paleta.morado, .4) }
                                Rectangle {
                                    visible: conv.actual
                                    width: 3; height: parent.height - 20; radius: 2
                                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                    color: Paleta.morado
                                }
                                ColumnLayout {
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: borrarConv.visible ? 36 : 10 }
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: ag.privado ? ag.g("f033e") + "  Conversación" : conv.modelData.titulo
                                        elide: Text.ElideRight
                                        color: conv.actual ? Paleta.texto : Qt.alpha(Paleta.texto, .85)
                                        font { family: Paleta.fuente; pixelSize: 12; bold: conv.actual }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: ag.cuandoFue(conv.modelData.actualizada) + " · " + conv.modelData.n + (conv.modelData.n === 1 ? " mensaje" : " mensajes")
                                        elide: Text.ElideRight
                                        color: Paleta.gris
                                        font { family: Paleta.fuente; pixelSize: 10 }
                                    }
                                }
                                MouseArea {
                                    id: zonaConv
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ag.abrirConversacion(conv.modelData.id)
                                }
                                // Borrar (aparece al pasar el ratón)
                                Rectangle {
                                    id: borrarConv
                                    visible: zonaConv.containsMouse || zonaBorrarConv.containsMouse
                                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    width: 26; height: 26; radius: 13
                                    color: zonaBorrarConv.containsMouse ? Qt.alpha(Paleta.rojo, .25) : Qt.alpha(Paleta.texto, .06)
                                    Text { anchors.centerIn: parent; text: ag.g("f0a7a"); color: zonaBorrarConv.containsMouse ? Paleta.rojo : Paleta.gris; font { family: Paleta.fuente; pixelSize: 13 } }
                                    MouseArea { id: zonaBorrarConv; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.borrarConversacion(conv.modelData.id) }
                                    ToolTip.visible: zonaBorrarConv.containsMouse; ToolTip.delay: 400; ToolTip.text: "Borrar del historial"
                                }
                            }
                        }
                        // vacío
                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            visible: ag.historial.length === 0
                            spacing: 6
                            Text { Layout.alignment: Qt.AlignHCenter; text: ag.g("f0b79"); color: Qt.alpha(Paleta.morado, .6); font { family: Paleta.fuente; pixelSize: 28 } }
                            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Aquí aparecerán tus conversaciones para retomarlas cuando quieras"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: ag.historial.length > 1
                        text: "⌃↑ ⌃↓ moverse entre ellas"
                        color: Qt.alpha(Paleta.gris, .8)
                        font { family: Paleta.fuente; pixelSize: 9 }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 12
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
