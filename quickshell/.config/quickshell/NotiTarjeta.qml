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
    signal terminada()                       // la emergente ya cumplió su tiempo

    readonly property color colorUrgencia: noti.urgency === NotificationUrgency.Critical ? Paleta.peligro
                                         : noti.urgency === NotificationUrgency.Low ? Paleta.gris
                                         : Paleta.acento
    readonly property string rutaIcono: EstadoEscritorio.privacidad ? "" : Notificaciones.icono(noti)

    implicitHeight: contenido.implicitHeight + 24
    radius: 16
    color: emergente ? "transparent"
         : zona.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
    border { width: emergente ? 0 : 1; color: zona.containsMouse ? Qt.alpha(tarjeta.colorUrgencia, .3) : EstiloPanel.borde }
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
            const def = Array.from(tarjeta.noti.actions).find(a => a.identifier === "default");
            if (def) { def.invoke(); if (!tarjeta.noti.resident) tarjeta.noti.dismiss(); }
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
                    text: EstadoEscritorio.privacidad ? "Aplicación" : tarjeta.noti.appName || "Aviso"
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
                Text {
                    text: ""
                    color: cerrar.containsMouse ? Paleta.peligro : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 12 }
                    MouseArea { id: cerrar; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: tarjeta.noti.dismiss() }
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
                visible: !EstadoEscritorio.privacidad && (botones.count > 0 || tarjeta.noti.hasInlineReply)
                // Respuesta en línea (p. ej. WhatsApp del móvil por KDE Connect): se escribe en el panel del móvil
                Rectangle {
                    visible: tarjeta.noti.hasInlineReply
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 12
                    color: zonaResp.containsMouse ? Qt.alpha(Paleta.exito, 0.3) : Qt.alpha(Paleta.exito, 0.14)
                    border { width: 1; color: Qt.alpha(Paleta.exito, .4) }
                    Text {
                        anchors.centerIn: parent
                        text: "\u{F0451}  Responder"
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 11; bold: true }
                    }
                    MouseArea {
                        id: zonaResp
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Notificaciones.responder(tarjeta.noti)
                    }
                }
                Repeater {
                    id: botones
                    model: Array.from(tarjeta.noti.actions).filter(a => a.identifier !== "default")
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 12
                        color: zonaAccion.containsMouse ? Qt.alpha(Paleta.acento, 0.25) : EstiloPanel.rellenoActivo
                        border { width: 1; color: zonaAccion.containsMouse ? Qt.alpha(Paleta.acento, .5) : EstiloPanel.borde }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Paleta.texto
                            font { family: Paleta.fuente; pixelSize: 11; bold: true }
                        }
                        MouseArea {
                            id: zonaAccion
                            anchors.fill: parent
                            hoverEnabled: true
                            // invoke() ya cierra la notificación si no es «residente»: cerrarla otra vez
                            // daba «Cannot close destroyed notification» (y antes, ReferenceError: tarjeta)
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
