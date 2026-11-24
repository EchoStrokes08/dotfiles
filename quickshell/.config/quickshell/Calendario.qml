// Calendario del mes, empezando en lunes. Las flechas (o la rueda del ratón) cambian de mes.
// Clic en un día = elegirlo (para crear un evento o tarea ese día; ver NuevoEvento.qml).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

ColumnLayout {
    id: cal
    property date hoy: new Date()
    property int desfase: 0          // meses respecto al actual (‹ resta, › suma)
    property date elegido: new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())
    property bool conMas: false      // muestra el ＋ (nuevo evento/tarea el día elegido) en la cabecera
    signal nuevo()
    spacing: 4

    readonly property date mes: new Date(hoy.getFullYear(), hoy.getMonth() + desfase, 1)
    // lunes = 0 … domingo = 6 (getDay() da domingo = 0)
    readonly property int hueco: (mes.getDay() + 6) % 7
    readonly property int dias: new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate()

    // Al cambiar de mes, la rejilla entra desde el lado hacia el que se avanza
    property int direccion: 0
    onDesfaseChanged: if (EstiloPanel.movimiento) entradaMes.restart()
    function mover(d) { direccion = d; desfase += d; }

    // Cabecera: ‹ noviembre 2026 ›
    RowLayout {
        Layout.fillWidth: true
        FlechaMes { glifo: "\u{f053}"; Accessible.name: "Mes anterior"; onPulsada: cal.mover(-1) }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cal.mes.toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy")
            color: Paleta.acento
            font { family: Paleta.fuente; pixelSize: 14; bold: true }
            MouseArea {   // clic = volver a hoy
                anchors.fill: parent
                onClicked: { cal.desfase = 0; cal.elegido = new Date(cal.hoy.getFullYear(), cal.hoy.getMonth(), cal.hoy.getDate()); }
            }
        }
        FlechaMes { glifo: "\u{f054}"; Accessible.name: "Mes siguiente"; onPulsada: cal.mover(1) }
        Rectangle {   // ＋ = nuevo evento o tarea el día elegido
            visible: cal.conMas
            Layout.leftMargin: 4
            implicitWidth: 22; implicitHeight: 22; radius: height / 2
            color: mas.containsMouse ? Paleta.acento : Qt.alpha(Paleta.acento, .18)
            Text {
                anchors.centerIn: parent
                text: "\uF067"
                color: mas.containsMouse ? Paleta.fondo : Paleta.acento
                font { family: Paleta.mono; pixelSize: 11; bold: true }
            }
            MouseArea { id: mas; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cal.nuevo() }
        }
    }

    GridLayout {
        id: rejilla
        columns: 7
        transform: Translate { id: deslizMes }
        ParallelAnimation {
            id: entradaMes
            NumberAnimation { target: deslizMes; property: "x"; from: 18 * cal.direccion; to: 0; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
            NumberAnimation { target: rejilla; property: "opacity"; from: .2; to: 1; duration: EstiloPanel.normal }
        }
        columnSpacing: 2
        rowSpacing: 2

        // L M X J V S D
        Repeater {
            model: ["L", "M", "X", "J", "V", "S", "D"]
            Text {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index >= 5 ? Paleta.acento2 : Paleta.gris
                font { family: Paleta.fuente; pixelSize: 11; bold: true }
            }
        }

        // huecos + días del mes
        Repeater {
            model: cal.hueco + cal.dias
            Rectangle {
                id: celda
                readonly property int dia: index - cal.hueco + 1
                readonly property bool esHoy: cal.desfase === 0 && dia === cal.hoy.getDate()
                readonly property date fecha: new Date(cal.mes.getFullYear(), cal.mes.getMonth(), dia)
                readonly property bool esElegido: dia > 0 && fecha.getTime() === cal.elegido.getTime()
                readonly property bool finde: index % 7 >= 5
                // qué hay ese día: un punto por tipo (eventos en acento2, tareas en éxito)
                readonly property var marcas: { Eventos.lista; Eventos.tareas; return dia > 0 ? Eventos.marcasEn(fecha) : ({}); }
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
                radius: EstiloPanel.rChip
                color: esHoy ? "transparent"
                     : esElegido ? EstiloPanel.seleccionado
                     : zonaDia.containsMouse && dia > 0 ? EstiloPanel.rellenoActivo : "transparent"
                border { width: esElegido && !esHoy ? 1 : 0; color: Qt.alpha(Paleta.acento, .8) }
                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }

                RectangularShadow {   // halo: fuerte en hoy, suave en el elegido
                    anchors.fill: parent; z: -1
                    visible: EstiloPanel.profundidad && (celda.esHoy || celda.esElegido)
                    radius: parent.radius; blur: celda.esHoy ? 16 : 12; spread: celda.esHoy ? 0 : -2
                    color: Qt.alpha(Paleta.acento, celda.esHoy ? .55 : .25)
                }
                Rectangle {   // hoy: pastilla con degradado del acento y filo de luz
                    visible: celda.esHoy
                    anchors.fill: parent; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(Paleta.acento, 1.18) }
                        GradientStop { position: 1; color: Paleta.acento }
                    }
                    Rectangle {
                        x: parent.radius * .7; y: 1
                        width: parent.width - parent.radius * 1.4; height: 1
                        color: Qt.alpha("white", .45)
                    }
                }
                MouseArea {
                    id: zonaDia
                    anchors.fill: parent
                    enabled: dia > 0
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: cal.elegido = parent.fecha
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: celda.marcas.eventos || celda.marcas.tareas ? -2 : 0
                    text: dia > 0 ? dia : ""
                    color: celda.esHoy ? Paleta.sobreAcento : celda.finde ? Qt.tint(Paleta.texto, Qt.alpha(Paleta.acento2, .35)) : Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 12; bold: celda.esHoy || celda.esElegido }
                }
                Row {   // puntos: hay algo fuera de la rutina diaria (eventos) o tareas con fecha
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
                    spacing: 2
                    Repeater {
                        model: [celda.marcas.eventos ? Paleta.acento2 : null, celda.marcas.tareas ? Paleta.exito : null].filter(c => c)
                        Item {
                            required property color modelData
                            width: 4; height: 4
                            RectangularShadow {
                                anchors.fill: parent
                                visible: EstiloPanel.profundidad && !celda.esHoy
                                radius: width / 2; blur: 4
                                color: Qt.alpha(parent.modelData, .8)
                            }
                            Rectangle {
                                anchors.fill: parent; radius: height / 2
                                color: celda.esHoy ? Paleta.sobreAcento : parent.modelData
                            }
                        }
                    }
                }
            }
        }
    }

    WheelHandler { onWheel: (e) => cal.mover(e.angleDelta.y > 0 ? -1 : 1) }
}
