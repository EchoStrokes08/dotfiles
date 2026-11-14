// La caché sigue siendo útil sin red, pero nunca se presenta como recién sincronizada.
import QtQuick
import QtQuick.Layouts

RowLayout {
    spacing: 8
    readonly property bool problema: Eventos.estadoAgenda === "error" || Eventos.estadoAgenda === "desactualizado"
    readonly property string ultima: Eventos.sincronizadoEn
        ? new Date(Eventos.sincronizadoEn * 1000).toLocaleString(Qt.locale("es_ES"), "d MMM HH:mm") : ""
    Text {
        Layout.fillWidth: true
        text: Eventos.errorTareas ? Eventos.errorTareas : Eventos.leyendo ? "Sincronizando agenda…" + (ultima ? " · última: " + ultima : "")
            : Eventos.estadoAgenda === "sin_configurar" ? "Agenda sin configurar"
            : Eventos.estadoAgenda === "error" ? Eventos.errorAgenda + (ultima ? " · última: " + ultima : "")
            : Eventos.estadoAgenda === "desactualizado" ? "Agenda sin actualizar · última sincronización: " + ultima
            : "Agenda actualizada · " + ultima
        wrapMode: Text.Wrap
        color: parent.problema || Eventos.errorTareas ? Paleta.aviso : EstiloPanel.tenue
        font { family: Paleta.fuente; pixelSize: 12 }
        Accessible.name: text
    }
    BotonCompacto {
        text: Eventos.leyendo ? "Sincronizando…" : parent.problema || Eventos.errorTareas ? "Reintentar" : "Actualizar"
        enabled: !Eventos.leyendo && Eventos.estadoAgenda !== "sin_configurar"
        onClicked: Eventos.actualizar()
    }
}
