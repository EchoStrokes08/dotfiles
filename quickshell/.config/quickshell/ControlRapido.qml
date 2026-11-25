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
    property bool compacto: false       // fila de 52 px: icono, nombre y estado en horizontal
    property string subtitulo: ""       // sustituye a «Activado» (p. ej. la red o el dispositivo conectado)
    property bool conDetalle: false     // flecha dentro de la tarjeta que abre la lista de dispositivos
    property bool pendiente: false
    readonly property bool disponible: dato?.disponible ?? false
    readonly property bool activo: dato?.activo === true
    readonly property bool ocupado: pendiente || orden.running
    readonly property string estadoTexto: ocupado ? "Aplicando…" : error ? "Reintentar"
        : !dato ? "Consultando…" : !disponible ? "No disponible" : (activo && subtitulo) ? subtitulo : dato.etiqueta || (activo ? "Activado" : "Desactivado")
    signal accionar()
    signal detalle()
    signal consultar()
    signal confirmado(var estado)
    signal fallo(string mensaje)

    Layout.fillWidth: true
    implicitHeight: compacto ? 52 : 70
    leftPadding: compacto ? 12 : 0; rightPadding: compacto && conDetalle ? 36 : compacto ? 12 : 0
    topPadding: 4; bottomPadding: 4
    enabled: !ocupado
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.checkable: cosa !== "" && disponible
    Accessible.checked: activo
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
        // encendido = se ve encendido: superficie destacada, borde del acento y luz desde la izquierda
        destacado: control.disponible && control.activo
        Rectangle {
            visible: control.disponible && control.activo
            anchors { fill: parent; margins: 1 }
            radius: EstiloPanel.rTarjeta - 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0;   color: Qt.alpha(Paleta.acento, .16) }
                GradientStop { position: .55; color: "transparent" }
            }
        }
        Rectangle {
            visible: control.disponible && control.activo
            // dentro de la curva de la esquina (radio 16): a 4 px montaba sobre el borde y se veía cortada
            anchors { left: parent.left; top: parent.top; leftMargin: 8; topMargin: 8 }
            width: 14; height: 14; radius: height / 2
            color: Paleta.acento
            Text { anchors.centerIn: parent; text: "✓"; color: Paleta.sobreAcento; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
            z: 1
        }
        encima: control.hovered
        foco: control.activeFocus
        tinte: control.error ? Paleta.peligro : Paleta.acento
    }
    contentItem: compacto ? filaCompacta : columna
    Row {
        id: filaCompacta
        visible: control.compacto
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.ocupado ? "…" : control.simbolo
            color: control.error ? Paleta.peligro : control.activo ? Paleta.acento : Paleta.texto
            font { family: Paleta.fuente; pixelSize: 20 }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: filaCompacta.width - 32
            Text {
                width: parent.width; elide: Text.ElideRight
                text: control.nombre
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; bold: true }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                visible: control.cosa !== ""
                text: control.estadoTexto
                color: control.error ? Paleta.peligro : EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 11 }
            }
        }
    }
    Column {
        id: columna
        visible: !control.compacto
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
    // Flecha integrada: abre los dispositivos sin conmutar (clic principal en el resto = conmutar)
    MouseArea {
        id: zonaDetalle
        visible: control.compacto && control.conDetalle
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.detalle()
        Accessible.role: Accessible.Button
        Accessible.name: "Dispositivos de " + control.nombre
        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 1; height: parent.height - 24
            color: EstiloPanel.bordeFuerte
        }
        Text {
            anchors.centerIn: parent
            text: "›"
            color: zonaDetalle.containsMouse ? Paleta.acento : Paleta.texto
            font { family: Paleta.fuente; pixelSize: 20 }
        }
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
