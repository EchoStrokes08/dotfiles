// Brújula (SUPER+CTRL+B): el escritorio que se anticipa. Cuatro pestañas:
//   Hoy        saludo, frase del asistente local y sugerencias de un clic (scripts/sugerencias.py)
//   Línea      qué tuviste delante y cuándo: cinta del día, resumen y bloques (scripts/brujula.py linea)
//   Contexto   reglas automáticas (~/.config/hypr/brujula.json): cuáles están activas, pausar, activar/desactivar
//   Sesión     la sesión anterior (tras reiniciar o un cuelgue) para reabrirla entera o en parte
//   qs ipc call brujula abrir hoy|linea|contexto|sesion · qs ipc call brujula dia 2026-11-10
// Teclas: Ctrl+1…4 o Ctrl+Tab cambian de pestaña · ←/→ cambian de día en la línea · Esc cierra.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Superpuesta {
    id: br
    espacio: "brujula"
    anchoTarjeta: Math.min(980, (screen?.width ?? 1280) - 40)
    alturaRelativa: 0.05
    opacidadTarjeta: 0.96

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    readonly property var paginas: ["hoy", "linea", "contexto", "sesion"]
    property int pagina: 0
    property var hoy: null
    property string frase: ""
    property bool fraseCargando: false
    property var linea: null
    property string dia: ""
    property var estado: null
    property var sesion: null
    property var elegidas: ({})
    property string aviso: ""
    property string filtro: ""

    function abrir(nombre) { pagina = Math.max(0, paginas.indexOf(nombre)); abierto = true; cargar(); }
    function abrirDia(d) { dia = d; pagina = 1; abierto = true; cargar(); }
    function cargar() {
        if (pagina === 0) { correr(pHoy, [scripts + "sugerencias.py"]); if (!frase && !pFrase.running) { fraseCargando = true; pFrase.running = true; } }
        if (pagina === 1) correr(pLinea, [scripts + "brujula.py", "linea"].concat(dia ? ["--dia", dia] : []));
        if (pagina === 2) correr(pEstado, [scripts + "brujula.py", "estado"]);
        if (pagina === 3) correr(pSesion, [scripts + "brujula.py", "sesion"]);
    }
    function correr(p, cmd) { if (p.running) return; p.command = cmd; p.running = true; }
    function orden(args, despues) {
        if (pOrden.running) return;
        pOrden.despues = despues || "";
        pOrden.command = [scripts + "brujula.py", ...args]; pOrden.running = true;
    }
    function lanzar(cmd) { if (cmd && cmd.length) Quickshell.execDetached(cmd); }

    // ── formato ──────────────────────────────────────────────────────────
    function g(hex) { return String.fromCodePoint(parseInt(hex, 16)); }
    function hora(t) { const d = new Date(t * 1000); return d.getHours().toString().padStart(2, "0") + ":" + d.getMinutes().toString().padStart(2, "0"); }
    function dur(s) { s = Math.round(s); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? `${h} h ${m.toString().padStart(2, "0")} min` : m ? `${m} min` : `${s} s`; }
    function hace(t) { const s = Date.now() / 1000 - t; return s < 90 ? "hace un momento" : s < 3600 ? `hace ${Math.round(s / 60)} min` : s < 86400 ? `hace ${Math.round(s / 3600)} h` : `hace ${Math.round(s / 86400)} días`; }
    readonly property var nombresDia: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var nombresMes: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    function fechaBonita(iso) {
        if (!iso) return "";
        const d = new Date(iso + "T12:00:00"), hoyD = new Date(); hoyD.setHours(12, 0, 0, 0);
        const dif = Math.round((hoyD - d) / 86400000);
        const base = `${nombresDia[d.getDay()]} ${d.getDate()} ${nombresMes[d.getMonth()]}`;
        return dif === 0 ? "Hoy · " + base : dif === 1 ? "Ayer · " + base : base.charAt(0).toUpperCase() + base.slice(1);
    }
    function moverDia(paso) {
        const base = new Date((linea?.dia || new Date().toISOString().slice(0, 10)) + "T12:00:00");
        base.setDate(base.getDate() + paso);
        const hoyD = new Date(); if (base > hoyD) return;
        dia = `${base.getFullYear()}-${String(base.getMonth() + 1).padStart(2, "0")}-${String(base.getDate()).padStart(2, "0")}`;
        cargar();
    }
    readonly property var tonos: [Paleta.naranja, Paleta.azul, Paleta.verde, Paleta.amarillo, Paleta.morado, "#95e6cb", "#f07178", "#ffb454"]
    function colorDe(clase) { let h = 0; for (const c of (clase || "")) h = (h * 31 + c.codePointAt(0)) >>> 0; return tonos[h % tonos.length]; }
    function html(t) { return String(t ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function tono(nombre) { return ({ naranja: Paleta.naranja, azul: Paleta.azul, verde: Paleta.verde, amarillo: Paleta.amarillo, rojo: Paleta.rojo, morado: Paleta.morado })[nombre] || Paleta.naranja; }

    onAbriendose: { aviso = ""; Qt.callLater(() => pestanas.forceActiveFocus()); }
    // las capturas descifradas solo existen mientras el panel está abierto
    onAbiertoChanged: if (!abierto && (linea?.capturas?.length ?? 0) > 0) Quickshell.execDetached([scripts + "brujula.py", "capturas", "limpiar"])
    onPaginaChanged: { aviso = ""; if (abierto) cargar(); }
    Timer { interval: 5000; repeat: true; running: br.abierto && (br.pagina === 2 || (br.pagina === 1 && !br.dia)); onTriggered: br.cargar() }

    // ── procesos ─────────────────────────────────────────────────────────
    component Lector: Process {
        id: lp
        property var alLeer: null
        stdout: StdioCollector { onStreamFinished: { try { if (text.trim()) lp.alLeer(JSON.parse(text)); } catch (e) { br.aviso = "No se pudo leer la respuesta."; } } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) { try { br.aviso = JSON.parse(text).error; } catch (e) { br.aviso = text.trim().split("\n").pop(); } } } }
    }
    Lector { id: pHoy; alLeer: function(d) { br.hoy = d; } }
    Lector { id: pFrase; command: [br.scripts + "sugerencias.py", "frase"]; alLeer: function(d) { br.frase = d.frase; br.fraseCargando = false; } onExited: br.fraseCargando = false }
    Lector { id: pLinea; alLeer: function(d) { br.linea = d; } }
    Lector { id: pEstado; alLeer: function(d) { br.estado = d; } }
    Lector { id: pSesion; alLeer: function(d) { br.sesion = d; const e = {}; (d.anterior?.apps || []).forEach((a, i) => e[i] = !a.abierta); br.elegidas = e; } }
    Lector {
        id: pOrden
        property string despues: ""
        alLeer: function(d) { br.aviso = d.mensaje || ""; if (pOrden.despues === "cerrar") br.abierto = false; else br.cargar(); }
    }

    // ── piezas ───────────────────────────────────────────────────────────
    component Boton: Button {
        id: bt
        property bool destacado: false
        property color acento: Paleta.naranja
        implicitHeight: 34
        leftPadding: 14; rightPadding: 14
        background: Rectangle {
            radius: 9
            color: Qt.alpha(bt.acento, bt.destacado ? (bt.hovered ? .32 : .22) : (bt.hovered ? .14 : .06))
            border { width: 1; color: Qt.alpha(bt.acento, bt.activeFocus || bt.destacado ? .7 : .2) }
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        contentItem: Text { text: bt.text; color: bt.enabled ? Paleta.texto : Paleta.gris; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; font { family: Paleta.fuente; pixelSize: 12; bold: bt.destacado } }
    }
    component Interruptor: Rectangle {
        id: sw
        property bool activo: false
        property color acento: Paleta.verde
        signal alternado()
        implicitWidth: 40; implicitHeight: 22; radius: 11
        color: activo ? Qt.alpha(acento, .55) : Qt.alpha(Paleta.texto, .12)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 16; height: 16; radius: 8; y: 3
            x: sw.activo ? sw.width - width - 3 : 3
            color: sw.activo ? Paleta.texto : Paleta.gris
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.alternado() }
    }
    component Medalla: Rectangle {
        id: md
        property string glifo: "f03d8"
        property color acento: Paleta.naranja
        property real lado: 38
        implicitWidth: lado; implicitHeight: lado; radius: lado / 3.2
        color: Qt.alpha(acento, .16)
        border { width: 1; color: Qt.alpha(acento, .35) }
        Text { anchors.centerIn: parent; text: br.g(md.glifo); color: md.acento; font { family: Paleta.fuente; pixelSize: md.lado * .47 } }
    }
    component Etiqueta: Text { color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1.6 } }
    component Cifra: Rectangle {
        id: cf
        property string titulo: ""
        property string valor: ""
        property string glifo: "f0954"
        property color acento: Paleta.azul
        Layout.fillWidth: true; implicitHeight: 64; radius: 12
        color: Qt.alpha(Paleta.texto, .035)
        border { width: 1; color: Qt.alpha(Paleta.texto, .06) }
        RowLayout {
            anchors { fill: parent; margins: 12 } spacing: 12
            Medalla { glifo: cf.glifo; acento: cf.acento; lado: 36 }
            ColumnLayout { spacing: 2; Layout.fillWidth: true
                Etiqueta { text: cf.titulo.toUpperCase() }
                Text { text: cf.valor; color: Paleta.texto; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Paleta.fuente; pixelSize: 15; bold: true } }
            }
        }
    }
    component Icono: Item {
        id: ic
        property string nombre: ""
        property string clase: ""
        property real lado: 22
        implicitWidth: lado; implicitHeight: lado
        readonly property string ruta: nombre ? (nombre.startsWith("/") ? "file://" + nombre : Quickshell.iconPath(nombre, true)) : ""
        IconImage { anchors.fill: parent; visible: !!ic.ruta; source: ic.ruta; asynchronous: true }
        Rectangle {
            anchors.fill: parent; radius: ic.lado / 3.4; visible: !ic.ruta
            color: Qt.alpha(br.colorDe(ic.clase), .2)
            Text { anchors.centerIn: parent; text: (ic.clase || "?").replace(/^.*[.-]/, "").charAt(0).toUpperCase(); color: br.colorDe(ic.clase); font { family: Paleta.fuente; pixelSize: ic.lado * .5; bold: true } }
        }
    }

    // ── atajos de teclado del panel ──────────────────────────────────────
    Shortcut { sequences: ["Ctrl+Tab"]; enabled: br.abierto; onActivated: br.pagina = (br.pagina + 1) % 4 }
    Shortcut { sequences: ["Ctrl+Shift+Tab"]; enabled: br.abierto; onActivated: br.pagina = (br.pagina + 3) % 4 }
    Repeater { model: 4; Item { required property int index; Shortcut { sequence: "Ctrl+" + (index + 1); enabled: br.abierto; onActivated: br.pagina = index } } }
    Shortcut { sequence: "Left"; enabled: br.abierto && br.pagina === 1 && !buscarLinea.activeFocus; onActivated: br.moverDia(-1) }
    Shortcut { sequence: "Right"; enabled: br.abierto && br.pagina === 1 && !buscarLinea.activeFocus; onActivated: br.moverDia(1) }

    ColumnLayout {
        width: parent.width; spacing: 14

        // ── cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Rectangle {
                implicitWidth: 46; implicitHeight: 46; radius: 14
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Paleta.naranja, .35) }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.morado, .25) }
                }
                Text {
                    id: aguja
                    anchors.centerIn: parent; text: br.g("f018b"); color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 24 }
                    rotation: br.abierto ? 0 : -40
                    Behavior on rotation { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
                }
            }
            ColumnLayout {
                spacing: 1; Layout.fillWidth: true
                Etiqueta { text: "BRÚJULA"; color: Paleta.naranja }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 22; bold: true }
                    text: ["Tu día, de un vistazo", "Lo que tuviste delante", "El escritorio se adapta solo", "Sigue donde lo dejaste"][br.pagina]
                }
            }
            // contextos activos ahora mismo
            Repeater {
                model: (br.estado?.reglas || []).filter(r => r.activa)
                Rectangle {
                    id: chip
                    required property var modelData
                    implicitHeight: 28; implicitWidth: fila.implicitWidth + 20; radius: 14
                    color: Qt.alpha(Paleta.verde, .12); border { width: 1; color: Qt.alpha(Paleta.verde, .4) }
                    Row { id: fila; anchors.centerIn: parent; spacing: 6
                        Rectangle { width: 7; height: 7; radius: 4; color: Paleta.verde; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { loops: Animation.Infinite; running: br.abierto; NumberAnimation { to: .3; duration: 900 } NumberAnimation { to: 1; duration: 900 } } }
                        Text { text: br.g(chip.modelData.icono) + "  " + chip.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
                    }
                }
            }
            Boton { text: "Esc"; onClicked: br.abierto = false; implicitWidth: 52 }
        }

        // ── pestañas (con indicador que se desliza) ──────────────────────
        Item {
            id: pestanas
            Layout.fillWidth: true; implicitHeight: 40
            focus: true
            Keys.onTabPressed: br.pagina = (br.pagina + 1) % 4
            Rectangle { anchors.fill: parent; radius: 12; color: Qt.alpha(Paleta.texto, .04) }
            Rectangle {
                id: indicador
                y: 4; height: parent.height - 8; width: (parent.width - 8) / 4; radius: 9
                x: 4 + br.pagina * width
                color: Qt.alpha(Paleta.naranja, .2); border { width: 1; color: Qt.alpha(Paleta.naranja, .55) }
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
            Row {
                anchors { fill: parent; margins: 4 }
                Repeater {
                    model: [["f05a8", "Hoy"], ["f0954", "Línea de tiempo"], ["f0493", "Contexto"], ["f099b", "Sesión"]]
                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width / 4; height: parent.height
                        Text {
                            anchors.centerIn: parent
                            text: br.g(parent.modelData[0]) + "  " + parent.modelData[1] + "  " + "⌃" + (parent.index + 1)
                            color: br.pagina === parent.index ? Paleta.texto : Paleta.gris
                            font { family: Paleta.fuente; pixelSize: 12; bold: br.pagina === parent.index }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: br.pagina = parent.index }
                    }
                }
            }
        }

        // ── páginas ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: 486
            clip: true

            // ═══ HOY ═════════════════════════════════════════════════════
            Flickable {
                anchors.fill: parent
                visible: br.pagina === 0
                contentHeight: hoyCol.implicitHeight; clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: hoyCol; width: parent.width; spacing: 14
                    // saludo + frase del asistente
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: saludoCol.implicitHeight + 32; radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha(Paleta.naranja, .14) }
                            GradientStop { position: .6; color: Qt.alpha(Paleta.morado, .07) }
                            GradientStop { position: 1; color: Qt.alpha(Paleta.azul, .05) }
                        }
                        border { width: 1; color: Qt.alpha(Paleta.naranja, .22) }
                        ColumnLayout {
                            id: saludoCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 } spacing: 8
                            RowLayout {
                                Text { text: br.hoy?.saludo ?? "Hola"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 26; bold: true } }
                                Item { Layout.fillWidth: true }
                                Text { text: br.hoy?.fecha ?? ""; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 } }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 10
                                Text { text: "✦"; color: Paleta.morado; font { family: Paleta.fuente; pixelSize: 16 } Layout.alignment: Qt.AlignTop
                                    SequentialAnimation on opacity { loops: Animation.Infinite; running: br.fraseCargando && br.abierto; NumberAnimation { to: .25; duration: 600 } NumberAnimation { to: 1; duration: 600 } } }
                                Text {
                                    Layout.fillWidth: true; wrapMode: Text.Wrap; lineHeight: 1.25
                                    text: br.frase || (br.fraseCargando ? "El asistente local está pensando en tu día…" : "")
                                    color: br.frase ? Paleta.texto : Paleta.gris
                                    font { family: Paleta.fuente; pixelSize: 13; italic: !br.frase }
                                }
                            }
                        }
                    }
                    // cifras
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Cifra { titulo: "Ayer en pantalla"; valor: br.hoy?.datos?.ayer ?? "—"; glifo: "f0954"; acento: Paleta.azul }
                        Cifra { titulo: "Media de la semana"; valor: br.hoy?.datos?.media ?? "—"; glifo: "f0128"; acento: Paleta.verde }
                        Cifra { titulo: "Hoy"; glifo: "f00ed"; acento: Paleta.amarillo
                                valor: !br.hoy ? "—" : [br.hoy.datos.eventos ? `${br.hoy.datos.eventos} ${br.hoy.datos.eventos === 1 ? "evento" : "eventos"}` : "",
                                                 br.hoy.datos.recordatorios ? `${br.hoy.datos.recordatorios} ${br.hoy.datos.recordatorios === 1 ? "recordatorio" : "recordatorios"}` : ""].filter(x => x).join(" · ") || "Agenda libre" }
                    }
                    Etiqueta { text: "IDEAS PARA HOY"; visible: (br.hoy?.sugerencias?.length ?? 0) > 0; Layout.topMargin: 2 }
                    Repeater {
                        model: br.hoy?.sugerencias ?? []
                        Rectangle {
                            id: tarjeta
                            required property var modelData
                            required property int index
                            property color acento: br.tono(modelData.tono)
                            property bool hecha: false
                            Layout.fillWidth: true; implicitHeight: 70; radius: 14
                            color: Qt.alpha(Paleta.texto, area.containsMouse ? .06 : .035)
                            border { width: 1; color: Qt.alpha(acento, area.containsMouse ? .45 : .15) }
                            opacity: hecha ? .45 : 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            // entrada escalonada
                            transform: Translate { id: tr; x: 0 }
                            Component.onCompleted: entrada.start()
                            SequentialAnimation { id: entrada
                                PropertyAction { target: tarjeta; property: "opacity"; value: 0 }
                                PropertyAction { target: tr; property: "x"; value: 18 }
                                PauseAnimation { duration: 60 * tarjeta.index }
                                ParallelAnimation {
                                    NumberAnimation { target: tarjeta; property: "opacity"; to: 1; duration: 260 }
                                    NumberAnimation { target: tr; property: "x"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }
                            Rectangle { width: 3; radius: 2; color: tarjeta.acento; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 14 } }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 26; rightMargin: 14 } spacing: 14
                                Medalla { glifo: tarjeta.modelData.icono; acento: tarjeta.acento }
                                ColumnLayout { Layout.fillWidth: true; spacing: 3
                                    Text { Layout.fillWidth: true; text: tarjeta.modelData.titulo; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                                    Text { Layout.fillWidth: true; text: tarjeta.modelData.detalle; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 } }
                                }
                                Boton {
                                    visible: !!tarjeta.modelData.boton2 && !tarjeta.hecha
                                    text: tarjeta.modelData.boton2 ?? ""; acento: tarjeta.acento
                                    onClicked: { br.lanzar(tarjeta.modelData.cmd2); tarjeta.hecha = true; cerrarLuego.restart(); }
                                }
                                Boton {
                                    text: tarjeta.hecha ? "✓ Hecho" : tarjeta.modelData.boton; destacado: !tarjeta.hecha; acento: tarjeta.acento
                                    Layout.preferredWidth: Math.max(130, implicitContentWidth + 28)
                                    onClicked: { br.lanzar(tarjeta.modelData.cmd); tarjeta.hecha = true; if (tarjeta.modelData.cmd.length) cerrarLuego.restart(); }
                                }
                            }
                        }
                    }
                    Timer { id: cerrarLuego; interval: 450; onTriggered: br.abierto = false }
                    // concentraciones programadas
                    Etiqueta { text: "CONCENTRACIÓN PROGRAMADA"; visible: (br.hoy?.programados?.length ?? 0) > 0 }
                    Flow {
                        Layout.fillWidth: true; spacing: 8; visible: (br.hoy?.programados?.length ?? 0) > 0
                        Repeater { model: br.hoy?.programados ?? []
                            Rectangle {
                                id: prog
                                required property var modelData
                                implicitHeight: 32; implicitWidth: pt.implicitWidth + 46; radius: 16
                                color: Qt.alpha(Paleta.naranja, .12); border { width: 1; color: Qt.alpha(Paleta.naranja, .4) }
                                Text { id: pt; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                    text: br.g("f04fe") + "  " + prog.modelData.texto + " · " + prog.modelData.minutos + " min"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
                                Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "✕"; color: Paleta.gris; font { pixelSize: 12 }
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: br.orden(["cancelar", prog.modelData.id]) } }
                            }
                        }
                    }
                    // recordatorios
                    Etiqueta { text: "RECORDATORIOS DE HOY"; visible: (br.hoy?.recordatorios?.length ?? 0) > 0 }
                    Flow {
                        Layout.fillWidth: true; spacing: 8; visible: (br.hoy?.recordatorios?.length ?? 0) > 0
                        Repeater { model: br.hoy?.recordatorios ?? []
                            Rectangle { required property var modelData; implicitHeight: 30; implicitWidth: rt.implicitWidth + 22; radius: 15; color: Qt.alpha(Paleta.amarillo, .1); border { width: 1; color: Qt.alpha(Paleta.amarillo, .3) }
                                Text { id: rt; anchors.centerIn: parent; text: parent.modelData.hora + "  " + parent.modelData.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } } } }
                    }
                    // vacío
                    ColumnLayout {
                        visible: br.hoy && br.hoy.sugerencias.length === 0
                        Layout.fillWidth: true; Layout.topMargin: 30; spacing: 6
                        Text { Layout.alignment: Qt.AlignHCenter; text: br.g("f05a8"); color: Paleta.verde; font { family: Paleta.fuente; pixelSize: 36 } }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Todo en orden. Nada que proponerte por ahora."; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 13 } }
                    }
                }
            }

            // ═══ LÍNEA DE TIEMPO ═════════════════════════════════════════
            ColumnLayout {
                anchors.fill: parent; spacing: 12
                visible: br.pagina === 1
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Boton { text: "‹"; implicitWidth: 36; onClicked: br.moverDia(-1) }
                    Text { text: br.fechaBonita(br.linea?.dia); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 15; bold: true } Layout.preferredWidth: 220; horizontalAlignment: Text.AlignHCenter }
                    Boton { text: "›"; implicitWidth: 36; enabled: !!br.dia; onClicked: br.moverDia(1) }
                    Boton { text: "Hoy"; visible: !!br.dia; onClicked: { br.dia = ""; br.cargar(); } }
                    Item { Layout.fillWidth: true }
                    Text { text: br.linea?.total ? "Total " + br.dur(br.linea.total) : ""; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 } }
                    TextField {
                        id: buscarLinea
                        Layout.preferredWidth: 220; placeholderText: "Filtrar por app o título…"
                        color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 }
                        background: Rectangle { radius: 9; color: Qt.alpha(Paleta.texto, .05); border { width: 1; color: Qt.alpha(Paleta.naranja, buscarLinea.activeFocus ? .5 : .1) } }
                        onTextChanged: br.filtro = text.toLowerCase()
                        Keys.onEscapePressed: { if (text) text = ""; else br.abierto = false; }
                    }
                }
                // cinta del día
                Item {
                    id: cinta
                    Layout.fillWidth: true; implicitHeight: 62
                    readonly property var bs: br.linea?.bloques ?? []
                    readonly property real inicio: {
                        if (!bs.length) return 0;
                        const d = new Date(bs[0].inicio * 1000); d.setMinutes(0, 0, 0);
                        return d.getTime() / 1000;
                    }
                    readonly property real fin: {
                        if (!bs.length) return 1;
                        const d = new Date(bs[bs.length - 1].fin * 1000); d.setMinutes(59, 59, 999);
                        return Math.max(d.getTime() / 1000 + 1, inicio + 6 * 3600);
                    }
                    function pos(t) { return (t - inicio) / (fin - inicio) * width; }
                    Rectangle { y: 8; width: parent.width; height: 30; radius: 8; color: Qt.alpha(Paleta.texto, .04) }
                    Repeater {
                        model: cinta.bs
                        Rectangle {
                            required property var modelData
                            readonly property bool coincide: !br.filtro || (modelData.nombre + " " + modelData.titulos.join(" ")).toLowerCase().includes(br.filtro)
                            x: cinta.pos(modelData.inicio); y: 8
                            width: Math.max(2, cinta.pos(modelData.fin) - x); height: 30
                            radius: width > 6 ? 4 : 1
                            color: Qt.alpha(br.colorDe(modelData.clase), coincide ? (zona.containsMouse ? 1 : .78) : .12)
                            MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true }
                            ToolTip.visible: zona.containsMouse
                            ToolTip.delay: 120
                            ToolTip.text: `${br.hora(modelData.inicio)}–${br.hora(modelData.fin)} · ${modelData.nombre} · ${br.dur(modelData.fin - modelData.inicio)}` + (modelData.titulos.length ? "\n" + modelData.titulos.slice(-2).join("\n") : "")
                        }
                    }
                    // marcas de hora
                    Repeater {
                        model: {
                            const r = []; if (!cinta.bs.length) return r;
                            const paso = (cinta.fin - cinta.inicio) > 12 * 3600 ? 3 : 2;
                            for (let t = cinta.inicio; t <= cinta.fin; t += 3600) { const h = new Date(t * 1000).getHours(); if (h % paso === 0) r.push(t); }
                            return r;
                        }
                        Item {
                            required property var modelData
                            x: cinta.pos(modelData)
                            Rectangle { y: 40; width: 1; height: 5; color: Qt.alpha(Paleta.texto, .25) }
                            Text { y: 46; x: -width / 2; text: new Date(parent.modelData * 1000).getHours() + ":00"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 9 } }
                        }
                    }
                    // archivos abiertos: un rombo sobre la cinta
                    Repeater {
                        model: (br.linea?.archivos ?? []).filter(a => a.t >= cinta.inicio && a.t <= cinta.fin)
                        Rectangle {
                            required property var modelData
                            x: cinta.pos(modelData.t) - 4; y: 0; width: 8; height: 8; rotation: 45; radius: 1
                            color: Paleta.amarillo; border { width: 1; color: Paleta.fondo }
                            MouseArea { id: zArch; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["xdg-open", parent.modelData.ruta]) }
                            ToolTip.visible: zArch.containsMouse; ToolTip.delay: 100
                            ToolTip.text: br.hora(modelData.t) + " · " + modelData.nombre + (modelData.app ? " · " + modelData.app : "")
                        }
                    }
                    // ahora
                    Rectangle {
                        visible: !br.dia && cinta.bs.length > 0
                        x: cinta.pos(Date.now() / 1000); y: 2; width: 2; height: 42; radius: 1; color: Paleta.naranja
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: -3; width: 8; height: 8; radius: 4; color: Paleta.naranja }
                    }
                }
                // resumen por app
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: br.linea?.resumen ?? []
                        Rectangle {
                            id: resApp
                            required property var modelData
                            implicitHeight: 28; implicitWidth: rs.implicitWidth + 22; radius: 14
                            color: Qt.alpha(br.colorDe(modelData.clase), br.filtro && modelData.nombre.toLowerCase().includes(br.filtro) ? .25 : .1)
                            border { width: 1; color: Qt.alpha(br.colorDe(modelData.clase), .35) }
                            Row { id: rs; anchors.centerIn: parent; spacing: 7
                                Rectangle { width: 8; height: 8; radius: 4; color: br.colorDe(resApp.modelData.clase); anchors.verticalCenter: parent.verticalCenter }
                                Text { text: resApp.modelData.nombre + "  " + br.dur(resApp.modelData.segundos); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: buscarLinea.text = buscarLinea.text === parent.modelData.nombre ? "" : parent.modelData.nombre }
                        }
                    }
                }
                // archivos abiertos ese día
                ListView {
                    visible: count > 0
                    Layout.fillWidth: true; implicitHeight: 34; orientation: ListView.Horizontal; spacing: 8; clip: true
                    model: (br.linea?.archivos ?? []).filter(a => !br.filtro || (a.nombre + " " + a.app).toLowerCase().includes(br.filtro)).slice().reverse()
                    delegate: Rectangle {
                        id: arch
                        required property var modelData
                        height: 30; width: Math.min(260, at.implicitWidth + 24); radius: 15
                        color: Qt.alpha(Paleta.amarillo, za.containsMouse ? .2 : .08); border { width: 1; color: Qt.alpha(Paleta.amarillo, .3) }
                        opacity: modelData.existe ? 1 : .45
                        Text { id: at; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle
                            text: br.g("f0214") + " " + br.hora(arch.modelData.t) + "  " + arch.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
                        MouseArea { id: za; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: arch.modelData.existe
                            onClicked: Quickshell.execDetached(["xdg-open", arch.modelData.ruta]) }
                        ToolTip.visible: za.containsMouse; ToolTip.delay: 300; ToolTip.text: arch.modelData.ruta + (arch.modelData.app ? "\nAbierto con " + arch.modelData.app : "")
                    }
                }
                // bloques (más recientes arriba)
                ListView {
                    id: listaBloques
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: (br.linea?.bloques ?? []).filter(b => b.fin - b.inicio >= 45 && (!br.filtro || (b.nombre + " " + b.titulos.join(" ")).toLowerCase().includes(br.filtro))).reverse()
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: bloque
                        required property var modelData
                        width: ListView.view.width - 10; implicitHeight: 52; radius: 10
                        color: Qt.alpha(Paleta.texto, hb.hovered ? .055 : .025)
                        HoverHandler { id: hb }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 12
                            Text { text: br.hora(bloque.modelData.inicio); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } Layout.preferredWidth: 42 }
                            Rectangle { width: 3; Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; radius: 2; color: br.colorDe(bloque.modelData.clase) }
                            Icono { nombre: bloque.modelData.icono; clase: bloque.modelData.clase; lado: 24 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 1
                                RowLayout { spacing: 8
                                    Text { text: bloque.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                    Rectangle { visible: !!bloque.modelData.contexto; implicitHeight: 18; implicitWidth: cx.implicitWidth + 12; radius: 9; color: Qt.alpha(Paleta.verde, .14)
                                        Text { id: cx; anchors.centerIn: parent; text: bloque.modelData.contexto; color: Paleta.verde; font { family: Paleta.fuente; pixelSize: 9; bold: true } } }
                                }
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                                    text: bloque.modelData.privado ? "🔒 Título no guardado (privado)" : bloque.modelData.titulos.length ? bloque.modelData.titulos.slice(-3).reverse().join("  ·  ") : "Sin título"
                                }
                            }
                            Text { text: br.dur(bloque.modelData.fin - bloque.modelData.inicio); color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent; visible: listaBloques.count === 0; spacing: 6
                        Text { Layout.alignment: Qt.AlignHCenter; text: br.g(br.linea?.privado ? "f033e" : "f0954"); color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 34 } }
                        Text {
                            Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 13 }
                            text: br.linea?.privado ? "Oculta mientras la privacidad está activa." : br.filtro ? "Nada coincide con «" + buscarLinea.text + "»." : "Aún no hay nada este día.\nLa línea se llena sola mientras usas el equipo."
                        }
                    }
                }
                // capturas (si las activaste)
                ListView {
                    visible: (br.linea?.capturas?.length ?? 0) > 0
                    Layout.fillWidth: true; implicitHeight: 74; orientation: ListView.Horizontal; spacing: 8; clip: true
                    model: br.linea?.capturas ?? []
                    delegate: Rectangle {
                        required property string modelData
                        width: 118; height: 70; radius: 8; clip: true; color: Qt.alpha(Paleta.texto, .05)
                        Image { anchors.fill: parent; source: "file://" + parent.modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 236 }
                        Text { anchors { right: parent.right; bottom: parent.bottom; margins: 4 } text: parent.modelData.split("/").pop().replace(/(\d\d)(\d\d)\d\d\.jpg/, "$1:$2"); color: "white"; style: Text.Outline; styleColor: "black"; font { family: Paleta.fuente; pixelSize: 10; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", parent.modelData]) }
                    }
                }
            }

            // ═══ CONTEXTO ════════════════════════════════════════════════
            ColumnLayout {
                anchors.fill: parent; spacing: 12
                visible: br.pagina === 2
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 64; radius: 14
                    color: Qt.alpha(br.estado?.pausado ? Paleta.gris : Paleta.verde, .08)
                    border { width: 1; color: Qt.alpha(br.estado?.pausado ? Paleta.gris : Paleta.verde, .3) }
                    RowLayout {
                        anchors { fill: parent; margins: 14 } spacing: 14
                        Medalla { glifo: br.estado?.pausado ? "f03e4" : "f0493"; acento: br.estado?.pausado ? Paleta.gris : Paleta.verde }
                        ColumnLayout { Layout.fillWidth: true; spacing: 2
                            Text { text: !br.estado?.servicio ? "El servicio no está en marcha" : br.estado?.pausado ? "Contexto automático en pausa" : "Contexto automático activo"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                                text: !br.estado?.servicio ? "Arranca solo al iniciar sesión. Ahora: ~/.config/hypr/scripts/brujula.py vigilar &"
                                    : br.estado?.pausado ? "Nada cambia solo. Lo que estaba aplicado se deshizo."
                                    : "Cambia perfil, No molestar y energía según lo que haces. Al terminar, todo vuelve como estaba." }
                        }
                        Interruptor { activo: !(br.estado?.pausado ?? false); onAlternado: br.orden([br.estado?.pausado ? "reanudar" : "pausar"]) }
                    }
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: br.estado?.reglas ?? []
                    delegate: Rectangle {
                        id: regla
                        required property var modelData
                        readonly property color acento: modelData.activa ? Paleta.verde : modelData.desactivada ? Paleta.gris : Paleta.azul
                        width: ListView.view.width; implicitHeight: 66; radius: 14
                        color: Qt.alpha(Paleta.texto, .03)
                        border { width: 1; color: Qt.alpha(regla.acento, modelData.activa ? .5 : .12) }
                        opacity: modelData.desactivada || br.estado?.pausado ? .55 : 1
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                        RowLayout {
                            anchors { fill: parent; margins: 12 } spacing: 14
                            Medalla { glifo: regla.modelData.icono; acento: regla.acento }
                            ColumnLayout { Layout.fillWidth: true; spacing: 3
                                RowLayout { spacing: 8
                                    Text { text: regla.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                                    Rectangle {
                                        implicitHeight: 18; implicitWidth: est.implicitWidth + 14; radius: 9
                                        color: Qt.alpha(regla.acento, .15)
                                        Text { id: est; anchors.centerIn: parent; color: regla.acento; font { family: Paleta.fuente; pixelSize: 9; bold: true }
                                            text: regla.modelData.desactivada ? "DESACTIVADA" : regla.modelData.activa ? "ACTIVA · desde " + br.hora(regla.modelData.desde) : "EN ESPERA" }
                                    }
                                }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.StyledText; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                                    text: "<font color='" + Paleta.texto + "'>Cuando</font> " + br.html(regla.modelData.cuando) + "  <font color='" + Paleta.naranja + "'>→</font>  " + br.html(regla.modelData.hace) }
                            }
                            Interruptor { activo: !regla.modelData.desactivada; acento: Paleta.azul; onAlternado: br.orden(["regla", regla.modelData.id, regla.modelData.desactivada ? "on" : "off"]) }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
                        text: "Línea de tiempo: " + (br.estado?.linea?.guardar ? "activa" : "apagada") + (br.estado?.linea?.titulos ? ", con títulos" : ", sin títulos")
                              + (br.estado?.linea?.capturas ? ", con capturas" : "") + ` · se borra a los ${br.estado?.linea?.dias ?? 30} días · nada sale del equipo · con privacidad activa no se guardan títulos.`
                    }
                    Boton { text: "Editar reglas"; onClicked: { Quickshell.execDetached(["kitty", "--class", "scratch-notas", "-e", "nvim", br.estado?.config ?? ""]); br.abierto = false; } }
                }
            }

            // ═══ SESIÓN ══════════════════════════════════════════════════
            ColumnLayout {
                id: pagSesion
                anchors.fill: parent; spacing: 12
                visible: br.pagina === 3
                readonly property var anterior: br.sesion?.anterior ?? null
                // sin sesión pendiente
                ColumnLayout {
                    visible: !parent.anterior
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    Item { Layout.fillHeight: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: br.g("f099b"); color: Paleta.verde; font { family: Paleta.fuente; pixelSize: 44 } }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "No hay nada pendiente de restaurar"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
                    Text {
                        Layout.alignment: Qt.AlignHCenter; horizontalAlignment: Text.AlignHCenter; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 }
                        text: (br.sesion?.foto?.apps ? `Tu escritorio está a salvo: última foto ${br.hace(br.sesion.foto.fecha)}, ${br.sesion.foto.apps} apps.\n` : "")
                              + "Si el equipo se reinicia o algo falla, al volver te ofreceré abrirlo todo en sus espacios."
                    }
                    Item { Layout.fillHeight: true }
                }
                // con sesión anterior
                Rectangle {
                    visible: !!parent.anterior
                    Layout.fillWidth: true; implicitHeight: 58; radius: 14
                    color: Qt.alpha(Paleta.azul, .08); border { width: 1; color: Qt.alpha(Paleta.azul, .3) }
                    RowLayout {
                        anchors { fill: parent; margins: 12 } spacing: 12
                        Medalla { glifo: "f02da"; acento: Paleta.azul; lado: 34 }
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Text { text: "Sesión anterior · " + (pagSesion.anterior ? br.hace(pagSesion.anterior.fecha) : ""); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                            Text { text: "Elige qué volver a abrir. Lo que ya está abierto viene sin marcar."; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                    }
                }
                GridView {
                    id: rejilla
                    visible: !!parent.anterior
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    cellWidth: width / 2; cellHeight: 58
                    boundsBehavior: Flickable.StopAtBounds
                    model: parent.anterior?.apps ?? []
                    delegate: Item {
                        id: app
                        required property var modelData
                        required property int index
                        readonly property bool marcada: !!br.elegidas[index]
                        width: rejilla.cellWidth; height: rejilla.cellHeight
                        Rectangle {
                            anchors { fill: parent; margins: 4 } radius: 11
                            color: Qt.alpha(app.marcada ? Paleta.naranja : Paleta.texto, app.marcada ? .1 : .03)
                            border { width: 1; color: Qt.alpha(Paleta.naranja, app.marcada ? .5 : .08) }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 } spacing: 10
                                Rectangle { implicitWidth: 18; implicitHeight: 18; radius: 5; color: app.marcada ? Paleta.naranja : "transparent"; border { width: 1.5; color: app.marcada ? Paleta.naranja : Paleta.gris }
                                    Text { anchors.centerIn: parent; text: "✓"; visible: app.marcada; color: Paleta.fondo; font { pixelSize: 12; bold: true } } }
                                Icono { nombre: app.modelData.icono; clase: app.modelData.clase; lado: 26 }
                                ColumnLayout { Layout.fillWidth: true; spacing: 0
                                    Text { text: app.modelData.nombre; color: Paleta.texto; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                                    Text { text: app.modelData.abierta ? "Ya está abierta" : (app.modelData.geo ? `Flotante ${app.modelData.geo.w}×${app.modelData.geo.h} · ` : "") + (app.modelData.titulo || app.modelData.clase); color: Paleta.gris; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Paleta.fuente; pixelSize: 10 } }
                                }
                                Rectangle { implicitHeight: 22; implicitWidth: 34; radius: 7; color: Qt.alpha(Paleta.azul, .15)
                                    Text { anchors.centerIn: parent; text: app.modelData.ws; color: Paleta.azul; font { family: Paleta.fuente; pixelSize: 11; bold: true } } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { const e = Object.assign({}, br.elegidas); e[app.index] = !e[app.index]; br.elegidas = e; } }
                        }
                    }
                }
                RowLayout {
                    visible: !!parent.anterior
                    Layout.fillWidth: true; spacing: 10
                    readonly property var marcadas: Object.keys(br.elegidas).filter(k => br.elegidas[k])
                    Boton { text: "Descartar"; acento: Paleta.gris; onClicked: br.orden(["sesion", "descartar"]) }
                    Item { Layout.fillWidth: true }
                    Boton { text: "Restaurar todo"; onClicked: br.orden(["sesion", "restaurar"], "cerrar") }
                    Boton { text: `Abrir ${parent.marcadas.length} seleccionadas`; destacado: true; enabled: parent.marcadas.length > 0
                            onClicked: br.orden(["sesion", "restaurar", "--solo", parent.marcadas.join(",")], "cerrar") }
                }
            }
        }

        // ── pie: mensajes ────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true; visible: !!br.aviso; elide: Text.ElideRight
            text: br.aviso; color: /no se|error|no existe/i.test(br.aviso) ? Paleta.rojo : Paleta.verde
            font { family: Paleta.fuente; pixelSize: 11 }
        }
    }
}
