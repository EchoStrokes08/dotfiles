// Agente (SUPER+O): modelo local, herramientas del sistema y navegador visible con perfil propio.
//   · consulta y abre sin preguntar; lo que CAMBIA algo te lo propone y espera tu «Sí»
//   · «qué leí / dónde vi / qué hice…» busca en tu memoria (scripts/memoria.py) y cita las fuentes
//   · micrófono: habla en vez de escribir (dictado local con Whisper)
//   · historial a la izquierda: tus conversaciones guardadas; clic = retomarla donde la dejaste
// Teclas: Enter enviar · Ctrl+L nueva conversación · Ctrl+↑/↓ conversación anterior/siguiente · Ctrl+Espacio micrófono
//         S / N en una confirmación · Esc cerrar
//   qs ipc call agente toggle · qs ipc call agente preguntar "¿qué tengo mañana?"
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    Connections {
        target: EstadoEscritorio
        function onCapturaPrivadaChanged() { if(EstadoEscritorio.capturaPrivada) ag.abierto=false; }
    }
    property var mensajes: []             // {rol: tu|asistente|paso|fuentes|confirmar|error, texto, lista, resuelto}
    property bool pensando: false
    property bool listo: false            // modelo cargado (la primera vez tarda ~1 min en esta CPU)
    property bool navegadorListo: false
    property string nube: ""              // modelo en la nube en uso ("" = local)
    // Selector de modelo y esfuerzo (se guarda en ~/.local/state/brujula/agente/eleccion.json)
    property var modelos: ["auto"]
    property var grupos: ({})            // modelo → proveedor ("Google", "Groq"), para separarlos en el selector
    property var nombres: ({})           // modelo → nombre visible que da Google («Gemini 3.5 Flash»)
    property var estados: ({})           // modelo → resultado de la prueba diaria («Lento: tardó 20 s»)
    function proveedorDe(id) { return id === "local" ? "Este equipo" : (grupos[id] || ""); }
    function colorGrupo(g) { return g === "Google" ? Paleta.acento2 : g === "Groq" ? Paleta.acento : EstiloPanel.tenue; }
    property string modeloElegido: "auto"
    property string esfuerzo: "bajo"
    function tituloModelo(id) { return nombreModelo(id).split(" · ")[0]; }
    function notaModelo(id) { if (estados[id]) return estados[id]; const p = nombreModelo(id).split(" · "); return p.length > 1 ? p[1].charAt(0).toUpperCase() + p[1].slice(1) : ""; }
    function nombreModelo(id) {
        const n = { "auto": "Auto · el mejor disponible", "local": "Local · privado, lento",
                    "openai/gpt-oss-120b": "GPT-OSS 120B · el más listo", "qwen/qwen3.8-27b": "Qwen 3.8 27B · equilibrado",
                    "openai/gpt-oss-20b": "GPT-OSS 20B · el más rápido",
                    "gemini-4-hydrogen": "Gemini 4 Hydrogen · Google, de serie" };
        return n[id] || nombres[id] || id;
    }
    function leerOpciones(texto) {
        try { const o = JSON.parse(texto); modelos = o.modelos; grupos = o.grupos || {}; nombres = o.nombres || {}; estados = o.estados || {}; modeloElegido = o.modelo; esfuerzo = o.esfuerzo;
              if (o.permisos) permisos = o.permisos; } catch (e) {}
    }
    // Permisos del agente: cuánto hace sin preguntarte (~/.config/ia/permisos.json)
    property string permisos: "equilibrado"
    readonly property var niveles: [
        { id: "cauteloso",   nombre: "Cauteloso",   color: Paleta.exito,   resumen: "Te pregunta antes de cambiar nada",
          detalle: "Solo consulta y abre por su cuenta. Cualquier comando, archivo o ajuste espera tu «sí»." },
        { id: "equilibrado", nombre: "Equilibrado", color: Paleta.acento2,    resumen: "Consultas y tus archivos, sin preguntar",
          detalle: "Comandos de solo lectura y escribir en tus carpetas personales. Lo demás lo confirma." },
        { id: "amplio",      nombre: "Amplio",      color: Paleta.acento, resumen: "Casi todo el día a día, sin preguntar",
          detalle: "Ventanas, apps, ajustes, comandos y archivos. Pregunta antes de borrar, apagar, ejecutar scripts, tocar configuración o enviar algo. Si leyó una web, vuelve a preguntar." },
        { id: "total",       nombre: "Total",       color: Paleta.peligro,    resumen: "Todo sin preguntar, salvo administrador",
          detalle: "Cualquier comando y archivo, también borrar. Riesgo: una web maliciosa o un error del modelo pueden hacer daño. Úsalo solo cuando lo necesites." }
    ]
    function nivelDe(id) { return niveles.find(n => n.id === id) || niveles[1]; }
    function elegir(campo, valor) {
        if (proceso.running) return;
        if (campo === "modelo") modeloElegido = valor; else esfuerzo = valor;   // respuesta inmediata
        pElegir.command = [scripts + "agente.py", "elegir", campo, valor]; pElegir.running = true;
    }
    property real calentadoEn: 0
    property bool escuchando: false
    property string pendienteTexto: ""    // lo que mandaste mientras el modelo despertaba
    property var historial: []            // [{id, titulo, actualizada, n}] más reciente primero
    property string idActual: ""
    readonly property bool privado: EstadoEscritorio.privacidad

    function g(hex) { return String.fromCodePoint(parseInt(hex, 16)); }
    function agregar(m) { mensajes = [...mensajes, m]; Qt.callLater(() => lista.positionViewAtEnd()); }
    function ultimo() { return mensajes[mensajes.length - 1]; }
    function reemplazarUltimo(m) { const seguir = lista.contentY + lista.height >= lista.contentHeight - 80; const c = mensajes.slice(); c[c.length - 1] = m; mensajes = c; if (seguir) Qt.callLater(() => lista.positionViewAtEnd()); }

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
    // Borrar todo: el primer clic pide confirmación (el botón se pone rojo 4 s); el segundo borra
    property bool confirmandoBorrado: false
    function borrarTodo() {
        if (proceso.running || !historial.length) return;
        if (!confirmandoBorrado) { confirmandoBorrado = true; tiempoBorrado.restart(); return; }
        confirmandoBorrado = false;
        mensajes = []; idActual = ""; historial = [];             // respuesta inmediata
        pOrden.command = [scripts + "agente.py", "borrar-todo"]; pOrden.running = true;
    }
    Timer { id: tiempoBorrado; interval: 4000; onTriggered: ag.confirmandoBorrado = false }
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
        diagnostico.running = true;
        pOpciones.running = true;
        Qt.callLater(() => entrada.forceActiveFocus());
        refrescarHistorial();
        if (mensajes.length === 0 && !proceso.running) { pCargar.command = [scripts + "agente.py", "actual"]; pCargar.running = true; }
        if (Date.now() - calentadoEn > 15 * 60 * 1000 && !calentador.running) { listo = false; calentador.running = true; }
    }

    // ── procesos ─────────────────────────────────────────────────────────
    Process {
        id: diagnostico
        command: [ag.scripts + "agente.py", "diagnostico"]
        stdout: StdioCollector { onStreamFinished: { try { const d = JSON.parse(text); ag.navegadorListo = d.navegador; ag.nube = d.nube || ""; } catch (e) {} } }
    }
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
        id: pOpciones
        command: [ag.scripts + "agente.py", "opciones"]
        stdout: StdioCollector { onStreamFinished: ag.leerOpciones(text) }
    }
    Process {
        id: pElegir
        stdout: StdioCollector { onStreamFinished: ag.leerOpciones(text) }
        onExited: {
            diagnostico.running = true;   // actualiza el subtítulo («Nube (…)» o «Modelo local»)
            if (ag.modeloElegido === "local" && !calentador.running) { ag.listo = false; calentador.running = true; }
        }
    }
    Process {
        id: pMostrar
        command: ["python3", ag.scripts + "agente_navegador.py", "mostrar"]
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

    Shortcut { sequence: "Ctrl+L"; enabled: ag.abierto; onActivated: ag.nuevaConversacion() }
    Shortcut { sequence: "Ctrl+Up"; enabled: ag.abierto; onActivated: ag.moverConversacion(-1) }
    Shortcut { sequence: "Ctrl+Down"; enabled: ag.abierto; onActivated: ag.moverConversacion(1) }
    Shortcut { sequence: "Ctrl+Space"; enabled: ag.abierto; onActivated: ag.alternarMicro() }
    Shortcut { sequence: "S"; enabled: ag.abierto && ag.hayConfirmacion && !entrada.activeFocus && !proceso.running; onActivated: ag.responder(true) }
    Shortcut { sequence: "N"; enabled: ag.abierto && ag.hayConfirmacion && !entrada.activeFocus && !proceso.running; onActivated: ag.responder(false) }

    ColumnLayout {
        width: parent.width; spacing: 12

        // ── cabecera: nombre y estado · ajustes · cerrar ────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Rectangle {
                implicitWidth: 40; implicitHeight: 40; radius: height / 2
                color: Qt.alpha(Paleta.acento, .22)
                border { width: 1; color: Qt.alpha(Paleta.acento, .5) }
                Text { anchors.centerIn: parent; text: "✦"; color: Paleta.texto; font { pixelSize: 16 }
                    RotationAnimation on rotation { running: ag.pensando || calentador.running; loops: Animation.Infinite; from: 0; to: 360; duration: 2400 } }
                // halo mientras piensa
                Rectangle {
                    anchors.centerIn: parent; width: parent.width + 10; height: width; radius: width / 2; color: "transparent"
                    border { width: 2; color: Qt.alpha(Paleta.acento, .6) }
                    visible: ag.pensando || calentador.running
                    SequentialAnimation on opacity { running: ag.pensando || calentador.running; loops: Animation.Infinite
                        NumberAnimation { to: .15; duration: 700 } NumberAnimation { to: .8; duration: 700 } }
                }
            }
            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true; Layout.minimumWidth: 0
                Text { text: "Agente"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20; bold: true } }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
                    text: calentador.running ? "Despertando al asistente… la primera vez tarda alrededor de un minuto"
                        : ag.pensando ? "Pensando…" : ag.escuchando ? "Escuchando… pulsa el micrófono para terminar"
                        : ag.privado && ag.modeloElegido !== "local" ? "Modelo local · la privacidad activa apaga la nube"
                        : ag.tituloModelo(ag.modeloElegido) + (ag.modeloElegido !== "local" ? " · esfuerzo " + ({ bajo: "rápido", medio: "medio", alto: "a fondo" })[ag.esfuerzo] : "")
                }
            }
            // Ajustes: modelo, esfuerzo y navegador, en un desplegable
            BotonCompacto {
                id: botonAjustes
                text: ag.g("f0493") + "  Ajustes"
                destacado: panelAjustes.visible
                onClicked: panelAjustes.visible ? panelAjustes.close() : panelAjustes.open()
                Popup {
                    id: panelAjustes
                    y: botonAjustes.height + 8
                    x: botonAjustes.width - width
                    width: 360
                    padding: 16
                    background: Rectangle { radius: 16; color: EstiloPanel.elevada; border { width: 1; color: EstiloPanel.bordeFuerte } }
                    contentItem: ColumnLayout {
                        spacing: 8
                        Etiqueta { text: "MODELO" }
                        // ── modelo y esfuerzo ──
                        ComboBox {
                            id: selModelo
                            Layout.fillWidth: true; implicitHeight: 36
                            enabled: !ag.pensando
                            opacity: enabled ? 1 : .5
                            model: ag.modelos
                            currentIndex: ag.modelos.indexOf(ag.modeloElegido)
                            onActivated: (i) => ag.elegir("modelo", ag.modelos[i])
                            background: Rectangle {
                                radius: 16
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.alpha(Paleta.acento, selModelo.hovered || selModelo.popup.visible ? .22 : .14) }
                                    GradientStop { position: 1; color: Qt.alpha(Paleta.acento, .04) }
                                }
                                border { width: selModelo.activeFocus || selModelo.popup.visible ? 2 : 1; color: Qt.alpha(Paleta.acento, selModelo.popup.visible ? .7 : .4) }
                            }
                            contentItem: RowLayout {
                                spacing: 8
                                Text { Layout.leftMargin: 13; text: ag.modeloElegido === "local" ? ag.g("f0322") : ag.modeloElegido === "auto" ? "✦" : ag.g("f06a9"); color: Paleta.acento; font { family: Paleta.mono; pixelSize: 14 } }
                                Text { Layout.fillWidth: true; Layout.rightMargin: 26; text: ag.tituloModelo(ag.modeloElegido); elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold } }
                            }
                            indicator: Text {
                                x: selModelo.width - width - 13; anchors.verticalCenter: parent.verticalCenter
                                text: selModelo.popup.visible ? "▴" : "▾"; color: Paleta.acento
                                font { family: Paleta.fuente; pixelSize: 13 }
                            }
                            popup: Popup {
                                y: selModelo.height + 6
                                width: 300
                                padding: 4
                                implicitHeight: Math.min(listaModelos.contentHeight + 12, 420)   // con muchos modelos, se desplaza
                                background: Rectangle { radius: 16; color: EstiloPanel.elevada; border { width: 1; color: Qt.alpha(Paleta.acento, .3) } }
                                contentItem: ListView {
                                    id: listaModelos
                                    implicitHeight: contentHeight
                                    spacing: 2
                                    interactive: contentHeight > height   // Gemini ofrece muchos modelos
                                    clip: true
                                    model: selModelo.popup.visible ? selModelo.delegateModel : null
                                    currentIndex: selModelo.highlightedIndex
                                }
                            }
                            delegate: ItemDelegate {
                                id: opcionModelo
                                required property var modelData
                                required property int index
                                readonly property bool elegido: modelData === ag.modeloElegido
                                // primer modelo de cada proveedor: lleva encima su cabecera (GOOGLE, GROQ…)
                                readonly property string grupo: ag.proveedorDe(modelData)
                                readonly property color tinte: ag.colorGrupo(grupo)
                                readonly property bool cabecera: grupo !== "" && (index === 0 || grupo !== ag.proveedorDe(ag.modelos[index - 1]))
                                readonly property int altoCabecera: cabecera ? 28 : 0
                                width: 288
                                padding: 8
                                topPadding: 8 + altoCabecera
                                highlighted: selModelo.highlightedIndex === index
                                background: Item {
                                    RowLayout {
                                        visible: opcionModelo.cabecera
                                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; leftMargin: 8; rightMargin: 8 }
                                        spacing: 8
                                        Rectangle { implicitWidth: 6; implicitHeight: 6; radius: height / 2; color: opcionModelo.tinte }
                                        Text { text: opcionModelo.grupo.toUpperCase(); color: opcionModelo.tinte; font { family: Paleta.fuente; pixelSize: 11; weight: Font.Bold; letterSpacing: 1.4 } }
                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Qt.alpha(opcionModelo.tinte, .3) }
                                    }
                                    Rectangle {
                                        anchors { fill: parent; topMargin: opcionModelo.altoCabecera }
                                        radius: 12
                                        color: Qt.alpha(Paleta.acento, opcionModelo.elegido ? .2 : opcionModelo.highlighted ? .1 : 0)
                                        border { width: opcionModelo.elegido ? 1 : 0; color: Qt.alpha(Paleta.acento, .45) }
                                    }
                                }
                                contentItem: RowLayout {
                                    spacing: 12
                                    Text { text: opcionModelo.modelData === "local" ? ag.g("f0322") : opcionModelo.modelData === "auto" ? "✦" : ag.g("f06a9"); color: opcionModelo.elegido ? Paleta.acento : opcionModelo.grupo && opcionModelo.grupo !== "Este equipo" ? opcionModelo.tinte : EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 16 } }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: ag.tituloModelo(opcionModelo.modelData); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold } }
                                        Text { Layout.fillWidth: true; visible: text !== ""; text: ag.notaModelo(opcionModelo.modelData); elide: Text.ElideRight
                                            color: text.startsWith("Falló") ? Paleta.peligro : text.startsWith("Lento") || text.startsWith("Va con") ? Paleta.aviso : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                                    }
                                    Text { visible: opcionModelo.elegido; text: "✓"; color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                }
                            }
                            ToolTip.visible: hovered && !popup.visible; ToolTip.delay: 500
                            ToolTip.text: "Modelo del asistente, del que mejor responde al que peor (se prueban una vez al día). Si uno falla, se reintenta con la clave de respaldo y luego con los demás; en el chat verás cada cambio."
                        }
                        Etiqueta { text: "ESFUERZO"; Layout.topMargin: 4 }
                        // esfuerzo: control segmentado
                        Rectangle {
                            implicitWidth: filaEsfuerzo.implicitWidth + 6; implicitHeight: 36; radius: height / 2
                            opacity: ag.modeloElegido === "local" ? .45 : 1
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, .45) }
                                GradientStop { position: 1; color: EstiloPanel.relleno }
                            }
                            border { width: 1; color: EstiloPanel.borde }
                            Row {
                                id: filaEsfuerzo
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: [["bajo", "Rápido"], ["medio", "Medio"], ["alto", "A fondo"]]
                                    BotonCompacto {
                                        id: btEsfuerzo
                                        required property var modelData
                                        text: modelData[1]
                                        implicitHeight: 30; leftPadding: 12; rightPadding: 12
                                        acento: Paleta.acento
                                        destacado: ag.esfuerzo === modelData[0]
                                        enabled: !ag.pensando && ag.modeloElegido !== "local"
                                        onClicked: ag.elegir("esfuerzo", modelData[0])
                                        background: FondoBoton { visible: btEsfuerzo.destacado || btEsfuerzo.hovered; tinte: Paleta.acento; destacado: btEsfuerzo.destacado; encima: btEsfuerzo.hovered; pulsado: btEsfuerzo.down; foco: btEsfuerzo.activeFocus; radio: 15 }
                                        ToolTip.visible: hovered; ToolTip.delay: 500
                                        ToolTip.text: "Esfuerzo: cuánto razona antes de responder. «A fondo» es más listo pero más lento."
                                    }
                                }
                            }
                        }

                        Etiqueta { text: "NAVEGADOR"; Layout.topMargin: 4 }
                        BotonCompacto {
                            text: ag.navegadorListo ? "Navegador" : "Instalar navegador"
                            enabled: !ag.pensando
                            // con el navegador instalado, lo muestra directamente (el agente lo usa invisible)
                            onClicked: ag.navegadorListo ? pMostrar.running = true
                                                         : ag.enviar("Instala el navegador integrado con la acción instalar_navegador")
                        }

                    }
                }
            }
            BotonCompacto { text: "󰅖"; Accessible.name: "Cerrar"; implicitWidth: 38; implicitHeight: 38; leftPadding: 0; rightPadding: 0; onClicked: ag.abierto = false; background: FondoBoton { tinte: Paleta.peligro; encima: parent.hovered; foco: parent.activeFocus; radio: 19 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            // ── historial de conversaciones ──────────────────────────────
            Rectangle {
                id: lateral
                Layout.preferredWidth: 264
                Layout.fillHeight: true
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Qt.tint(Paleta.texto, Qt.alpha(Paleta.acento, .5)), .06) }
                    GradientStop { position: 1; color: EstiloPanel.relleno }
                }
                border { width: 1; color: EstiloPanel.borde }

                ColumnLayout {
                    anchors { fill: parent; margins: 8 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4; Layout.topMargin: 2
                        Text { text: "CONVERSACIONES"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 } }
                        Rectangle {
                            visible: ag.historial.length > 0
                            implicitWidth: Math.max(20, cuentaHist.implicitWidth + 12); implicitHeight: 18; radius: height / 2
                            color: Qt.alpha(Paleta.acento, .2)
                            Text { id: cuentaHist; anchors.centerIn: parent; text: ag.historial.length; color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                        }
                        Item { Layout.fillWidth: true }
                        // Borrar todas las conversaciones (doble clic de seguridad)
                        Rectangle {
                            visible: ag.historial.length > 0
                            implicitWidth: ag.confirmandoBorrado ? textoBorrarTodo.implicitWidth + 20 : 26; implicitHeight: 26; radius: height / 2
                            color: ag.confirmandoBorrado ? Qt.alpha(Paleta.peligro, .3) : zonaBorrarTodo.containsMouse ? Qt.alpha(Paleta.peligro, .2) : EstiloPanel.rellenoActivo
                            Behavior on implicitWidth { NumberAnimation { duration: EstiloPanel.rapido } }
                            Text {
                                id: textoBorrarTodo
                                anchors.centerIn: parent
                                text: ag.confirmandoBorrado ? "¿Borrar todo?" : ag.g("f0a7a")
                                color: ag.confirmandoBorrado || zonaBorrarTodo.containsMouse ? Paleta.peligro : Paleta.gris
                                font { family: Paleta.fuente; pixelSize: ag.confirmandoBorrado ? 11 : 13; bold: ag.confirmandoBorrado }
                            }
                            MouseArea { id: zonaBorrarTodo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.borrarTodo() }
                            ToolTip.visible: zonaBorrarTodo.containsMouse && !ag.confirmandoBorrado; ToolTip.delay: 400; ToolTip.text: "Borrar todas las conversaciones"
                        }
                    }
                    BotonCompacto {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        text: ag.g("f0415") + "  Nueva conversación   ⌃L"
                        acento: Paleta.acento
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
                                color: EstiloPanel.apagado
                                font { family: Paleta.fuente; pixelSize: 11; bold: true }
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 50; radius: 12
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: conv.actual ? Qt.alpha(Paleta.acento, .26) : Qt.alpha(Paleta.texto, zonaConv.containsMouse ? .07 : 0) }
                                    GradientStop { position: 1; color: conv.actual ? Qt.alpha(Paleta.acento, .07) : Qt.alpha(Paleta.texto, zonaConv.containsMouse ? .03 : 0) }
                                }
                                border { width: conv.actual ? 1 : 0; color: Qt.alpha(Paleta.acento, .4) }
                                Rectangle {
                                    visible: conv.actual
                                    width: 3; height: parent.height - 20; radius: 4
                                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                    color: Paleta.acento
                                }
                                ColumnLayout {
                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: borrarConv.visible ? 36 : 10 }
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        text: ag.privado ? ag.g("f033e") + "  Conversación" : conv.modelData.titulo
                                        elide: Text.ElideRight
                                        color: conv.actual ? Paleta.texto : EstiloPanel.secundario
                                        font { family: Paleta.fuente; pixelSize: 12; bold: conv.actual }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: ag.cuandoFue(conv.modelData.actualizada) + " · " + conv.modelData.n + (conv.modelData.n === 1 ? " mensaje" : " mensajes")
                                        elide: Text.ElideRight
                                        color: Paleta.gris
                                        font { family: Paleta.fuente; pixelSize: 11 }
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
                                    width: 26; height: 26; radius: height / 2
                                    color: zonaBorrarConv.containsMouse ? Qt.alpha(Paleta.peligro, .25) : EstiloPanel.rellenoActivo
                                    Text { anchors.centerIn: parent; text: ag.g("f0a7a"); color: zonaBorrarConv.containsMouse ? Paleta.peligro : Paleta.gris; font { family: Paleta.fuente; pixelSize: 13 } }
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
                            spacing: 4
                            Text { Layout.alignment: Qt.AlignHCenter; text: ag.g("f0b79"); color: Qt.alpha(Paleta.acento, .6); font { family: Paleta.fuente; pixelSize: 26 } }
                            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Aquí aparecerán tus conversaciones para retomarlas cuando quieras"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        visible: ag.historial.length > 1
                        text: "⌃↑ ⌃↓ moverse entre ellas"
                        color: Qt.alpha(Paleta.gris, .8)
                        font { family: Paleta.fuente; pixelSize: 11 }
                    }

                    // ── permisos del agente ──
                    Text { Layout.topMargin: 6; text: "PERMISOS"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 } }
                    ComboBox {
                        id: selPermisos
                        readonly property var actual: ag.nivelDe(ag.permisos)
                        Layout.fillWidth: true
                        implicitHeight: 56
                        enabled: !ag.pensando
                        model: ag.niveles
                        currentIndex: ag.niveles.findIndex(n => n.id === ag.permisos)
                        onActivated: (i) => ag.elegir("permisos", ag.niveles[i].id)
                        background: Rectangle {
                            radius: 16
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.alpha(selPermisos.actual.color, selPermisos.hovered ? .22 : .15) }
                                GradientStop { position: 1; color: Qt.alpha(selPermisos.actual.color, .04) }
                            }
                            border { width: selPermisos.activeFocus || selPermisos.popup.visible ? 2 : 1; color: Qt.alpha(selPermisos.actual.color, .55) }
                            Behavior on border.color { ColorAnimation { duration: EstiloPanel.normal } }
                        }
                        contentItem: RowLayout {
                            spacing: 8
                            Rectangle {   // piloto del nivel
                                Layout.leftMargin: 12
                                implicitWidth: 10; implicitHeight: 10; radius: height / 2
                                color: selPermisos.actual.color
                                Rectangle { anchors.centerIn: parent; width: 18; height: 18; radius: height / 2; color: "transparent"; border { width: 2; color: Qt.alpha(selPermisos.actual.color, .3) } }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: selPermisos.actual.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                Text { Layout.fillWidth: true; text: selPermisos.actual.resumen; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                            }
                        }
                        indicator: Text {
                            x: selPermisos.width - width - 14; anchors.verticalCenter: parent.verticalCenter
                            text: selPermisos.popup.visible ? "▴" : "▾"; color: selPermisos.actual.color
                            font { family: Paleta.fuente; pixelSize: 14 }
                        }
                        popup: Popup {
                            y: -implicitHeight - 6   // se abre hacia arriba: está al pie del panel
                            width: selPermisos.width + 170
                            padding: 4
                            implicitHeight: listaNiveles.contentHeight + 12
                            background: Rectangle { radius: 16; color: EstiloPanel.elevada; border { width: 1; color: EstiloPanel.bordeFuerte } }
                            contentItem: ListView {
                                id: listaNiveles
                                implicitHeight: contentHeight
                                spacing: 4
                                interactive: false
                                model: selPermisos.popup.visible ? selPermisos.delegateModel : null
                                currentIndex: selPermisos.highlightedIndex
                            }
                        }
                        delegate: ItemDelegate {
                            id: opcionNivel
                            required property var modelData
                            required property int index
                            readonly property bool elegido: modelData.id === ag.permisos
                            width: selPermisos.width + 158
                            padding: 8
                            highlighted: selPermisos.highlightedIndex === index
                            background: Rectangle {
                                radius: 12
                                color: Qt.alpha(opcionNivel.modelData.color, opcionNivel.elegido ? .2 : opcionNivel.highlighted ? .12 : 0)
                                border { width: opcionNivel.elegido ? 1 : 0; color: Qt.alpha(opcionNivel.modelData.color, .5) }
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                Rectangle { Layout.alignment: Qt.AlignTop; Layout.topMargin: 4; implicitWidth: 10; implicitHeight: 10; radius: height / 2; color: opcionNivel.modelData.color }
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: opcionNivel.modelData.nombre; color: opcionNivel.modelData.color; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight; text: "· " + opcionNivel.modelData.resumen; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
                                        Text { visible: opcionNivel.elegido; text: "✓"; color: opcionNivel.modelData.color; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                    }
                                    Text { Layout.fillWidth: true; text: opcionNivel.modelData.detalle; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true; Layout.leftMargin: 4
                        text: "Lo de administrador (sudo, pacman) siempre te lo pregunta."
                        wrapMode: Text.Wrap; color: Qt.alpha(Paleta.gris, .8); font { family: Paleta.fuente; pixelSize: 11 }
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
                        anchors.fill: parent; clip: true; spacing: 8
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
                            NumberAnimation { id: entra; target: msj; property: "opacity"; to: 1; duration: EstiloPanel.normal }

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
                        anchors.centerIn: parent; width: parent.width - 60; spacing: 12
                        visible: ag.mensajes.length === 0
                        Rectangle {   // emblema
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 64; implicitHeight: 64; radius: height / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(Paleta.acento, .32) }
                                GradientStop { position: 1; color: Qt.alpha(Paleta.acento2, .1) }
                            }
                            border { width: 1; color: Qt.alpha(Paleta.acento, .4) }
                            RectangularShadow { anchors.fill: parent; z: -1; visible: EstiloPanel.efectos; radius: height / 2; blur: 40; spread: -6; color: Qt.alpha(Paleta.acento, .35) }
                            Text { anchors.centerIn: parent; text: "✦"; color: Qt.lighter(Paleta.acento, 1.2); font.pixelSize: 26 }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Pregúntame o pídeme algo, como se lo dirías a alguien"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 14 } }
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: ["¿Qué tengo mañana?", "¿Qué estuve leyendo sobre el método de dos fases?", "Prepárame para estudiar",
                                        "¿Cómo está el equipo?", "¿Qué hice ayer por la tarde?", "Ponme concentración de 50 minutos",
                                        "¿Tengo mensajes en el móvil?", "Busca mis apuntes de redes"]
                                Rectangle {
                                    required property string modelData
                                    implicitHeight: 36; implicitWidth: sug.implicitWidth + 30; radius: height / 2
                                    color: Qt.alpha(Paleta.acento, zs.containsMouse ? .2 : .07); border { width: 1; color: Qt.alpha(Paleta.acento, zs.containsMouse ? .5 : .22) }
                                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                    Text { id: sug; anchors.centerIn: parent; text: parent.modelData; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13 } }
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
                        Layout.fillWidth: true; implicitHeight: 50; radius: height / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, entrada.activeFocus ? .6 : .45) }
                            GradientStop { position: 1; color: Qt.alpha(Paleta.texto, entrada.activeFocus ? .07 : .045) }
                        }
                        border { width: entrada.activeFocus ? 1.5 : 1; color: Qt.alpha(Paleta.acento, entrada.activeFocus ? .7 : .18) }
                        Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
                        RectangularShadow {   // brillo al escribir
                            anchors.fill: parent; z: -1
                            visible: EstiloPanel.efectos
                            opacity: entrada.activeFocus ? 1 : 0
                            radius: 24; blur: 22; spread: -4
                            color: Qt.alpha(Paleta.acento, .32)
                            Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
                        }
                        TextField {
                            id: entrada
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            placeholderText: ag.hayConfirmacion ? "Responde arriba (S / N) o escribe otra cosa…" : "Escribe aquí… (Enter para enviar)"
                            color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14 }
                            placeholderTextColor: EstiloPanel.apagado
                            selectionColor: Qt.alpha(Paleta.acento, .4)
                            background: null
                            Keys.onReturnPressed: ag.enviar(text)
                            Keys.onEnterPressed: ag.enviar(text)
                        }
                    }
                    Rectangle {
                        implicitWidth: 50; implicitHeight: 50; radius: height / 2
                        color: ag.escuchando ? Qt.alpha(Paleta.peligro, .35) : Qt.alpha(Paleta.texto, zm.containsMouse ? .1 : .05)
                        border { width: 1; color: Qt.alpha(ag.escuchando ? Paleta.peligro : Paleta.acento, .4) }
                        Text { anchors.centerIn: parent; text: ag.g(ag.escuchando ? "f036d" : "f036c"); color: ag.escuchando ? Paleta.peligro : Paleta.texto; font { family: Paleta.fuente; pixelSize: 16 } }
                        SequentialAnimation on scale { running: ag.escuchando; loops: Animation.Infinite; NumberAnimation { to: 1.08; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
                        MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ag.alternarMicro() }
                    }
                    Rectangle {
                        id: enviarBtn
                        readonly property bool listo: entrada.text.trim() !== "" && !ag.pensando
                        implicitWidth: 50; implicitHeight: 50; radius: height / 2
                        scale: ze.pressed ? .94 : 1
                        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
                        gradient: Gradient {
                            GradientStop { position: 0; color: enviarBtn.listo ? Qt.lighter(Paleta.acento, ze.containsMouse ? 1.1 : 1) : EstiloPanel.rellenoActivo }
                            GradientStop { position: 1; color: enviarBtn.listo ? Qt.tint(Paleta.acento, Qt.alpha(Paleta.acento2, .45)) : EstiloPanel.relleno }
                        }
                        border { width: 1; color: Qt.alpha(enviarBtn.listo ? "white" : Paleta.texto, enviarBtn.listo ? .25 : .1) }
                        RectangularShadow {
                            anchors.fill: parent; z: -1
                            visible: EstiloPanel.efectos && enviarBtn.listo
                            radius: 24; offset.y: 4; blur: 18; spread: -4
                            color: Qt.alpha(Paleta.acento, .55)
                        }
                        Text { anchors.centerIn: parent; text: ag.g("f048a"); color: enviarBtn.listo ? Paleta.fondo : EstiloPanel.apagado; font { family: Paleta.fuente; pixelSize: 20 } }
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
                width: parent.width * .78; implicitHeight: tt.implicitHeight + 24
                radius: 16; bottomRightRadius: 6   // «cola» hacia el lado de quien habla
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Paleta.acento, .24) }
                    GradientStop { position: 1; color: Qt.alpha(Qt.tint(Paleta.acento, Qt.alpha(Paleta.acento, .35)), .16) }
                }
                border { width: 1; color: Qt.alpha(Qt.lighter(Paleta.acento, 1.2), .32) }
                MensajeAgente {
                    id: tt
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    texto: parent.parent.parent.m.texto
                    onEnlace: (url) => Qt.openUrlExternally(url)
                }
            }
        }
    }
    Component {
        id: burbujaAsistente
        RowLayout {
            spacing: 12
            Rectangle {   // avatar del asistente
                Layout.alignment: Qt.AlignTop
                implicitWidth: 28; implicitHeight: 28; radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Paleta.acento, .38) }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.acento2, .16) }
                }
                border { width: 1; color: Qt.alpha(Paleta.acento, .45) }
                Text { anchors.centerIn: parent; text: "✦"; color: Qt.lighter(Paleta.acento, 1.15); font.pixelSize: 13 }
            }
            MensajeAgente {
                Layout.fillWidth: true; Layout.topMargin: 3
                texto: parent.parent.m.texto
                terminado: !ag.pensando || !!parent.parent.m.cerrado
                onEnlace: (url) => Qt.openUrlExternally(url)
            }
        }
    }
    Component {
        id: paso
        Item {
            id: raizPaso
            readonly property string texto: parent?.m?.texto ?? ""
            implicitHeight: 28
            TextMetrics { id: medidaPaso; text: raizPaso.texto; font { family: Paleta.fuente; pixelSize: 11 } }
            Rectangle {   // pastilla discreta: qué está haciendo (ancho = el del texto, medido aparte)
                x: 40
                width: Math.min(parent.width - 40, medidaPaso.advanceWidth + 6 + 8 + 24 + 4); height: 26; radius: height / 2
                color: Qt.alpha(Paleta.acento2, .07); border { width: 1; color: Qt.alpha(Paleta.acento2, .16) }
                RowLayout {
                    id: filaPaso
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 8
                    Rectangle { implicitWidth: 6; implicitHeight: 6; radius: height / 2; color: Paleta.acento2 }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: raizPaso.texto; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                }
            }
        }
    }
    Component {
        id: fuentes
        Flow {
            spacing: 4; leftPadding: 40
            Repeater {
                model: parent.parent.m.lista ?? []
                Rectangle {
                    id: fu
                    required property var modelData
                    required property int index
                    implicitHeight: 26; implicitWidth: Math.min(300, ft.implicitWidth + 20); radius: height / 2
                    color: Qt.alpha(Paleta.acento2, zf.containsMouse ? .2 : .08); border { width: 1; color: Qt.alpha(Paleta.acento2, .3) }
                    Text { id: ft; anchors { fill: parent; leftMargin: 8; rightMargin: 8 } verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                        text: `[${fu.index + 1}] ` + ag.g(({ documento: "f0219", web: "f059f", linea: "f0954" })[fu.modelData.tipo] ?? "f0219") + " " + fu.modelData.titulo
                        color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
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
            implicitHeight: cc.implicitHeight + 24; radius: 16
            color: Qt.alpha(m.resuelto === "no" ? Paleta.gris : Paleta.exito, .08)
            border { width: 1; color: Qt.alpha(m.resuelto === "no" ? Paleta.gris : Paleta.exito, m.resuelto ? .2 : .55) }
            RowLayout {
                id: cc
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 } spacing: 12
                Text { text: ag.g(parent.parent.m.resuelto === "si" ? "f012c" : parent.parent.m.resuelto === "no" ? "f0156" : "f02d7"); color: parent.parent.m.resuelto === "no" ? Paleta.gris : Paleta.exito; font { family: Paleta.fuente; pixelSize: 20 } }
                ColumnLayout { Layout.fillWidth: true; spacing: 1
                    Text { text: parent.parent.parent.m.resuelto === "si" ? "HECHO" : parent.parent.parent.m.resuelto === "no" ? "NO SE HIZO" : "¿LO HAGO?"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 } }
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: parent.parent.parent.m.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                }
                BotonCompacto { visible: !parent.parent.m.resuelto; text: "Sí, hazlo  S"; destacado: true; acento: Paleta.exito; enabled: !proceso.running; onClicked: ag.responder(true) }
                BotonCompacto { visible: !parent.parent.m.resuelto; text: "No  N"; acento: Paleta.gris; enabled: !proceso.running; onClicked: ag.responder(false) }
            }
        }
    }
    Component {
        id: error
        Text { wrapMode: Text.Wrap; leftPadding: 40; text: "⚠ " + parent.m.texto; color: Paleta.peligro; font { family: Paleta.fuente; pixelSize: 12 } }
    }
}
