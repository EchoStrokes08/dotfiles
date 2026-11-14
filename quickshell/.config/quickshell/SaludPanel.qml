// Salud: una jerarquía común, métricas sobrias y atención solo donde hace falta.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Services.UPower

Flickable {
    id: salud
    property var datos: null
    property bool todas: false
    property bool mantenimiento: false
    signal revisar()
    signal ejecutar(var comando)
    signal actualizarSistema()
    signal deshacerActualizacion()
    readonly property var alertas: (datos?.comprobaciones ?? []).filter(c => c.estado === "mal" || c.estado === "aviso")
    readonly property var rutina: (datos?.comprobaciones ?? []).filter(c => c.estado !== "mal" && c.estado !== "aviso")
    readonly property var bat: UPower.displayDevice
    readonly property real carga: bat ? (bat.percentage > 1 ? bat.percentage : bat.percentage*100) : -1
    contentHeight: contenido.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { }

    component Comprobacion: Rectangle {
        id: fila
        required property var dato
        readonly property bool atencion: dato.estado === "mal" || dato.estado === "aviso"
        readonly property color tono: dato.estado === "mal" ? Paleta.peligro : Paleta.aviso
        Layout.fillWidth: true
        implicitHeight: interior.implicitHeight + 24
        radius: EstiloPanel.rTarjeta
        color: EstiloPanel.superficie
        border { width: 1; color: EstiloPanel.borde }
        RowLayout {
            id: interior
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 12
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 36; implicitHeight: 36; radius: EstiloPanel.rControl
                color: EstiloPanel.elevada
                Text { anchors.centerIn: parent; text: String.fromCodePoint(parseInt(fila.dato.glifo || "f05e0",16)); color: fila.atencion ? fila.tono : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: fila.dato.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                    Text { text: fila.dato.valor; color: fila.atencion ? fila.tono : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12; bold: fila.atencion } }
                }
                Text { Layout.fillWidth: true; text: fila.dato.detalle; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
            }
            BotonCompacto { visible: !!fila.dato.accion; text: fila.dato.accion?.texto ?? ""; onClicked: salud.ejecutar(fila.dato.accion.cmd) }
        }
    }

    ColumnLayout {
        id: contenido
        width: parent.width
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { text: !salud.datos ? "Revisando tu equipo…" : salud.alertas.length ? "Tu equipo necesita atención" : "Tu equipo está en orden"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20; bold: true } }
                Text { text: !salud.datos ? "Recopilando las comprobaciones" : salud.alertas.length ? salud.alertas.length + " avisos · " + salud.rutina.length + " comprobaciones sin alertas" : "Sin alertas en las comprobaciones disponibles"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
            }
            BotonCompacto { text: "Revisar"; onClicked: salud.revisar() }
            BotonCompacto { text: "Mantenimiento"; onClicked: salud.mantenimiento = !salud.mantenimiento }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: salud.width >= 650 ? 4 : 2
            columnSpacing: 12; rowSpacing: 12
            Repeater {
                model: [
                    {nombre:"Procesador",valor:Math.round(Sistema.cpu*100)+"%",uso:Sistema.cpu,detalle:"Carga actual",alerta:Sistema.cpu>.85},
                    {nombre:"Memoria",valor:Math.round(Sistema.ram*100)+"%",uso:Sistema.ram,detalle:"RAM en uso",alerta:Sistema.ram>.85},
                    {nombre:"Temperatura",valor:Math.round(Sistema.temp)+"°",uso:Sistema.temp/100,detalle:"Del procesador",alerta:Sistema.temp>=80},
                    {nombre:"Batería",valor:salud.carga>=0 ? Math.round(salud.carga)+"%" : "—",uso:Math.max(0,salud.carga)/100,detalle:UPower.onBattery ? "Con batería" : "Conectado a corriente",alerta:salud.carga>=0 && salud.carga<=15}
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 104
                    radius: EstiloPanel.rTarjeta
                    color: EstiloPanel.superficie
                    border { width: 1; color: EstiloPanel.borde }
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 4
                        Text { text: modelData.nombre; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                        Text { text: modelData.valor; color: modelData.alerta ? Paleta.aviso : Paleta.texto; font { family: Paleta.fuente; pixelSize: 26; bold: true } }
                        Rectangle {
                            Layout.fillWidth: true; height: 4; radius: 4; color: EstiloPanel.borde
                            Rectangle { width: parent.width*Math.min(1,Math.max(0,modelData.uso)); height: 4; radius: 4; color: modelData.alerta ? Paleta.aviso : Qt.alpha(Paleta.texto,.35) }
                        }
                        Text { text: modelData.detalle; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                    }
                }
            }
        }
        TarjetaPanel {
            Layout.fillWidth: true
            visible: salud.mantenimiento
            relleno: 12
            Text { Layout.fillWidth: true; text: salud.datos?.ultima_actualizacion ? "Última actualización: " + salud.datos.ultima_actualizacion.paquetes + " paquetes" : "Actualiza con revisión previa y punto de recuperación."; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
            RowLayout {
                BotonCompacto { text: "Actualizar con seguridad"; onClicked: salud.actualizarSistema() }
                BotonCompacto { visible: !!salud.datos?.ultima_actualizacion?.pre; text: "Deshacer última actualización"; onClicked: salud.deshacerActualizacion() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Necesita atención"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            Text { text: "· " + salud.alertas.length; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
        }
        Text { visible: salud.datos && !salud.alertas.length; text: "Puedes seguir con tu día. No hay acciones pendientes en esta revisión."; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
        Repeater { model: salud.alertas; Comprobacion { required property var modelData; dato: modelData } }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Revisiones de rutina · " + salud.rutina.length; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            BotonCompacto { text: salud.todas ? "Mostrar menos" : "Ver todas"; onClicked: salud.todas = !salud.todas }
        }
        Repeater { model: salud.todas ? salud.rutina : salud.rutina.slice(0,2); Comprobacion { required property var modelData; dato: modelData } }
    }
}
