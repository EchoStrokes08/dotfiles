// Una notificación: línea de color según urgencia, icono o imagen, texto, acciones y cerrar.
// La usan las emergentes y el historial del centro de control.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: tarjeta
    required property var noti
    property bool emergente: false           // en emergentes: fondo más opaco y temporizador
    signal terminada()                       // la emergente ya cumplió su tiempo

    readonly property color colorUrgencia: noti.urgency === NotificationUrgency.Critical ? Paleta.rojo
                                         : noti.urgency === NotificationUrgency.Low ? Paleta.gris
                                         : Paleta.naranja
    readonly property string rutaIcono: Notificaciones.icono(noti)

    implicitHeight: contenido.implicitHeight + 24
    radius: 12
    color: emergente ? Qt.alpha(Paleta.fondo, 0.92)
         : zona.containsMouse ? Qt.alpha(Paleta.texto, 0.07) : Qt.alpha(Paleta.texto, 0.04)
    border { width: emergente ? 1 : 0; color: Qt.alpha(tarjeta.colorUrgencia, 0.45) }
    Behavior on color { ColorAnimation { duration: 120 } }

    // Temporizador de la emergente (se pausa con el ratón encima)
    Timer {
        id: tiempo
        interval: Notificaciones.duracion(tarjeta.noti)
        running: tarjeta.emergente && interval > 0 && !zona.containsMouse
        onTriggered: tarjeta.terminada()
    }

    // Línea de urgencia a la izquierda
    Rectangle {
        width: 3; radius: 2
        anchors { left: parent.left; leftMargin: 6; top: parent.top; bottom: parent.bottom; topMargin: 12; bottomMargin: 12 }
        color: tarjeta.colorUrgencia
    }

    // Clic en la tarjeta = acción por defecto (si la hay)
    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            const def = Array.from(tarjeta.noti.actions).find(a => a.identifier === "default");
            if (def) { def.invoke(); if (!tarjeta.noti.resident) tarjeta.noti.dismiss(); }
            else if (tarjeta.emergente) tarjeta.terminada();
        }
    }

    RowLayout {
        id: contenido
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 18 }
        spacing: 12

        // Imagen de la notificación (p. ej. foto de contacto) o icono de la app
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 44; implicitHeight: 44
            radius: 10
            color: Qt.alpha(Paleta.texto, 0.06)
            visible: imagen.source != "" || tarjeta.rutaIcono !== ""
            Image {
                id: imagen
                anchors.fill: parent
                source: tarjeta.noti.image || tarjeta.rutaIcono
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize { width: 88; height: 88 }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: tarjeta.noti.appName || "Aviso"
                    color: tarjeta.colorUrgencia
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 0.5; capitalization: Font.AllUppercase }
                }
                Text {
                    text: { Notificaciones.pulso; return Notificaciones.haceCuanto(tarjeta.noti); }
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 10 }
                }
                // Cerrar
                Text {
                    text: ""
                    color: cerrar.containsMouse ? Paleta.rojo : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 12 }
                    MouseArea { id: cerrar; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: tarjeta.noti.dismiss() }
                }
            }
            Text {
                Layout.fillWidth: true
                text: tarjeta.noti.summary
                color: Paleta.texto
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font { family: Paleta.fuente; pixelSize: 13; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: tarjeta.noti.body
                textFormat: Text.StyledText          // <b>, <i>, enlaces
                color: Qt.alpha(Paleta.texto, 0.8)
                linkColor: Paleta.azul
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
                spacing: 6
                visible: botones.count > 0
                Repeater {
                    id: botones
                    model: Array.from(tarjeta.noti.actions).filter(a => a.identifier !== "default")
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 7
                        color: zonaAccion.containsMouse ? Qt.alpha(Paleta.naranja, 0.25) : Qt.alpha(Paleta.texto, 0.07)
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
                            // guardar la noti ANTES de invocar: la acción puede cerrarla y destruir esta tarjeta
                            onClicked: { const n = tarjeta.noti, residente = n.resident; modelData.invoke(); if (!residente && n) n.dismiss(); }
                        }
                    }
                }
            }
        }
    }
}
