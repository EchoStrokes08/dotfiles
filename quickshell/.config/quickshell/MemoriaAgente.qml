// MemoriaAgente: ver y gestionar lo que el agente recuerda (scripts/memoria.py). Dentro de Agente › Memoria.
//   · composición por tipo (web, documentos, línea de tiempo), tamaño y última actualización
//   · lo que más guarda: dominios y carpetas, con «Excluir»
//   · explorar fuentes con buscador; «Olvidar» borra una y no vuelve (con deshacer)
//   · exclusiones como chips; pausar, actualizar ahora y borrar todo (escribiendo BORRAR)
// Con privacidad activa solo se ven las cifras.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: mem
    property bool activa: false              // el agente la muestra: cargar al entrar
    property var datos: null                 // memoria.py resumen
    property var lista: []                   // memoria.py fuentes <tipo>
    property string tipo: "web"
    property string mensaje: ""
    property bool error: false
    property string deshacerClave: ""
    property bool confirmarBorrado: false
    readonly property bool privado: EstadoEscritorio.privacidad
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/memoria.py"
    readonly property var tipos: [
        { id: "web", nombre: "Web", color: Paleta.serie[4], dias: datos?.dias_web ?? 90 },
        { id: "documento", nombre: "Documentos", color: Paleta.serie[0], dias: 0 },
        { id: "linea", nombre: "Línea de tiempo", color: Paleta.serie[5], dias: datos?.dias_linea ?? 60 }]

    onActivaChanged: if (activa) refrescar()
    function refrescar() { if (!leerResumen.running) leerResumen.running = true; leerFuentes.restart(); }
    function g(cp) { return String.fromCodePoint(parseInt(cp, 16)); }
    function cuenta(t) { return datos?.por_tipo?.[t] ?? 0; }
    function megas(b) { return b >= 1048576 ? (b / 1048576).toFixed(1).replace(".", ",") + " MB" : Math.round(b / 1024) + " KB"; }
    function hace(t) {
        if (!t) return "nunca";
        const m = Math.round((Date.now() / 1000 - t) / 60);
        return m < 1 ? "ahora" : m < 60 ? "hace " + m + " min" : m < 1440 ? "hace " + Math.round(m / 60) + " h" : "hace " + Math.round(m / 1440) + " días";
    }
    function fecha(t) { return t ? new Date(t * 1000).toLocaleDateString(Qt.locale("es_ES"), "d MMM yyyy") : ""; }
    function orden(args, msg) {
        if (accion.running) return;
        mem.error = false; mem.mensaje = msg || "Aplicando…";
        accion.command = [mem.script, ...args]; accion.running = true;
    }

    Process {
        id: leerResumen
        command: [mem.script, "resumen"]
        stdout: StdioCollector { onStreamFinished: { try { mem.datos = JSON.parse(text); } catch (e) { mem.error = true; mem.mensaje = "No se pudo leer la memoria."; } } }
    }
    Timer {   // el buscador espera a que termines de escribir
        id: leerFuentes
        interval: 250
        onTriggered: { if (mem.privado) { mem.lista = []; return; } procFuentes.command = [mem.script, "fuentes", mem.tipo, buscador.text]; procFuentes.running = true; }
    }
    Process {
        id: procFuentes
        stdout: StdioCollector { onStreamFinished: { try { mem.lista = JSON.parse(text); } catch (e) { mem.lista = []; } } }
    }
    Process {
        id: accion
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    mem.error = r.ok === false;
                    mem.mensaje = r.error || r.mensaje || (r.fuentes_actualizadas !== undefined ? "Actualizada: " + r.trozos_nuevos + " trozos nuevos." : "Hecho.");
                    mem.deshacerClave = r.deshacer || "";
                } catch (e) { mem.error = true; mem.mensaje = "No se pudo completar la orden."; }
            }
        }
        onExited: mem.refrescar()
    }

    Flickable {
    id: desplazable
    anchors.fill: parent
    clip: true
    contentHeight: columna.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
    id: columna
    width: desplazable.width - 16
    spacing: 12

    // ── Cabecera: estado y control ───────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { text: "Memoria del agente"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                text: !mem.datos ? "Leyendo…" : (mem.datos.pausada ? "En pausa · no guarda nada nuevo" : "Activa · actualizada " + mem.hace(mem.datos.actualizado))
                      + " · local, nada sale del equipo"
                color: mem.datos?.pausada ? Paleta.aviso : EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
        BotonCompacto { text: "Actualizar ahora"; enabled: !accion.running && !(mem.datos?.pausada); onClicked: mem.orden(["indexar", "--max", "400"], "Actualizando… puede tardar un minuto") }
        BotonCompacto { text: mem.datos?.pausada ? "Reanudar" : "Pausar"; destacado: mem.datos?.pausada ?? false; enabled: !accion.running; onClicked: mem.orden([mem.datos?.pausada ? "reanudar" : "pausar"]) }
    }

    // ── Composición: una barra proporcional por tipo ─────────────────
    TarjetaPanel {
        Layout.fillWidth: true
        relleno: 16
        RowLayout {
            Layout.fillWidth: true
            Text { text: (mem.datos?.trozos ?? 0).toLocaleString(Qt.locale("es_ES"), "f", 0) + " fragmentos"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20; bold: true } }
            Item { Layout.fillWidth: true }
            Text { text: mem.megas(mem.datos?.bytes ?? 0) + " en disco"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
        }
        Rectangle {
            id: barra
            Layout.fillWidth: true
            implicitHeight: 12; radius: height / 2
            color: EstiloPanel.relleno
            clip: true
            Row {
                anchors.fill: parent
                Repeater {
                    model: mem.tipos
                    Rectangle {
                        required property var modelData
                        height: barra.height
                        width: (mem.datos?.trozos ?? 0) > 0 ? barra.width * mem.cuenta(modelData.id) / mem.datos.trozos : 0
                        color: modelData.color
                        Behavior on width { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                model: mem.tipos
                RowLayout {
                    required property var modelData
                    spacing: 8
                    Rectangle { implicitWidth: 10; implicitHeight: 10; radius: height / 2; color: modelData.color }
                    Text {
                        text: modelData.nombre + " · " + mem.cuenta(modelData.id) + (modelData.dias ? "  (últimos " + modelData.dias + " días)" : "")
                        color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
                    }
                }
            }
        }
    }

    // ── Lo que más guarda ────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: !mem.privado
        spacing: 12
        Repeater {
            model: [{ clave: "web", titulo: "DOMINIOS", clase: "dominio" }, { clave: "documento", titulo: "CARPETAS", clase: "carpeta" }]
            TarjetaPanel {
                id: tarjetaTop
                required property var modelData
                readonly property var filas: mem.datos?.top?.[modelData.clave] ?? []
                readonly property int maximo: filas.length ? filas[0].trozos : 1
                Layout.fillWidth: true; Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                relleno: 12
                espaciado: 4
                Etiqueta { text: tarjetaTop.modelData.titulo + " CON MÁS FRAGMENTOS" }
                Text { visible: tarjetaTop.filas.length === 0; text: "Nada guardado."; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                Repeater {
                    // cada fila lleva su color, su máximo y su clase: el delegado no mira fuera
                    model: tarjetaTop.filas.slice(0, 4).map(f => Object.assign({}, f, {
                        tono: tarjetaTop.modelData.clave === "web" ? Paleta.serie[4] : Paleta.serie[0],
                        maximo: tarjetaTop.maximo, clase: tarjetaTop.modelData.clase }))
                    Item {
                        id: filaTop
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        HoverHandler { id: sobreTop }
                        Rectangle {   // barra de fondo proporcional
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            height: 24; radius: EstiloPanel.rChip
                            width: Math.max(8, (parent.width - 72) * filaTop.modelData.trozos / Math.max(1, filaTop.modelData.maximo))
                            color: EstiloPanel.rellenoActivo      // neutra: un color translúcido sobre oscuro se vuelve marrón
                            Rectangle { width: 3; height: parent.height - 8; radius: 4; anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } color: filaTop.modelData.tono }
                        }
                        Text {
                            anchors { left: parent.left; leftMargin: 16; right: botonExcluir.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideMiddle
                            text: filaTop.modelData.nombre + "  ·  " + filaTop.modelData.trozos
                            color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 }
                        }
                        BotonCompacto {
                            id: botonExcluir
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            implicitHeight: 24
                            opacity: sobreTop.hovered || activeFocus ? 1 : 0
                            text: "Excluir"
                            Accessible.name: "Excluir " + filaTop.modelData.nombre
                            onClicked: mem.orden(["excluir", filaTop.modelData.clase, filaTop.modelData.ruta || filaTop.modelData.nombre])
                        }
                    }
                }
            }
        }
    }

    // ── Explorar ─────────────────────────────────────────────────────
    TarjetaPanel {
        Layout.fillWidth: true
        relleno: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: mem.tipos
                BotonCompacto {
                    required property var modelData
                    text: modelData.nombre
                    destacado: mem.tipo === modelData.id
                    onClicked: { mem.tipo = modelData.id; leerFuentes.restart(); }
                }
            }
            CampoPanel {
                id: buscador
                Layout.fillWidth: true
                enabled: !mem.privado
                placeholderText: mem.privado ? "Detalles ocultos por privacidad" : "Buscar en lo guardado…"
                onTextChanged: leerFuentes.restart()
            }
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 232
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            model: mem.lista
            delegate: Item {
                id: fila
                required property var modelData
                width: ListView.view.width - 8
                implicitHeight: 44
                HoverHandler { id: sobreFila }
                Rectangle { anchors.fill: parent; radius: EstiloPanel.rControl; color: sobreFila.hovered ? EstiloPanel.rellenoActivo : "transparent" }
                Rectangle {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 4; height: 24; radius: 4
                    color: mem.tipos.find(t => t.id === mem.tipo)?.color ?? Paleta.acento
                }
                ColumnLayout {
                    anchors { left: parent.left; leftMargin: 24; right: accionesFila.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: fila.modelData.titulo || fila.modelData.ref; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideMiddle
                        text: (fila.modelData.dominio || fila.modelData.ref.replace(Quickshell.env("HOME"), "~")) + " · " + mem.fecha(fila.modelData.fecha)
                              + " · " + fila.modelData.trozos + (fila.modelData.trozos === 1 ? " fragmento" : " fragmentos")
                        color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
                Row {
                    id: accionesFila
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    opacity: sobreFila.hovered || abrirFila.activeFocus || olvidarFila.activeFocus ? 1 : 0
                    BotonCompacto {
                        id: abrirFila
                        visible: mem.tipo !== "linea"
                        text: "Abrir"
                        onClicked: Quickshell.execDetached(["xdg-open", fila.modelData.ref])
                    }
                    BotonCompacto {
                        id: olvidarFila
                        text: "Olvidar"
                        Accessible.name: "Olvidar " + (fila.modelData.titulo || fila.modelData.ref)
                        onClicked: mem.orden(["olvidar", fila.modelData.clave])
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: mem.privado ? "Con privacidad activa solo se muestran las cifras." : buscador.text ? "Nada coincide." : "Nada guardado de este tipo."
                color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
    }

    // ── Exclusiones y zona de borrado ────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: !mem.privado
        spacing: 8
        Etiqueta { text: "NO GUARDAR" }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: [...(mem.datos?.dominios ?? []).map(d => ({ clase: "dominio", valor: d, texto: d })),
                        ...(mem.datos?.carpetas ?? []).map(c => ({ clase: "carpeta", valor: c, texto: c.replace(Quickshell.env("HOME"), "~") }))]
                Rectangle {
                    id: chip
                    required property var modelData
                    implicitHeight: 24; implicitWidth: textoChip.implicitWidth + 32; radius: height / 2
                    color: EstiloPanel.elevada; border { width: 1; color: EstiloPanel.bordeFuerte }
                    Text { id: textoChip; anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter } text: chip.modelData.texto; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11 } }
                    Text {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "×"; color: zonaChip.containsMouse ? Paleta.peligro : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13; bold: true }
                        MouseArea { id: zonaChip; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: mem.orden(["incluir", chip.modelData.clase, chip.modelData.valor]) }
                    }
                }
            }
            Text {
                visible: !(mem.datos?.dominios?.length) && !(mem.datos?.carpetas?.length)
                text: "Nada excluido" + ((mem.datos?.olvidadas ?? 0) > 0 ? " · " + mem.datos.olvidadas + " fuentes olvidadas" : "")
                color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
        CampoPanel {
            id: nuevaExclusion
            Layout.preferredWidth: 220
            placeholderText: "dominio.com o ~/carpeta"
            onAccepted: if (text.trim()) { mem.orden(["excluir", /^[~\/]/.test(text.trim()) ? "carpeta" : "dominio", text.trim()]); text = ""; }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true
            visible: mem.mensaje !== ""
            text: mem.mensaje; elide: Text.ElideRight
            color: mem.error ? Paleta.peligro : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true; visible: mem.mensaje === "" }
        BotonCompacto {
            visible: mem.deshacerClave !== ""
            text: "Deshacer"
            onClicked: { mem.orden(["recordar", mem.deshacerClave], "Vuelve en la próxima actualización"); mem.deshacerClave = ""; }
        }
        BotonCompacto {
            visible: !mem.confirmarBorrado
            text: "Borrar toda la memoria"
            acento: Paleta.peligro
            onClicked: { mem.confirmarBorrado = true; confirmacion.forceActiveFocus(); }
        }
        CampoPanel {
            id: confirmacion
            visible: mem.confirmarBorrado
            Layout.preferredWidth: 220
            placeholderText: "Escribe BORRAR y pulsa Enter"
            onAccepted: { if (text === "BORRAR") mem.orden(["borrar-todo"]); text = ""; mem.confirmarBorrado = false; }
            Keys.onEscapePressed: { text = ""; mem.confirmarBorrado = false; }
        }
    }
    }
    }
}
