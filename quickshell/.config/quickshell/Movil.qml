// Móvil (SUPER+ALT+M, clic en el móvil de la barra): el PC y el móvil como uno solo (KDE Connect).
//   · avisos del móvil, con respuesta (WhatsApp, Telegram, SMS…) y descartar
//   · acciones: sonar, abrir en el móvil lo copiado, archivo, captura, sus archivos, mensajes
//   · música que suena en el móvil · funciones de «uno solo» · mandos del PC en el móvil
// Datos y órdenes: ~/.config/hypr/scripts/movil.py. «Responder» en una notificación del PC abre
// aquí la respuesta (Notificaciones.responder).
//   qs ipc call movil toggle · qs ipc call movil estado
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Superpuesta {
    id: mv
    espacio: "movil"
    anchoTarjeta: Math.min(900, (screen?.width ?? 1280) - 40)
    alturaRelativa: 0.07
    opacidadTarjeta: 0.96
    acentoPanel: Paleta.verde

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/movil.py"
    property var d: null
    property string aviso: ""
    property string respondiendo: ""      // id de la notificación del móvil que se contesta
    property var notiPc: null             // o una notificación del PC con respuesta en línea

    function abrir() { abierto = true; cargar(); }
    function cargar() { if (!lector.running) lector.running = true; }
    function orden(args, cerrar) {
        if (accion.running) return;
        accion.cerrar = cerrar === true;
        accion.command = [script, ...args]; accion.running = true;
    }
    function g(hex) { return String.fromCodePoint(typeof hex === "number" ? hex : parseInt(hex, 16)); }
    function componer(n) { notiPc = n; respondiendo = ""; abierto = true; cargar(); Qt.callLater(() => respuesta.forceActiveFocus()); }

    Connections {
        target: Notificaciones
        function onResponderPedido(n) { mv.componer(n); }
    }
    onAbiertoChanged: if (!abierto) { notiPc = null; respondiendo = ""; respuesta.text = ""; }
    onAbriendose: aviso = ""
    Timer { interval: 4000; repeat: true; running: mv.abierto; onTriggered: mv.cargar() }

    Process {
        id: lector
        command: [mv.script, "estado"]
        stdout: StdioCollector { onStreamFinished: { try { mv.d = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: accion
        property bool cerrar: false
        stdout: StdioCollector { onStreamFinished: { try { const r = JSON.parse(text); if (r.mensaje) mv.aviso = r.mensaje; } catch (e) {} } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) { try { mv.aviso = "⚠ " + JSON.parse(text).error; } catch (e) { mv.aviso = "⚠ " + text.trim(); } } } }
        onExited: (codigo) => { if (codigo === 0 && accion.cerrar) mv.abierto = false; else mv.cargar(); }
    }

    function enviarRespuesta() {
        const t = respuesta.text.trim();
        if (!t) return;
        if (notiPc) {
            if (notiPc.hasInlineReply) notiPc.sendInlineReply(t);
            aviso = "Respuesta enviada";
            notiPc = null;
        } else if (respondiendo) {
            orden(["responder", respondiendo, t]);
            respondiendo = "";
        }
        respuesta.text = "";
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
    component Etiqueta: Text { color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1.6 } }
    component Accion: Rectangle {
        id: ac
        property string glifo: "f011c"
        property string texto: ""
        property color acento: Paleta.naranja
        signal pulsado()
        Layout.fillWidth: true; implicitHeight: 74; radius: 14
        color: Qt.alpha(acento, za.containsMouse ? .16 : .06)
        border { width: 1; color: Qt.alpha(acento, za.containsMouse ? .55 : .15) }
        scale: za.pressed ? .96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 140 } }
        Column {
            anchors.centerIn: parent; spacing: 6
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: mv.g(ac.glifo); color: ac.acento; font { family: Paleta.fuente; pixelSize: 22 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: ac.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
        }
        MouseArea { id: za; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !!mv.d?.conectado; onClicked: ac.pulsado() }
        opacity: mv.d?.conectado ? 1 : .4
    }

    ColumnLayout {
        width: parent.width; spacing: 14

        // ── cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Rectangle {
                implicitWidth: 50; implicitHeight: 50; radius: 15
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(Paleta.verde, .35) }
                    GradientStop { position: 1; color: Qt.alpha(Paleta.azul, .3) }
                }
                Text { anchors.centerIn: parent; text: mv.g("f011c"); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 26 } }
                // pulso: conectado
                Rectangle {
                    visible: !!mv.d?.conectado
                    anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
                    width: 14; height: 14; radius: 7; color: Paleta.verde; border { width: 2; color: Paleta.fondo }
                    SequentialAnimation on scale { loops: Animation.Infinite; running: mv.abierto; NumberAnimation { to: 1.25; duration: 900 } NumberAnimation { to: 1; duration: 900 } }
                }
            }
            ColumnLayout {
                spacing: 1; Layout.fillWidth: true
                Etiqueta { text: "PC + MÓVIL"; color: Paleta.verde }
                Text { text: mv.d?.conectado ? mv.d.nombre : "Móvil sin conectar"; color: Paleta.texto; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Paleta.fuente; pixelSize: 22; bold: true } }
                Text {
                    color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                    text: !mv.d ? "Buscando…" : !mv.d.conectado ? (mv.d.emparejado ? "Emparejado, pero no está en la misma red (o KDE Connect está cerrado en el móvil)" : "Aún no hay un móvil emparejado")
                        : "Conectado por " + (mv.d.via || "red") + (mv.d.red?.tipo ? ` · ${mv.d.red.tipo} ${"▂▄▆█".slice(0, Math.max(0, mv.d.red.fuerza))}` : "")
                }
            }
            Anillo {
                visible: (mv.d?.bateria ?? -1) >= 0
                implicitWidth: 62; implicitHeight: 62; grosor: 5
                valor: (mv.d?.bateria ?? 0) / 100
                color: mv.d?.cargando ? Paleta.verde : (mv.d?.bateria ?? 100) <= 20 ? Paleta.rojo : Paleta.azul
                texto: (mv.d?.bateria ?? 0) + "%"
                etiqueta: mv.d?.cargando ? "carga" : ""
            }
            Boton { text: "󰅖"; Accessible.name: "Cerrar"; implicitWidth: 38; implicitHeight: 38; leftPadding: 0; rightPadding: 0; onClicked: mv.abierto = false; background: FondoBoton { tinte: Paleta.rojo; encima: parent.hovered; foco: parent.activeFocus; radio: 19 } }
        }

        // ── responder (a una notificación del PC con respuesta en línea, o del móvil) ──
        Rectangle {
            visible: !!mv.notiPc || !!mv.respondiendo
            Layout.fillWidth: true; implicitHeight: comp.implicitHeight + 28; radius: 14
            color: Qt.alpha(Paleta.verde, .08); border { width: 1; color: Qt.alpha(Paleta.verde, .45) }
            readonly property var nm: (mv.d?.notificaciones ?? []).find(n => n.id === mv.respondiendo) ?? null
            ColumnLayout {
                id: comp
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 } spacing: 8
                Etiqueta { text: "RESPONDER · " + (mv.notiPc?.appName || parent.parent.nm?.app || "").toUpperCase(); color: Paleta.verde }
                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true }
                    text: mv.notiPc?.summary || parent.parent.nm?.titulo || "" }
                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 }
                    text: (mv.notiPc?.body || parent.parent.nm?.texto || "").replace(/<[^>]+>/g, "") }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    TextField {
                        id: respuesta
                        Layout.fillWidth: true
                        placeholderText: mv.notiPc?.inlineReplyPlaceholder || "Escribe tu respuesta y pulsa Enter…"
                        color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13 }
                        background: Rectangle { radius: 9; color: Qt.alpha(Paleta.texto, .06); border { width: 1; color: Qt.alpha(Paleta.verde, respuesta.activeFocus ? .6 : .15) } }
                        Keys.onReturnPressed: mv.enviarRespuesta()
                        Keys.onEnterPressed: mv.enviarRespuesta()
                        Keys.onEscapePressed: { mv.notiPc = null; mv.respondiendo = ""; }
                    }
                    Boton { text: "Enviar ↵"; destacado: true; acento: Paleta.verde; enabled: respuesta.text.trim().length > 0; onClicked: mv.enviarRespuesta() }
                    Boton { text: "Cancelar"; acento: Paleta.gris; onClicked: { mv.notiPc = null; mv.respondiendo = ""; } }
                }
            }
        }

        // ── acciones ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Accion { glifo: "f009e"; texto: "Sonar"; acento: Paleta.amarillo; onPulsado: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/movil.sh", "sonar"]) }
            Accion { glifo: "f0339"; texto: "Abrir lo copiado"; acento: Paleta.azul; onPulsado: mv.orden(["enlace"]) }
            Accion { glifo: "f0552"; texto: "Enviar archivo"; acento: Paleta.naranja; onPulsado: { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/movil.sh", "elegir"]); mv.abierto = false; } }
            Accion { glifo: "f0100"; texto: "Captura al móvil"; acento: Paleta.morado; onPulsado: { mv.abierto = false; capturaLuego.start(); } }
            Accion { glifo: "f024b"; texto: "Sus archivos"; acento: Paleta.verde; onPulsado: { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/movil.sh", "navegar"]); mv.abierto = false; } }
            Accion { glifo: "f0361"; texto: "Mensajes (SMS)"; acento: Paleta.azul; onPulsado: { Quickshell.execDetached(["kdeconnect-sms"]); mv.abierto = false; } }
        }
        Timer { id: capturaLuego; interval: 450; onTriggered: Quickshell.execDetached([mv.script, "captura"]) }   // sin el panel en la foto

        // ── avisos del móvil | música + funciones ────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 330; spacing: 14

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 3; spacing: 8
                RowLayout {
                    Etiqueta { text: "AVISOS DEL MÓVIL" }
                    Rectangle { visible: (mv.d?.notificaciones?.length ?? 0) > 0; implicitWidth: cn.implicitWidth + 12; implicitHeight: 16; radius: 8; color: Qt.alpha(Paleta.naranja, .2)
                        Text { id: cn; anchors.centerIn: parent; text: mv.d?.notificaciones?.length ?? 0; color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 9; bold: true } } }
                }
                ListView {
                    id: avisos
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: mv.d?.notificaciones ?? []
                    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 } }
                    delegate: Rectangle {
                        id: nt
                        required property var modelData
                        width: ListView.view.width; implicitHeight: 62; radius: 12
                        color: Qt.alpha(Paleta.texto, hn.hovered ? .06 : .035)
                        HoverHandler { id: hn }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 } spacing: 10
                            Item {
                                implicitWidth: 30; implicitHeight: 30
                                Image { anchors.fill: parent; visible: !!nt.modelData.icono; source: nt.modelData.icono ? "file://" + nt.modelData.icono : ""; sourceSize.width: 60; fillMode: Image.PreserveAspectFit; asynchronous: true }
                                Rectangle { anchors.fill: parent; radius: 9; visible: !nt.modelData.icono; color: Qt.alpha(Paleta.verde, .15)
                                    Text { anchors.centerIn: parent; text: (nt.modelData.app || "?").charAt(0).toUpperCase(); color: Paleta.verde; font { family: Paleta.fuente; pixelSize: 14; bold: true } } }
                            }
                            ColumnLayout { Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1; spacing: 1
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                    text: nt.modelData.titulo || nt.modelData.app }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                                    text: (nt.modelData.titulo ? nt.modelData.app + " · " : "") + nt.modelData.texto }
                            }
                            Boton { visible: nt.modelData.responder; text: "Responder"; acento: Paleta.verde
                                    onClicked: { mv.notiPc = null; mv.respondiendo = nt.modelData.id; respuesta.forceActiveFocus(); } }
                            Boton { visible: nt.modelData.descartable; text: "✕"; implicitWidth: 32; acento: Paleta.gris; onClicked: mv.orden(["descartar", nt.modelData.id]) }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent; width: parent.width - 40; spacing: 6
                        visible: avisos.count === 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: mv.g("f009c"); color: Qt.alpha(Paleta.gris, .7); font { family: Paleta.fuente; pixelSize: 34 } }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Nada nuevo en el móvil"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                        Text {
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                            text: "Aquí aparecen sus avisos, y los de WhatsApp o SMS se pueden contestar.\n¿No llega ninguno? En el móvil: KDE Connect → este PC → «Sincronizar notificaciones» y dale el permiso de acceso a notificaciones."
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 2; spacing: 10
                // música del móvil
                Rectangle {
                    visible: !!mv.d?.musica
                    Layout.fillWidth: true; implicitHeight: 74; radius: 14
                    gradient: Gradient { orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(Paleta.morado, .16) }
                        GradientStop { position: 1; color: Qt.alpha(Paleta.azul, .08) } }
                    RowLayout {
                        anchors { fill: parent; margins: 10 } spacing: 10
                        ClippingRectangle {
                            implicitWidth: 52; implicitHeight: 52; radius: 10; color: Qt.alpha(Paleta.texto, .08)
                            Image { anchors.fill: parent; source: mv.d?.musica?.portada ? (mv.d.musica.portada.startsWith("/") ? "file://" : "") + mv.d.musica.portada : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Text { anchors.centerIn: parent; visible: !mv.d?.musica?.portada; text: mv.g("f075a"); color: Paleta.morado; font { family: Paleta.fuente; pixelSize: 22 } }
                        }
                        ColumnLayout { Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1; spacing: 1
                            Etiqueta { text: "SUENA EN EL MÓVIL" }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: mv.d?.musica?.titulo ?? ""; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: mv.d?.musica?.artista ?? ""; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                        Repeater {
                            model: [["f04ae", "Previous"], [mv.d?.musica?.reproduciendo ? "f03e4" : "f040a", "PlayPause"], ["f04ad", "Next"]]
                            Text {
                                required property var modelData
                                text: mv.g(modelData[0]); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 18 }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: mv.orden(["musica", parent.modelData[1]]) }
                            }
                        }
                    }
                }
                Etiqueta { text: "UNO SOLO" }
                Repeater {
                    model: mv.d?.funciones ?? []
                    RowLayout {
                        id: fn
                        required property var modelData
                        Layout.fillWidth: true; spacing: 10
                        ColumnLayout { Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1; spacing: 0
                            Text { text: fn.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: fn.modelData.detalle; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 } }
                        }
                        Interruptor { activo: fn.modelData.activa; opacity: mv.d?.conectado ? 1 : .4; onAlternado: if (mv.d?.conectado) mv.orden(["funcion", fn.modelData.id, fn.modelData.activa ? "off" : "on"]) }
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
                        text: (mv.d?.mandos_nuestros ?? 0) > 0 ? `${mv.d.mandos_nuestros} mandos del PC en el móvil: KDE Connect → «Ejecutar orden».` : "Controla el PC desde el móvil: diapositivas, música, bloquear…" }
                    Boton { text: (mv.d?.mandos_nuestros ?? 0) > 0 ? "Actualizar mandos" : "Instalar mandos"; destacado: (mv.d?.mandos_nuestros ?? 0) === 0; onClicked: mv.orden(["comandos"]) }
                }
            }
        }

        // ── pie ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: mv.aviso; color: mv.aviso.startsWith("⚠") ? Paleta.rojo : Paleta.verde; font { family: Paleta.fuente; pixelSize: 11 } }
            Boton { text: "Abrir KDE Connect"; acento: Paleta.gris; onClicked: { Quickshell.execDetached(["kdeconnect-app"]); mv.abierto = false; } }
        }
    }
}
