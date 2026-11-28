// Reloj, clima y agenda sobre el wallpaper del espacio vacío.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: escena
    required property date ahora
    required property var frase
    required property var agenda
    property var clima: null

    readonly property bool compacto: width < 720 || height < 480
    readonly property real margen: compacto ? EstiloPanel.e5 : width >= 1440 ? 56 : 40
    readonly property color claro: Paleta.sobreImagen
    readonly property color tenue: Qt.alpha(claro, .84)
    // Al aclarar los acentos de un tema claro, conservan contraste sobre el velo oscuro.
    readonly property color luz: Qt.tint(Paleta.acento, Qt.alpha(claro, EstiloPanel.fondoClaro ? .58 : .24))
    readonly property color reflejo: Qt.tint(Paleta.acento2, Qt.alpha(claro, EstiloPanel.fondoClaro ? .58 : .24))
    readonly property int hora: ahora.getHours()
    readonly property string nombre: Quickshell.env("USER") ?? ""
    readonly property string saludo: hora >= 5 && hora < 12 ? "Buenos días"
        : hora >= 12 && hora < 20 ? "Buenas tardes" : hora < 5 ? "Ya es tarde" : "Buenas noches"
    readonly property string fecha: ahora.toLocaleDateString(Qt.locale("es_CO"), "dddd, d 'de' MMMM")

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(parent.height, contenido.height + escena.margen * 2 + parent.height * .18)
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: .42; color: Qt.alpha("black", .59) }
            GradientStop { position: 1; color: Qt.alpha("black", .82) }
        }
    }

    GridLayout {
        id: contenido
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: escena.margen; rightMargin: escena.margen; bottomMargin: escena.margen }
        columns: escena.width >= 720 ? 2 : 1
        columnSpacing: 32
        rowSpacing: 16

        ColumnLayout {
            id: izquierda
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignBottom
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Glifo {
                    text: String.fromCodePoint(escena.hora >= 6 && escena.hora < 18 ? 0xF0599 : 0xF0594)
                    color: escena.luz
                    alto: 20
                    font.pixelSize: 16
                }
                Text {
                    Layout.preferredWidth: implicitWidth
                    Layout.maximumWidth: Math.max(1, izquierda.width - 32)
                    text: escena.fecha.charAt(0).toUpperCase() + escena.fecha.slice(1)
                    elide: Text.ElideRight
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: escena.compacto ? 14 : 20; weight: Font.DemiBold }
                }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    visible: !escena.compacto && izquierda.width >= 460
                    text: "·  " + escena.saludo + (escena.nombre ? ", " + escena.nombre.charAt(0).toUpperCase() + escena.nombre.slice(1) : "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: escena.tenue
                    font { family: Paleta.fuente; pixelSize: 13 }
                }
            }

            Row {
                spacing: 4
                Accessible.name: Qt.formatTime(escena.ahora, "HH:mm")
                readonly property int cifra: escena.width < 420 ? 44 : escena.compacto ? 62 : escena.width >= 1440 ? 150 : 104

                Repeater {
                    model: [Qt.formatTime(escena.ahora, "HH"), ":", Qt.formatTime(escena.ahora, "mm")]
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        color: index === 0 ? escena.claro : index === 1 ? escena.tenue : escena.reflejo
                        font { family: Paleta.fuente; pixelSize: parent.cifra; weight: Font.Bold; letterSpacing: -2 }
                        topPadding: -Math.round(font.pixelSize * .17)
                        bottomPadding: -Math.round(font.pixelSize * .15)
                    }
                }
            }

            Rectangle {
                implicitWidth: 80
                implicitHeight: 2
                radius: EstiloPanel.rPunto
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: escena.luz }
                    GradientStop { position: 1; color: escena.reflejo }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                visible: !!escena.clima

                Glifo { text: escena.clima?.icono ?? ""; alto: 20; color: escena.luz; font.pixelSize: 16 }
                Text {
                    text: escena.clima?.grados ?? ""
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: 16; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: escena.clima?.detalle ?? ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: escena.tenue
                    font { family: Paleta.fuente; pixelSize: 13 }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 460
                Layout.topMargin: 12
                visible: escena.height >= 480 && !!escena.frase?.[0]
                text: escena.frase ? "«" + escena.frase[0] + "»" : ""
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: escena.claro
                font { family: Paleta.fuente; pixelSize: 16; italic: true }
            }
            Text {
                Layout.fillWidth: true
                visible: escena.height >= 480 && !!escena.frase?.[1]
                text: escena.frase?.[1] ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: escena.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }

        Item {
            Layout.fillWidth: contenido.columns === 1
            Layout.preferredWidth: 336
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignBottom | Qt.AlignRight
            implicitHeight: lista.implicitHeight + 2 * EstiloPanel.e4
            visible: escena.agenda.length > 0

            FondoPanel {
                anchors.fill: parent
                radio: EstiloPanel.rTarjeta
                opacidad: 1
            }

            ColumnLayout {
                id: lista
                anchors { left: parent.left; top: parent.top; right: parent.right; margins: 16 }
                spacing: 12

                Text {
                    Layout.fillWidth: true
                    text: "Lo próximo"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 16; weight: Font.DemiBold }
                }

                Repeater {
                    model: escena.agenda.slice(0, escena.compacto ? escena.height < 480 ? 1 : 2 : 4)
                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            implicitWidth: 32; implicitHeight: 32
                            radius: EstiloPanel.rChip
                            color: EstiloPanel.elevada
                            border { width: 1; color: EstiloPanel.bordeFuerte }
                            Glifo {
                                anchors.centerIn: parent
                                alto: 32
                                text: String.fromCodePoint(modelData.icono)
                                color: index === 0 ? Paleta.acento : Paleta.acento2
                                font.pixelSize: 16
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: modelData.texto
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 14; weight: Font.DemiBold }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.cuando
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }
}
