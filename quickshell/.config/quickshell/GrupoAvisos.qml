import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

ColumnLayout {
    id: grupo
    required property var datos
    spacing: 8
    readonly property bool expandido: Notificaciones.expandidos[datos.clave] === true
    readonly property var visibles: expandido ? datos.items : datos.items.filter((n,i) => i === 0 || n.urgency === NotificationUrgency.Critical)
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: (EstadoEscritorio.privacidad ? "Aplicación" : (grupo.datos.nombre + (grupo.datos.conversacion ? " · "+grupo.datos.conversacion : ""))) + " · " + grupo.datos.items.length; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
        BotonCompacto { visible: grupo.datos.items.length > 1; text: grupo.expandido ? "Contraer" : "Ver todas"; onClicked: Notificaciones.desplegar(grupo.datos.clave) }
        BotonCompacto { text: "×"; Accessible.name: "Descartar avisos de esta aplicación"; onClicked: { for (const n of grupo.datos.items.slice()) n.dismiss(); } }
    }
    Repeater {
        model: grupo.visibles
        NotiTarjeta { required property var modelData; Layout.fillWidth: true; noti: modelData }
    }
}
