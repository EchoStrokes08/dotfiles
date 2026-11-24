// Salud: una jerarquía común, métricas sobrias y atención solo donde hace falta.
import QtQuick
import QtQuick.Effects
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
                    {nombre:"Procesador",valor:Math.round(Sistema.cpu*100)+"%",uso:Sistema.cpu,detalle:"Carga actual",alerta:Sistema.cpu>.85,critico:Sistema.cpu>.95},
                    {nombre:"Memoria",valor:Math.round(Sistema.ram*100)+"%",uso:Sistema.ram,detalle:"RAM en uso",alerta:Sistema.ram>.85,critico:Sistema.ram>.95},
                    {nombre:"Temperatura",valor:Math.round(Sistema.temp)+"°",uso:Sistema.temp/100,detalle:"Del procesador",alerta:Sistema.temp>=80,critico:Sistema.temp>=90},
                    {nombre:"Batería",valor:salud.carga>=0 ? Math.round(salud.carga)+"%" : "—",uso:Math.max(0,salud.carga)/100,detalle:UPower.onBattery ? "Con batería" : "Conectado a corriente",alerta:salud.carga>=0 && salud.carga<=15,critico:salud.carga>=0 && salud.carga<=5}
                ]
                // Sobrias mientras todo va bien; una métrica en alerta se enciende sola (diseno.md: el color es para estados)
                TarjetaPanel {
                    id: metrica
                    required property var modelData
                    readonly property color tono: modelData.critico ? Paleta.peligro : Paleta.aviso
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 104
                    relleno: 12
                    espaciado: 4
                    acento: modelData.alerta ? tono : Paleta.texto
                    border.color: modelData.alerta ? Qt.alpha(tono, .45) : EstiloPanel.borde
                    RectangularShadow {   // halo de alerta alrededor de la tarjeta
                        parent: metrica; anchors.fill: parent; z: -2
                        visible: EstiloPanel.profundidad && metrica.modelData.alerta
                        radius: metrica.radius; blur: 24; spread: -4
                        color: Qt.alpha(metrica.tono, .30)
                    }
                    Text { text: metrica.modelData.nombre; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    Text { text: metrica.modelData.valor; color: metrica.modelData.alerta ? metrica.tono : Paleta.texto; font { family: Paleta.fuente; pixelSize: 26; bold: true; features: { "tnum": 1 } } }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        readonly property real fraccion: Math.min(1, Math.max(0, metrica.modelData.uso))
                        Rectangle { anchors.fill: parent; radius: height / 2; color: EstiloPanel.borde }
                        RectangularShadow {
                            width: barraUso.width; height: parent.height
                            visible: EstiloPanel.profundidad && metrica.modelData.alerta
                            radius: height / 2; blur: 10
                            color: Qt.alpha(metrica.tono, .6)
                        }
                        Rectangle {
                            id: barraUso
                            width: Math.max(height, parent.width * parent.fraccion); height: parent.height; radius: height / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: metrica.modelData.alerta ? Qt.alpha(metrica.tono, .55) : Qt.alpha(Paleta.texto, .14) }
                                GradientStop { position: 1; color: metrica.modelData.alerta ? Qt.lighter(metrica.tono, 1.12) : Qt.alpha(Paleta.texto, .42) }
                            }
                            Behavior on width { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {   // punta: un punto de luz al final del relleno
                            width: 8; height: 8; radius: height / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: barraUso.width - width / 2 - 1
                            color: metrica.modelData.alerta ? Qt.lighter(metrica.tono, 1.4) : Qt.alpha(Paleta.texto, .7)
                            border { width: 1; color: Qt.alpha("white", .35) }
                        }
                    }
                    Text { text: metrica.modelData.detalle; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                }
            }
        }
        // Almacenamiento del SSD: qué ocupa y cómo recuperarlo (Almacenamiento.qml)
        Almacenamiento {
            Layout.fillWidth: true
            onEjecutar: (comando) => salud.ejecutar(comando)
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
