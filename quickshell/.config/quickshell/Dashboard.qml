// Dashboard: panel de cristal que baja desde arriba (SUPER+D). Esc o clic fuera lo cierran.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Hyprland

PanelWindow {
    id: ventana

    property bool abierto: false
    property bool mostrar: false      // la ventana sigue viva mientras dura la animación de cierre

    onAbiertoChanged: {
        Sistema.activo = abierto;     // medir CPU/RAM solo con el panel abierto
        if (abierto) {
            cierre.stop(); mostrar = true;
            Hyprland.refreshWorkspaces();   // datos frescos de ventanas (para sus iconos)
            Hyprland.refreshToplevels();
        }
        else cierre.restart();
    }
    Timer { id: cierre; interval: 260; onTriggered: ventana.mostrar = false }

    visible: mostrar
    color: "transparent"
    // Ocupa toda la pantalla (transparente) para poder cerrar con un clic fuera de la tarjeta
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dashboard"       // para la layer rule de blur
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Velo oscuro detrás + clic fuera = cerrar
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: ventana.abierto ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        MouseArea { anchors.fill: parent; onClicked: ventana.abierto = false }
    }

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    readonly property var bateria: UPower.displayDevice
    // percentage puede venir de 0 a 1 o de 0 a 100 según la versión: se normaliza
    readonly property real carga: bateria ? (bateria.percentage > 1 ? bateria.percentage / 100 : bateria.percentage) : 0
    readonly property bool cargando: bateria?.state === UPowerDeviceState.Charging

    function saludo(h) {
        return h < 6 ? "buenas noches" : h < 12 ? "buenos días" : h < 20 ? "buenas tardes" : "buenas noches";
    }

    // ── La tarjeta ──────────────────────────────────────────────────────
    Rectangle {
        id: tarjeta
        width: 820
        height: contenido.implicitHeight + 48
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 18
        color: Qt.alpha(Paleta.fondo, 0.86)
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }

        // Entrada: baja 40 px y aparece; salida: al revés
        y: ventana.abierto ? 40 : 4
        opacity: ventana.abierto ? 1 : 0
        scale: ventana.abierto ? 1 : 0.97
        Behavior on y       { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale   { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }    // que un clic en la tarjeta no la cierre

        focus: true
        Keys.onEscapePressed: ventana.abierto = false

        ColumnLayout {
            id: contenido
            anchors { fill: parent; margins: 24 }
            spacing: 18

            // ── Reloj y saludo ──
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: -4
                    Text {
                        text: Qt.formatTime(reloj.date, "HH:mm")
                        color: Paleta.naranja
                        font { family: Paleta.fuente; pixelSize: 58; bold: true }
                    }
                    Text {
                        text: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 14 }
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: ventana.saludo(reloj.date.getHours()) + ", " + Quickshell.env("USER")
                        color: Paleta.morado
                        font { family: Paleta.fuente; pixelSize: 15; bold: true }
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "  encendido " + Sistema.encendido
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 11; italic: true }
                    }
                }
            }

            // ── Espacios de trabajo ──
            Espacios {
                Layout.fillWidth: true
                onElegido: ventana.abierto = false
            }

            Separador {}

            // ── Calendario | anillos | tiempo de pantalla ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                Calendario { Layout.alignment: Qt.AlignTop }
                Rectangle { Layout.fillHeight: true; width: 1; color: Qt.alpha(Paleta.texto, 0.08) }
                GridLayout {
                    Layout.alignment: Qt.AlignVCenter
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 14
                    Anillo {
                        valor: Sistema.cpu; color: Paleta.azul
                        etiqueta: "CPU"; texto: Math.round(Sistema.cpu * 100) + "%"
                    }
                    Anillo {
                        valor: Sistema.ram; color: Paleta.verde
                        etiqueta: "RAM"; texto: Math.round(Sistema.ram * 100) + "%"
                    }
                    Anillo {
                        // 30 °C = vacío, 95 °C = lleno; amarillo → rojo a partir de 80
                        valor: (Sistema.temp - 30) / 65
                        color: Sistema.temp >= 80 ? Paleta.rojo : Paleta.amarillo
                        etiqueta: "TEMP"; texto: Math.round(Sistema.temp) + "°"
                    }
                    Anillo {
                        valor: ventana.carga
                        color: ventana.cargando ? Paleta.verde : ventana.carga < 0.2 ? Paleta.rojo : Paleta.naranja
                        etiqueta: ventana.cargando ? " BAT" : "BAT"
                        texto: Math.round(ventana.carga * 100) + "%"
                    }
                }
                Rectangle { Layout.fillHeight: true; width: 1; color: Qt.alpha(Paleta.texto, 0.08) }
                Tiempo {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                }
            }

            Separador {}

            // ── Música ──
            Musica { Layout.fillWidth: true }
        }
    }

    component Separador: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.alpha(Paleta.texto, 0.08)
    }
}
