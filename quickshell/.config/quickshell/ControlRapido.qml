// Control rápido: el estado solo cambia después de confirmar la orden en el servicio.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Button {
    id: control
    property string nombre: ""
    property string simbolo: ""
    property string cosa: ""
    property var dato: null
    property string error: ""
    property bool pendiente: false
    readonly property bool disponible: dato?.disponible ?? false
    readonly property bool activo: dato?.activo === true
    readonly property bool ocupado: pendiente || orden.running
    readonly property string estadoTexto: ocupado ? "Aplicando…" : error ? "Reintentar"
        : !dato ? "Consultando…" : !disponible ? "No disponible" : dato.etiqueta || (activo ? "Activado" : "Desactivado")
    signal accionar()
    signal detalle()
    signal consultar()
    signal confirmado(var estado)
    signal fallo(string mensaje)

    Layout.fillWidth: true
    implicitHeight: 70
    leftPadding: 0; rightPadding: 0
    topPadding: 4; bottomPadding: 4
    enabled: !ocupado
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: nombre
    Accessible.description: cosa ? estadoTexto + ". " + (error || dato?.error || dato?.detalle || "") : nombre
    onDatoChanged: if (!ocupado) error = ""
    onClicked: {
        if (ocupado) return;
        if (!cosa) { accionar(); return; }
        error = "";
        if (!disponible) {
            consultar();
            fallo(dato?.error || "Consultando el servicio. Vuelve a intentarlo cuando termine.");
            return;
        }
        orden.respuesta = null;
        pendiente = true;
        orden.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/conmutadores.sh", cosa, activo ? "off" : "on"];
        orden.running = true;
    }
    background: FondoBoton {
        radio: EstiloPanel.rTarjeta
        destacado: control.activo
        encima: control.hovered
        foco: control.activeFocus
        tinte: control.error ? Paleta.peligro : Paleta.acento
    }
    contentItem: Column {
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.ocupado ? "…" : control.simbolo
            color: control.error ? Paleta.peligro : control.activo ? Paleta.acento : Paleta.texto
            font { family: Paleta.fuente; pixelSize: 20 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.nombre
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 11; bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: control.cosa !== ""
            text: control.estadoTexto
            color: control.error ? Paleta.peligro : EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 11 }
        }
    }
    ToolTip.visible: hovered && cosa !== ""
    ToolTip.text: error || dato?.error || dato?.detalle || (nombre + " · " + estadoTexto)
    ToolTip.delay: 500
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: control.detalle()
    }
    Process {
        id: orden
        property var respuesta: null
        stdout: StdioCollector {
            onStreamFinished: {
                try { orden.respuesta = JSON.parse(text); }
                catch (e) { orden.respuesta = null; }
            }
        }
        onExited: (codigo, estadoSalida) => {
            control.pendiente = false;
            const r = respuesta;
            if (r?.estado) control.confirmado(r.estado);
            if (codigo !== 0 || estadoSalida !== 0 || r?.ok !== true) {
                control.error = r?.error || "No se pudo confirmar el cambio. Reintenta o revisa el servicio.";
                control.fallo(control.error);
            } else control.error = "";
        }
    }
    Timer {
        interval: 30000
        running: control.ocupado
        onTriggered: {
            orden.running = false;
            control.pendiente = false;
            control.error = "El servicio no respondió a tiempo. Consulta su estado antes de reintentar.";
            control.fallo(control.error);
        }
    }
}
