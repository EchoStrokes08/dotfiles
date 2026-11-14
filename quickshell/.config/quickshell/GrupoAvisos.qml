// Un grupo de avisos (misma app o conversación). Plegado: una fila con la app, el número, el último
// asunto y la hora; clic o Enter lo despliega con las tarjetas completas (acciones y respuesta).
// Los críticos se ven siempre completos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

ColumnLayout {
    id: grupo
    required property var datos
    spacing: 8
    readonly property bool expandido: Notificaciones.expandidos[datos.clave] === true
    readonly property var ultimo: datos.items[0]
    readonly property var criticos: datos.items.filter(n => n.urgency === NotificationUrgency.Critical)
    readonly property string nombre: EstadoEscritorio.privacidad ? "Aplicación" : (datos.nombre + (datos.conversacion ? " · " + datos.conversacion : ""))
    readonly property string rutaIcono: EstadoEscritorio.privacidad || !ultimo ? "" : Notificaciones.icono(ultimo)

    // ── Plegado: una fila ────────────────────────────────────────────
    Rectangle {
        id: fila
        visible: !grupo.expandido
        Layout.fillWidth: true
        implicitHeight: 56
        radius: EstiloPanel.rTarjeta
        color: zona.containsMouse || fila.activeFocus ? EstiloPanel.rellenoActivo : EstiloPanel.superficie
        border { width: fila.activeFocus ? 2 : 1; color: fila.activeFocus ? Paleta.acento : EstiloPanel.borde }
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: grupo.nombre + ", " + grupo.datos.items.length + " avisos. Desplegar"
        Keys.onReturnPressed: Notificaciones.desplegar(grupo.datos.clave)
        Keys.onSpacePressed: Notificaciones.desplegar(grupo.datos.clave)
        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notificaciones.desplegar(grupo.datos.clave) }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
            spacing: 12
            Item {
                implicitWidth: 28; implicitHeight: 28
                IconImage { anchors.fill: parent; visible: grupo.rutaIcono !== ""; source: grupo.rutaIcono; asynchronous: true }
                Text { anchors.centerIn: parent; visible: grupo.rutaIcono === ""; text: grupo.nombre.charAt(0).toUpperCase(); color: Paleta.acento2; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: grupo.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                    Rectangle {
                        visible: grupo.datos.items.length > 1
                        implicitWidth: cuenta.implicitWidth + 12; implicitHeight: 18; radius: height / 2
                        color: EstiloPanel.elevada; border { width: 1; color: EstiloPanel.bordeFuerte }
                        Text { id: cuenta; anchors.centerIn: parent; text: grupo.datos.items.length; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                    }
                    Text { text: { Notificaciones.pulso; return grupo.ultimo ? Notificaciones.haceCuanto(grupo.ultimo) : ""; } color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: EstadoEscritorio.privacidad ? "Contenido oculto" : (grupo.ultimo?.summary || grupo.ultimo?.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                    color: EstiloPanel.secundario; font { family: Paleta.fuente; pixelSize: 13 }
                }
            }
            BotonCompacto {
                text: "×"
                implicitWidth: 32; leftPadding: 0; rightPadding: 0
                Accessible.name: "Descartar avisos de " + grupo.nombre
                onClicked: { for (const n of grupo.datos.items.slice()) n.dismiss(); }
            }
        }
    }
    // Los críticos no se esconden nunca
    Repeater {
        model: grupo.expandido ? [] : grupo.criticos
        NotiTarjeta { required property var modelData; Layout.fillWidth: true; noti: modelData }
    }

    // ── Desplegado: cabecera y tarjetas completas ────────────────────
    RowLayout {
        visible: grupo.expandido
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: grupo.nombre + " · " + grupo.datos.items.length; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
        BotonCompacto { text: "Plegar"; onClicked: Notificaciones.desplegar(grupo.datos.clave) }
        BotonCompacto { text: "×"; Accessible.name: "Descartar avisos de esta aplicación"; onClicked: { for (const n of grupo.datos.items.slice()) n.dismiss(); } }
    }
    Repeater {
        model: grupo.expandido ? grupo.datos.items : []
        NotiTarjeta { required property var modelData; Layout.fillWidth: true; noti: modelData }
    }
}
