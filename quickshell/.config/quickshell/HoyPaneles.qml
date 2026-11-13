// HoyPaneles: la fila de tarjetas de Brújula › Hoy.
//   Calendario con «Próximo» (eventos, recordatorios, tareas) · anillos del sistema · tiempo de pantalla
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

RowLayout {
    id: paneles
    spacing: 12

    readonly property var bateria: UPower.displayDevice
    // percentage puede venir de 0 a 1 o de 0 a 100 según la versión: se normaliza
    readonly property real carga: bateria ? (bateria.percentage > 1 ? bateria.percentage / 100 : bateria.percentage) : 0
    readonly property bool cargando: bateria?.state === UPowerDeviceState.Charging

    TarjetaPanel {
        Layout.fillHeight: true
        Layout.preferredWidth: 262
        // El formulario «nuevo evento/tarea» se abre ENCIMA del calendario (no agranda la tarjeta)
        Item {
            Layout.fillWidth: true
            implicitWidth: columnaCal.implicitWidth
            implicitHeight: columnaCal.implicitHeight
            ColumnLayout {
                id: columnaCal
                anchors { left: parent.left; right: parent.right }
                spacing: 4
                Calendario {
                    id: calendario
                    conMas: Eventos.hayCliente
                    onNuevo: formulario.abrir()
                }
                // Próximo: eventos de Google Calendar + recordatorios + tareas
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    readonly property var items: [
                        ...Eventos.proximos(4).map(e => ({ cuando: Eventos.cuando(e), texto: e.titulo, ms: e.inicio.getTime(), rec: null })),
                        ...Recordatorios.lista.slice(0, 3).map(r => ({ cuando: "⏰ " + Recordatorios.cuandoTexto(r.cuando).split(" · ")[0], texto: r.texto, ms: r.cuando, rec: r.id })),
                        // tareas: las vencidas o sin fecha cuentan como de hoy
                        ...Eventos.tareas.slice(0, 3).map(t => ({ cuando: "☐ " + (t.fecha ? Eventos.diaTexto(t.fecha < new Date() ? new Date() : t.fecha).split(" ").slice(0, 2).join(" ") : "tarea"),
                            texto: t.titulo, ms: t.fecha ? Math.max(t.fecha.getTime(), Date.now() - 1) : Date.now() - 1, tarea: t.id }))
                    ].sort((a, b) => a.ms - b.ms).slice(0, 4)
                    visible: items.length > 0
                    Etiqueta { text: "PRÓXIMO"; color: Paleta.acento }
                    Repeater {
                        model: parent.items
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: modelData.cuando
                                color: modelData.rec ? Paleta.serie[4] : modelData.tarea ? Paleta.exito : Paleta.acento2
                                font { family: Paleta.fuente; pixelSize: 11; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.texto
                                elide: Text.ElideRight
                                color: Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 11 }
                                MouseArea {   // clic en un recordatorio = borrarlo · en una tarea = marcarla hecha
                                    anchors.fill: parent
                                    enabled: !!modelData.rec || !!modelData.tarea
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: modelData.tarea ? Eventos.completar(modelData.tarea) : Recordatorios.borrar(modelData.rec)
                                }
                            }
                        }
                    }
                }
            }
            // Crear evento/tarea en Google (el día elegido en el calendario)
            NuevoEvento {
                id: formulario
                anchors.fill: parent
                anchors.margins: -8
                fecha: calendario.elegido
            }
        }
    }

    TarjetaPanel {
        Layout.fillHeight: true
        Item { Layout.fillHeight: true }
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            columnSpacing: 16
            rowSpacing: 12
            Anillo {
                valor: Sistema.cpu; color: Paleta.acento2
                etiqueta: "CPU"; texto: Math.round(Sistema.cpu * 100) + "%"
            }
            Anillo {
                valor: Sistema.ram; color: Paleta.acento2
                etiqueta: "RAM"; texto: Math.round(Sistema.ram * 100) + "%"
            }
            Anillo {
                // 30 °C = vacío, 95 °C = lleno; peligro a partir de 80
                valor: (Sistema.temp - 30) / 65
                color: Sistema.temp >= 80 ? Paleta.peligro : Paleta.acento2
                etiqueta: "TEMP"; texto: Math.round(Sistema.temp) + "°"
            }
            Anillo {
                valor: paneles.carga
                color: paneles.cargando ? Paleta.exito : paneles.carga < 0.2 ? Paleta.peligro : Paleta.acento2
                etiqueta: paneles.cargando ? " BAT" : "BAT"
                texto: Math.round(paneles.carga * 100) + "%"
            }
        }
        Item { Layout.fillHeight: true }
    }

    TarjetaPanel {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Tiempo {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
        }
        Item { Layout.fillHeight: true }
    }
}
