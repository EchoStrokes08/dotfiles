// Autorizacion: el agente de polkit de la sesión (la ventana que pide la contraseña de administrador),
// dibujado con el estilo del sistema. Sustituye a hyprpolkitagent, que queda de respaldo:
// scripts/polkit-respaldo.sh lo arranca si este agente no se ha registrado (qs caído o sin cargar).
//   qs ipc call polkit registrado   → "si" | "no"
//   qs ipc call polkit cancelar     cancela la petición en curso
// La contraseña solo vive en el campo mientras se escribe: se envía a polkit y se borra al terminar.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

Superpuesta {
    id: v
    espacio: "autorizacion"
    anchoTarjeta: 440
    alturaRelativa: 0.26
    opacidadTarjeta: 1

    readonly property var flujo: agente.flow
    property bool fallo: false

    PolkitAgent { id: agente }

    IpcHandler {
        target: "polkit"
        function registrado(): string { return agente.isRegistered ? "si" : "no"; }
        function cancelar(): void { v.abierto = false; }
    }

    Connections {
        target: agente
        function onIsActiveChanged() {
            if (agente.isActive) { v.fallo = false; clave.text = ""; v.abierto = true; clave.forceActiveFocus(); }
            else { clave.text = ""; v.abierto = false; }
        }
    }
    Connections {
        target: v.flujo
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { v.fallo = true; clave.text = ""; if (EstiloPanel.movimiento) sacudida.restart(); clave.forceActiveFocus(); }
        function onIsResponseRequiredChanged() { if (v.flujo?.isResponseRequired) clave.forceActiveFocus(); }
    }
    // Esc, clic fuera o el modo privado cierran la tarjeta: eso es cancelar la petición
    onAbiertoChanged: {
        if (!abierto) {
            clave.text = "";
            if (flujo && !flujo.isCompleted) flujo.cancelAuthenticationRequest();
        }
    }

    function enviar() {
        if (!flujo || !flujo.isResponseRequired || clave.text === "") return;
        v.fallo = false;
        flujo.submit(clave.text);
        clave.text = "";
    }
    // polkit manda el texto del PAM en inglés («Password:»): se traduce lo habitual
    function prompt(t) {
        const s = (t || "").replace(/:\s*$/, "").trim();
        return /^password$/i.test(s) || s === "" ? "Contraseña" : s;
    }
    // polkit manda la descripción de la acción en inglés: las más habituales, en español
    function mensaje(t) {
        const m = [
            [/run a program as another user/i, "Para ejecutar un programa como administrador."],
            [/(install|remove|update|upgrade).*(package|software)/i, "Para instalar, quitar o actualizar programas."],
            [/(mount|unmount|format|modify).*(drive|disk|device|filesystem)/i, "Para montar o modificar un disco."],
            [/(manage|start|stop|restart|reload).*(system )?(service|unit)/i, "Para gestionar un servicio del sistema."],
            [/(time|timezone|date)/i, "Para cambiar la fecha, la hora o la zona horaria."],
            [/network/i, "Para cambiar la configuración de red."],
            [/(suspend|hibernate|power ?off|reboot)/i, "Para apagar, reiniciar o suspender el equipo."],
        ].find(([r]) => r.test(t || ""));
        return m ? m[1] : (t || "");
    }
    function nombreUsuario() {
        const i = flujo?.selectedIdentity;
        const n = i?.displayName ?? i?.userName ?? "";
        return n !== "" ? n : (Quickshell.env("USER") ?? "");
    }

    ColumnLayout {
        width: parent.width
        spacing: EstiloPanel.e3
        transform: Translate { id: desplazar }
        SequentialAnimation {
            id: sacudida
            NumberAnimation { target: desplazar; property: "x"; to: -12; duration: 50 }
            NumberAnimation { target: desplazar; property: "x"; to: 10;  duration: 70 }
            NumberAnimation { target: desplazar; property: "x"; to: -6;  duration: 70 }
            NumberAnimation { target: desplazar; property: "x"; to: 0;   duration: 60 }
        }

        // Candado con halo: rojo si la última contraseña falló
        Item {
            id: candado
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: EstiloPanel.e2
            implicitWidth: 64; implicitHeight: 64
            readonly property color tono: v.fallo ? Paleta.peligro : Paleta.acento
            RectangularShadow {
                anchors.fill: parent
                visible: EstiloPanel.profundidad
                radius: width / 2; blur: 28; spread: 2
                color: Qt.alpha(parent.tono, .45)
                Behavior on color { ColorAnimation { duration: EstiloPanel.normal } }
            }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.tint(EstiloPanel.elevada, Qt.alpha(candado.tono, .30)) }
                    GradientStop { position: 1; color: Qt.tint(EstiloPanel.elevada, Qt.alpha(candado.tono, .10)) }
                }
                border { width: 1; color: Qt.alpha(parent.tono, .6) }
                Behavior on border.color { ColorAnimation { duration: EstiloPanel.normal } }
            }
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF033E)   // candado
                color: Qt.lighter(parent.tono, 1.2)
                font { family: Paleta.fuente; pixelSize: 26 }
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Se necesita autorización"
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 20; bold: true }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: v.mensaje(v.flujo?.message)
            color: EstiloPanel.secundario
            font { family: Paleta.fuente; pixelSize: 13 }
        }

        // Quién autoriza
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: filaUsuario.implicitWidth + 2 * EstiloPanel.e3
            implicitHeight: 32; radius: height / 2
            color: EstiloPanel.relleno
            border { width: 1; color: EstiloPanel.borde }
            RowLayout {
                id: filaUsuario
                anchors.centerIn: parent
                spacing: EstiloPanel.e2
                Rectangle {
                    implicitWidth: 22; implicitHeight: 22; radius: height / 2
                    color: Qt.alpha(Paleta.acento, .2)
                    border { width: 1; color: Qt.alpha(Paleta.acento, .5) }
                    Text { anchors.centerIn: parent; text: v.nombreUsuario().charAt(0).toUpperCase(); color: Paleta.acento
                           font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                }
                Text { text: v.nombreUsuario(); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
            }
        }

        CampoPanel {
            id: clave
            Layout.topMargin: EstiloPanel.e1
            tinte: v.fallo ? Paleta.peligro : Paleta.acento
            enabled: !!v.flujo && v.flujo.isResponseRequired
            echoMode: v.flujo?.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            placeholderText: v.prompt(v.flujo?.inputPrompt)
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            onAccepted: v.enviar()
            Keys.onEscapePressed: v.abierto = false
            onTextChanged: if (text !== "") v.fallo = false
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: v.fallo ? "Contraseña incorrecta. Inténtalo de nuevo."
                : (v.flujo?.supplementaryMessage ?? "")
            color: v.fallo || v.flujo?.supplementaryIsError ? Paleta.peligro : EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 12; bold: v.fallo }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: EstiloPanel.e1
            spacing: EstiloPanel.e2
            BotonPanel { text: "Cancelar"; onClicked: v.abierto = false }
            BotonPanel {
                text: v.flujo && !v.flujo.isResponseRequired && !v.flujo.isCompleted ? "Comprobando…" : "Autorizar"
                destacado: true
                enabled: !!v.flujo && v.flujo.isResponseRequired && clave.text !== ""
                onClicked: v.enviar()
            }
        }
        Text {   // la acción exacta que se pide, para quien quiera saberlo
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            text: v.flujo?.actionId ?? ""
            color: EstiloPanel.apagado
            font { family: Paleta.mono; pixelSize: 11 }
        }
    }
}
