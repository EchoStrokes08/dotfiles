// Una notificación: línea de color según urgencia, icono o imagen, texto, acciones y cerrar.
// La usan las emergentes y el historial del centro de control.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: tarjeta
    required property var noti
    property bool emergente: false           // en emergentes: fondo más opaco y temporizador
    readonly property var accionPrincipal: Array.from(noti.actions).find(a => a.identifier === "default")
    activeFocusOnTab: !emergente && !EstadoEscritorio.privacidad && !!accionPrincipal
    Accessible.name: EstadoEscritorio.privacidad ? "Notificación privada" : noti.summary
    Keys.onReturnPressed: if (!EstadoEscritorio.privacidad && accionPrincipal) accionPrincipal.invoke()
    Keys.onEnterPressed: if (!EstadoEscritorio.privacidad && accionPrincipal) accionPrincipal.invoke()
    property bool editando: false
    function finalizarRespuesta(enviar) {
        const texto = campo.text.trim();
        if (enviar && (!texto || EstadoEscritorio.privacidad || !noti.hasInlineReply)) return;
        editando = false;
        campo.clear();
        if (responder.visible) responder.forceActiveFocus(Qt.TabFocusReason);
        if (enviar) noti.sendInlineReply(texto);
    }
    Connections {
        target: EstadoEscritorio
        function onPrivacidadChanged() { if (EstadoEscritorio.privacidad && tarjeta.editando) tarjeta.finalizarRespuesta(false); }
    }
    signal terminada()                       // la emergente ya cumplió su tiempo

    readonly property color colorUrgencia: noti.urgency === NotificationUrgency.Critical ? Paleta.peligro
                                         : noti.urgency === NotificationUrgency.Low ? Paleta.gris
                                         : Paleta.acento
    readonly property string rutaIcono: EstadoEscritorio.privacidad ? "" : Notificaciones.icono(noti)

    implicitHeight: contenido.implicitHeight + 24
    radius: 16
    color: emergente ? "transparent"
         : zona.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
    border { width: activeFocus ? 2 : emergente ? 0 : 1; color: activeFocus ? Paleta.acento : zona.containsMouse ? Qt.alpha(tarjeta.colorUrgencia, .3) : EstiloPanel.borde }
    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }

    // Emergente: el mismo cristal que los paneles, con la luz del color de urgencia
    FondoPanel {
        visible: tarjeta.emergente
        anchors.fill: parent
        radio: 16
        acento: tarjeta.colorUrgencia
    }

    // Temporizador de la emergente (se pausa con el ratón encima)
    Timer {
        id: tiempo
        interval: Notificaciones.duracion(tarjeta.noti)
        running: tarjeta.emergente && interval > 0 && !zona.containsMouse
        onTriggered: tarjeta.terminada()
    }

    // Línea de urgencia a la izquierda: solo en las críticas (el color se reserva para estados)
    Rectangle {
        visible: tarjeta.noti.urgency === NotificationUrgency.Critical
        width: 3; radius: 4
        anchors { left: parent.left; leftMargin: 4; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
        color: tarjeta.colorUrgencia
    }

    // Clic en la tarjeta = acción por defecto (si la hay)
    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (EstadoEscritorio.privacidad) return;
            if (tarjeta.accionPrincipal) tarjeta.accionPrincipal.invoke();
            else if (tarjeta.emergente) tarjeta.terminada();
        }
    }

    RowLayout {
        id: contenido
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 16 }
        spacing: 12

        // Imagen de la notificación (p. ej. foto de contacto) o icono de la app
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 46; implicitHeight: 46
            radius: 16
            color: EstiloPanel.rellenoActivo
            visible: imagen.source != "" || tarjeta.rutaIcono !== ""
            Image {
                id: imagen
                anchors.fill: parent
                source: EstadoEscritorio.privacidad ? "" : tarjeta.noti.image || tarjeta.rutaIcono
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize { width: 88; height: 88 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: EstadoEscritorio.privacidad ? "Aplicación" : Notificaciones.nombreApp(tarjeta.noti) || "Aviso"
                    color: tarjeta.noti.urgency === NotificationUrgency.Critical ? Paleta.peligro : EstiloPanel.tenue
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 0.5; capitalization: Font.AllUppercase }
                }
                Text {
                    text: { Notificaciones.pulso; return Notificaciones.haceCuanto(tarjeta.noti); }
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
                // Cerrar
                BotonCompacto {
                    text: "×"
                    Accessible.name: "Descartar aviso"
                    implicitWidth: 30; implicitHeight: 30
                    leftPadding: 0; rightPadding: 0
                    onClicked: tarjeta.noti.dismiss()
                }
            }
            Text {
                Layout.fillWidth: true
                text: EstadoEscritorio.privacidad ? "Notificación privada" : tarjeta.noti.summary
                color: Paleta.texto
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font { family: Paleta.fuente; pixelSize: 13; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: EstadoEscritorio.privacidad ? "" : tarjeta.noti.body
                textFormat: Text.StyledText          // <b>, <i>, enlaces
                color: EstiloPanel.secundario
                linkColor: Paleta.acento2
                wrapMode: Text.Wrap
                maximumLineCount: tarjeta.emergente ? 4 : 3
                elide: Text.ElideRight
                font { family: Paleta.fuente; pixelSize: 12 }
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            // Botones de acción (los que no son "default")
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4
                visible: !tarjeta.editando && !EstadoEscritorio.privacidad && (botones.count > 0 || tarjeta.noti.hasInlineReply)
                // En el centro se responde en la tarjeta; la emergente abre el compositor de respuestas.
                BotonCompacto {
                    id: responder
                    visible: tarjeta.noti.hasInlineReply && !tarjeta.editando
                    Layout.fillWidth: true
                    text: "Responder"
                    onClicked: {
                        if (tarjeta.emergente) Notificaciones.responder(tarjeta.noti);
                        else { tarjeta.editando = true; campo.forceActiveFocus(); }
                    }
                }
                Repeater {
                    id: botones
                    model: Array.from(tarjeta.noti.actions).filter((a, i, acciones) =>
                        a.identifier !== "default" &&
                        !(tarjeta.noti.hasInlineReply && a.identifier === "inline-reply") &&
                        acciones.findIndex(x => x.identifier === a.identifier) === i)
                    BotonCompacto {
                        required property var modelData
                        Layout.fillWidth: true
                        visible: !tarjeta.editando
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
            RowLayout {
                visible: tarjeta.editando && !EstadoEscritorio.privacidad && tarjeta.noti.hasInlineReply
                Layout.fillWidth: true
                CampoPanel {
                    id: campo
                    Layout.fillWidth: true
                    placeholderText: "Escribe tu respuesta"
                    onAccepted: tarjeta.finalizarRespuesta(true)
                    Keys.onEscapePressed: tarjeta.finalizarRespuesta(false)
                }
                BotonCompacto { text: "Enviar"; enabled: campo.text.trim().length > 0; onClicked: tarjeta.finalizarRespuesta(true) }
                BotonCompacto { text: "Cancelar"; onClicked: tarjeta.finalizarRespuesta(false) }
            }
        }
    }
}
