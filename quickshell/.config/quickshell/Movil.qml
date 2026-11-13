// Móvil › avisos y respuestas (KDE Connect). Las acciones rápidas (sonar, enviar archivo…) y la batería
// están en el centro de control › Móvil (SUPER+N); aquí se llega desde allí o al pulsar «Responder».
//   · avisos del móvil, con respuesta (WhatsApp, Telegram, SMS…) y descartar
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
    ColumnLayout {
        width: parent.width; spacing: 12

        // ── cabecera ─────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Rectangle {
                implicitWidth: 40; implicitHeight: 40; radius: 12
                color: Qt.alpha(Paleta.acento, .22)
                border { width: 1; color: Qt.alpha(Paleta.acento, .5) }
                Text { anchors.centerIn: parent; text: mv.g("f011c"); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20 } }
            }
            ColumnLayout {
                spacing: 0; Layout.fillWidth: true
                Text { text: "Móvil"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20; bold: true } }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
                    text: !mv.d ? "Buscando…" : !mv.d.conectado ? "Sin conectar"
                        : mv.d.nombre + " · conectado por " + (mv.d.via || "red") + (mv.d.red?.tipo ? ` · ${mv.d.red.tipo}` : "")
                }
            }
            Anillo {
                visible: (mv.d?.bateria ?? -1) >= 0
                implicitWidth: 62; implicitHeight: 62; grosor: 5
                valor: (mv.d?.bateria ?? 0) / 100
                color: mv.d?.cargando ? Paleta.exito : (mv.d?.bateria ?? 100) <= 20 ? Paleta.peligro : Paleta.acento2
                texto: (mv.d?.bateria ?? 0) + "%"
                etiqueta: mv.d?.cargando ? "carga" : ""
            }
            BotonCompacto { text: "󰅖"; Accessible.name: "Cerrar"; implicitWidth: 38; implicitHeight: 38; leftPadding: 0; rightPadding: 0; onClicked: mv.abierto = false; background: FondoBoton { tinte: Paleta.peligro; encima: parent.hovered; foco: parent.activeFocus; radio: 19 } }
        }

        // ── responder (a una notificación del PC con respuesta en línea, o del móvil) ──
        Rectangle {
            visible: !!mv.notiPc || !!mv.respondiendo
            Layout.fillWidth: true; implicitHeight: comp.implicitHeight + 28; radius: 16
            color: Qt.alpha(Paleta.exito, .08); border { width: 1; color: Qt.alpha(Paleta.exito, .45) }
            readonly property var nm: (mv.d?.notificaciones ?? []).find(n => n.id === mv.respondiendo) ?? null
            ColumnLayout {
                id: comp
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 } spacing: 8
                Etiqueta { text: "RESPONDER · " + (mv.notiPc?.appName || parent.parent.nm?.app || "").toUpperCase(); color: Paleta.exito }
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
                        background: Rectangle { radius: 12; color: EstiloPanel.borde; border { width: 1; color: Qt.alpha(Paleta.exito, respuesta.activeFocus ? .6 : .15) } }
                        Keys.onReturnPressed: mv.enviarRespuesta()
                        Keys.onEnterPressed: mv.enviarRespuesta()
                        Keys.onEscapePressed: { mv.notiPc = null; mv.respondiendo = ""; }
                    }
                    BotonCompacto { text: "Enviar ↵"; destacado: true; acento: Paleta.exito; enabled: respuesta.text.trim().length > 0; onClicked: mv.enviarRespuesta() }
                    BotonCompacto { text: "Cancelar"; acento: Paleta.gris; onClicked: { mv.notiPc = null; mv.respondiendo = ""; } }
                }
            }
        }

        Timer { id: capturaLuego; interval: 450; onTriggered: Quickshell.execDetached([mv.script, "captura"]) }   // sin el panel en la foto

        // ── sin conectar: un mensaje y una acción ────────────────────────
        ColumnLayout {
            visible: !!mv.d && !mv.d.conectado
            Layout.fillWidth: true; Layout.topMargin: 32; Layout.bottomMargin: 32; spacing: 8
            Text { Layout.alignment: Qt.AlignHCenter; text: mv.g("f011c"); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 36 } }
            Text { Layout.alignment: Qt.AlignHCenter; text: mv.d?.emparejado ? "El móvil no está conectado" : "No hay ningún móvil emparejado"
                   color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 460; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   text: mv.d?.emparejado ? "Abre KDE Connect en el móvil y conéctalo a la misma red Wi-Fi que este equipo."
                                          : "Empareja tu móvil desde KDE Connect para ver aquí sus avisos y contestarlos."
                   color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
            BotonCompacto { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 8; text: "Abrir KDE Connect"; destacado: true
                            onClicked: { Quickshell.execDetached(["kdeconnect-app"]); mv.abierto = false; } }
        }

        // ── avisos del móvil | música + funciones ────────────────────────
        RowLayout {
            visible: !!mv.d?.conectado
            Layout.fillWidth: true; Layout.preferredHeight: 330; spacing: 12

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 3; spacing: 8
                RowLayout {
                    Etiqueta { text: "AVISOS DEL MÓVIL" }
                    Rectangle { visible: (mv.d?.notificaciones?.length ?? 0) > 0; implicitWidth: cn.implicitWidth + 12; implicitHeight: 16; radius: 8; color: Qt.alpha(Paleta.acento, .2)
                        Text { id: cn; anchors.centerIn: parent; text: mv.d?.notificaciones?.length ?? 0; color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 11; bold: true } } }
                }
                ListView {
                    id: avisos
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    boundsBehavior: Flickable.StopAtBounds
                    model: mv.d?.notificaciones ?? []
                    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: EstiloPanel.normal } }
                    delegate: Rectangle {
                        id: nt
                        required property var modelData
                        width: ListView.view.width; implicitHeight: 62; radius: 12
                        color: Qt.alpha(Paleta.texto, hn.hovered ? .06 : .035)
                        HoverHandler { id: hn }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 } spacing: 8
                            Item {
                                implicitWidth: 30; implicitHeight: 30
                                Image { anchors.fill: parent; visible: !!nt.modelData.icono; source: nt.modelData.icono ? "file://" + nt.modelData.icono : ""; sourceSize.width: 60; fillMode: Image.PreserveAspectFit; asynchronous: true }
                                Rectangle { anchors.fill: parent; radius: 12; visible: !nt.modelData.icono; color: Qt.alpha(Paleta.exito, .15)
                                    Text { anchors.centerIn: parent; text: (nt.modelData.app || "?").charAt(0).toUpperCase(); color: Paleta.exito; font { family: Paleta.fuente; pixelSize: 14; bold: true } } }
                            }
                            ColumnLayout { Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1; spacing: 1
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                    text: nt.modelData.titulo || nt.modelData.app }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                                    text: (nt.modelData.titulo ? nt.modelData.app + " · " : "") + nt.modelData.texto }
                            }
                            BotonCompacto { visible: nt.modelData.responder; text: "Responder"; acento: Paleta.exito
                                    onClicked: { mv.notiPc = null; mv.respondiendo = nt.modelData.id; respuesta.forceActiveFocus(); } }
                            BotonCompacto { visible: nt.modelData.descartable; text: "✕"; implicitWidth: 32; acento: Paleta.gris; onClicked: mv.orden(["descartar", nt.modelData.id]) }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent; width: parent.width - 40; spacing: 4
                        visible: avisos.count === 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: mv.g("f009c"); color: Qt.alpha(Paleta.gris, .7); font { family: Paleta.fuente; pixelSize: 36 } }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Nada nuevo en el móvil"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                        Text {
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                            text: "Aquí aparecen sus avisos, y los de WhatsApp o SMS se pueden contestar.\n¿No llega ninguno? En el móvil: KDE Connect → este PC → «Sincronizar notificaciones» y dale el permiso de acceso a notificaciones."
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 2; spacing: 8
                // música del móvil
                Rectangle {
                    visible: !!mv.d?.musica
                    Layout.fillWidth: true; implicitHeight: 74; radius: 16
                    gradient: Gradient { orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(Paleta.acento, .16) }
                        GradientStop { position: 1; color: Qt.alpha(Paleta.acento2, .08) } }
                    RowLayout {
                        anchors { fill: parent; margins: 8 } spacing: 8
                        ClippingRectangle {
                            implicitWidth: 52; implicitHeight: 52; radius: 12; color: EstiloPanel.rellenoActivo
                            Image { anchors.fill: parent; source: mv.d?.musica?.portada ? (mv.d.musica.portada.startsWith("/") ? "file://" : "") + mv.d.musica.portada : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Text { anchors.centerIn: parent; visible: !mv.d?.musica?.portada; text: mv.g("f075a"); color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 20 } }
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
                                text: mv.g(modelData[0]); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16 }
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
                        Layout.fillWidth: true; spacing: 8
                        ColumnLayout { Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.preferredWidth: 1; spacing: 0
                            Text { text: fn.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: fn.modelData.detalle; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                        Interruptor { activo: fn.modelData.activa; opacity: mv.d?.conectado ? 1 : .4; onAlternado: if (mv.d?.conectado) mv.orden(["funcion", fn.modelData.id, fn.modelData.activa ? "off" : "on"]) }
                    }
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 }
                        text: (mv.d?.mandos_nuestros ?? 0) > 0 ? `${mv.d.mandos_nuestros} mandos del PC en el móvil: KDE Connect → «Ejecutar orden».` : "Controla el PC desde el móvil: diapositivas, música, bloquear…" }
                    BotonCompacto { text: (mv.d?.mandos_nuestros ?? 0) > 0 ? "Actualizar mandos" : "Instalar mandos"; destacado: (mv.d?.mandos_nuestros ?? 0) === 0; onClicked: mv.orden(["comandos"]) }
                }
            }
        }

        // ── pie ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: mv.aviso; color: mv.aviso.startsWith("⚠") ? Paleta.peligro : Paleta.exito; font { family: Paleta.fuente; pixelSize: 11 } }
            BotonCompacto { visible: !!mv.d?.conectado; text: "Abrir KDE Connect"; acento: Paleta.gris; onClicked: { Quickshell.execDetached(["kdeconnect-app"]); mv.abierto = false; } }
        }
    }
}
