// Inspector contextual: capacidades actuales, formularios y recuperación, sin salir del lanzador.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: inspector
    property var referencia: null
    property var opciones: []
    property var seleccionada: null
    property var valores: ({})
    property string vista: ""
    property string mensaje: ""
    property string error: ""
    property string tokenDeshacer: ""
    readonly property bool ocupado: proceso.running
    signal cerrar()
    signal actualizado()
    signal soltarFoco()
    property bool exterior: false
    property var pendiente: null
    spacing: 8
    visible: referencia !== null
    function abrir(ref) {
        if (ocupado) return;
        if (EstadoEscritorio.privacidad) { referencia=ref;opciones=[];vista="";seleccionada=null;error="Desactiva privacidad para consultar detalles personales.";return; }
        forceActiveFocus();
        referencia = ref; seleccionada = null; opciones = []; vista = ""; mensaje = ""; error = ""; tokenDeshacer = "";
        lanzar("opciones",ref);
    }
    function lanzar(op,dato) {
        if (ocupado) return;
        if (EstadoEscritorio.privacidad) { error="Detalles ocultos por privacidad";return; }
        error = ""; proceso.op = op; proceso.respuesta = null;
        proceso.command = ["python3",Quickshell.env("HOME") + "/.config/hypr/scripts/acciones.py",op,JSON.stringify(dato)]; proceso.running = true;
    }
    function elegir(accion) {
        seleccionada = accion; valores = {};
        for (const campo of accion.campos) valores[campo.nombre] = campo.valor || "";
        if (!accion.campos.length) ejecutar();
        else Qt.callLater(() => campos.itemAt(0)?.enfocar());
    }
    function ejecutar() {
        exterior=["enfocar","retomar","abrir","carpeta","privada","abrir_con","calendario"].includes(seleccionada.codigo);
        const dato={ref:referencia,accion:seleccionada.codigo,valores:valores};
        if (exterior) { pendiente=dato;soltarFoco();esperarFoco.restart(); }
        else lanzar("ejecutar",dato);
    }
    Timer { id: esperarFoco; interval: 90; onTriggered: inspector.lanzar("ejecutar",inspector.pendiente) }
    function valor(nombre,texto) { const nuevos=Object.assign({},valores); nuevos[nombre]=texto; valores=nuevos; }
    Connections {
        target: EstadoEscritorio
        function onPrivacidadChanged() { if (EstadoEscritorio.privacidad) { inspector.seleccionada=null;inspector.opciones=[];inspector.vista="";inspector.error="Detalles ocultos por privacidad"; } }
    }
    Keys.onEscapePressed: (event) => {
        if (ocupado) { event.accepted = true; return; }
        if (seleccionada) seleccionada = null; else cerrar();
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Acciones"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
        BotonCompacto { text: "Volver"; enabled: !inspector.ocupado; onClicked: inspector.cerrar() }
    }
    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(100,vistaTexto.implicitHeight+16)
        visible: inspector.vista !== "" && !inspector.seleccionada
        clip: true
        TextArea { id: vistaTexto; readOnly: true; text: EstadoEscritorio.privacidad ? "Vista previa oculta por privacidad" : inspector.vista; wrapMode: TextEdit.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } background: Rectangle { color: EstiloPanel.superficie; radius: EstiloPanel.rChip } }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        visible: !inspector.seleccionada && !inspector.ocupado
        Repeater {
            id: listaAcciones
            model: inspector.opciones
            BotonCompacto { required property var modelData; text: modelData.titulo; onClicked: inspector.elegir(modelData) }
        }
    }
    Repeater {
        id: campos
        model: inspector.seleccionada?.campos ?? []
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 4
            function enfocar() { if (selector.visible) selector.forceActiveFocus(); else entrada.forceActiveFocus(); }
            Text { Layout.fillWidth: true; text: modelData.etiqueta; wrapMode: Text.Wrap; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
            SelectorPanel {
                id: selector
                Layout.fillWidth: true
                visible: modelData.tipo === "selector"
                model: modelData.opciones || []; textRole: "texto"; valueRole: "valor"
                currentIndex: Math.max(0,(modelData.opciones || []).findIndex(x => x.valor === modelData.valor))
                onActivated: inspector.valor(modelData.nombre,currentValue)
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: modelData.tipo === "multilinea" ? 92 : 38
                visible: modelData.tipo !== "selector"
                clip: true
                TextArea {
                    id: entrada
                    text: modelData.valor || ""
                    onTextChanged: inspector.valor(modelData.nombre,text)
                    wrapMode: TextEdit.Wrap
                    color: Paleta.texto; selectionColor: Paleta.acento; selectedTextColor: Paleta.sobreAcento
                    font { family: Paleta.fuente; pixelSize: 13 }
                    background: Rectangle { color: EstiloPanel.elevada; radius: EstiloPanel.rChip; border { width: entrada.activeFocus ? 2 : 1; color: entrada.activeFocus ? Paleta.acento : EstiloPanel.borde } }
                    Keys.onEscapePressed: { inspector.seleccionada=null; Qt.callLater(() => listaAcciones.itemAt(0)?.forceActiveFocus()); }
                }
            }
        }
    }
    RowLayout {
        visible: !!inspector.seleccionada && (inspector.seleccionada?.campos.length ?? 0)>0
        BotonCompacto { text: "Cancelar"; enabled: !inspector.ocupado; onClicked: inspector.seleccionada = null }
        BotonCompacto { text: inspector.ocupado ? "Aplicando…" : "Aplicar"; destacado: true; enabled: !inspector.ocupado; onClicked: inspector.ejecutar() }
    }
    Text { Layout.fillWidth: true; visible: text !== ""; text: inspector.ocupado ? "Consultando…" : inspector.error || inspector.mensaje; wrapMode: Text.Wrap; color: inspector.error ? Paleta.peligro : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
    RowLayout {
        visible: inspector.error !== "" || inspector.tokenDeshacer !== ""
        BotonCompacto { text: "Reintentar"; visible: inspector.error !== ""; enabled: !inspector.ocupado; onClicked: inspector.seleccionada ? inspector.ejecutar() : inspector.lanzar("opciones",inspector.referencia) }
        BotonCompacto { text: "Deshacer"; visible: inspector.tokenDeshacer !== ""; enabled: !inspector.ocupado; onClicked: inspector.lanzar("deshacer",{token:inspector.tokenDeshacer}) }
    }
    Process {
        id: proceso
        property string op: ""
        property var respuesta: null
        stdout: StdioCollector { onStreamFinished: { try { proceso.respuesta=JSON.parse(text); } catch(e) {} } }
        onExited: (codigo,estado) => {
            const r=respuesta;
            if (codigo !== 0 || estado !== 0 || r?.ok !== true) { inspector.error=r?.error || "No se pudo confirmar la acción. Reintenta."; if (inspector.exterior) Quickshell.execDetached(["notify-send","-a","ORION","No se pudo completar la acción",inspector.error]); return; }
            if (op === "opciones") { inspector.opciones=EstadoEscritorio.privacidad ? [] : r.acciones; inspector.vista=EstadoEscritorio.privacidad ? "" : r.vista; inspector.referencia=Object.assign({},inspector.referencia,{revision:r.revision}); Qt.callLater(() => listaAcciones.itemAt(0)?.forceActiveFocus()); }
            else {
                if (inspector.exterior) Quickshell.execDetached(["notify-send","-a","ORION","Acción confirmada",EstadoEscritorio.privacidad ? "Operación completada" : r.mensaje]);
                inspector.mensaje=r.mensaje; inspector.tokenDeshacer=r.deshacer || "";
                const codigo=inspector.seleccionada?.codigo;
                inspector.seleccionada=null; inspector.actualizado();
                if (["eliminar","archivar","ocultar","descartar","completar"].includes(codigo)) { inspector.opciones=[];inspector.vista=""; }
                else { const ref=Object.assign({},inspector.referencia);delete ref.revision;Qt.callLater(() => inspector.lanzar("opciones",ref)); }
            }
        }
    }
}
