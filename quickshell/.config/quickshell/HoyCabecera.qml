// HoyCabecera: la fila de arriba de Brújula › Hoy. Reloj y fecha · clima · saludo y tiempo encendido.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    id: cab
    spacing: 16

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    function saludo(h) {
        return h < 6 ? "Buenas noches" : h < 12 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches";
    }

    ColumnLayout {
        spacing: 0
        Text {
            text: Qt.formatTime(reloj.date, "HH:mm")
            color: Paleta.acento
            font { family: Paleta.fuente; pixelSize: 44; bold: true; letterSpacing: -1; features: { "tnum": 1 } }
        }
        Text {
            readonly property string fecha: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
            text: fecha.charAt(0).toUpperCase() + fecha.slice(1)
            color: EstiloPanel.secundario
            font { family: Paleta.fuente; pixelSize: 14 }
        }
    }

    Item { Layout.fillWidth: true }

    // Clima (Clima.qml, Open-Meteo)
    TarjetaPanel {
        visible: Clima.listo
        relleno: 12
        RowLayout {
            spacing: 12
            Text {
                text: Clima.icono(Clima.codigo, Clima.deDia)
                color: Paleta.aviso
                font { family: Paleta.fuente; pixelSize: 36 }
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: `${Math.round(Clima.temp)}°  ${Clima.texto(Clima.codigo)}`
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true }
                }
                Text {
                    text: `${Clima.lugar} · máx ${Math.round(Clima.max)}° · mín ${Math.round(Clima.min)}° · lluvia ${Clima.lluviaHoy} %`
                    color: EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
                Row {   // próximas horas: hora + probabilidad de lluvia (acento2 si ≥ 40 %)
                    spacing: 8
                    Repeater {
                        model: Clima.proximas
                        Text {
                            required property var modelData
                            text: `${modelData.hora}h ${modelData.lluvia}%`
                            color: modelData.lluvia >= 40 ? Paleta.acento2 : EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 11; features: { "tnum": 1 } }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 2
        Text {
            Layout.alignment: Qt.AlignRight
            text: cab.saludo(reloj.date.getHours()) + ", " + Quickshell.env("USER")
            color: Paleta.texto
            font { family: Paleta.fuente; pixelSize: 16; bold: true }
        }
        Text {
            Layout.alignment: Qt.AlignRight
            text: "Encendido " + Sistema.encendido
            color: EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 11 }
        }
    }
}
