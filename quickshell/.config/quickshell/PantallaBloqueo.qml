// Lo que se ve en cada monitor bloqueado (mismo diseño que tenía hyprlock):
// saludo · hora naranja y minutos azules · fecha · campo de contraseña · batería, estado y música.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

WlSessionLockSurface {
    id: superficie
    required property var estado          // el Scope de Bloqueo.qml (clave, error, comprobando…)
    color: Paleta.fondo

    SystemClock { id: reloj; precision: SystemClock.Seconds }

    // Todo aparece con un fundido y se va igual al desbloquear
    Item {
        id: todo
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        states: State { when: superficie.estado.saliendo; PropertyChanges { target: todo; opacity: 0 } }

        // ── Fondo: el wallpaper desenfocado y oscurecido ──
        Image {
            id: fondo
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.local/state/tema/wallpaper"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: fondo
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.45
            saturation: 0.1
        }

        // ── Centro ──
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 0

            Text {   // saludo
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 14
                readonly property int h: reloj.date.getHours()
                text: (h < 6 ? "Dulces sueños" : h < 13 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches")
                      + ", <b>" + Quickshell.env("USER") + "</b>"
                textFormat: Text.StyledText
                color: Qt.alpha(Paleta.texto, 0.7)
                font { family: Paleta.fuente; pixelSize: 20; italic: true }
            }

            // Hora naranja y minutos azules, con resplandor de su color
            Repeater {
                model: [
                    { txt: Qt.formatTime(reloj.date, "HH"), col: Paleta.naranja },
                    { txt: Qt.formatTime(reloj.date, "mm"), col: Paleta.azul }
                ]
                Text {
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -34
                    text: modelData.txt
                    color: modelData.col
                    font { family: Paleta.fuente; pixelSize: 150; weight: Font.ExtraBold }
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.alpha(modelData.col, 0.35)
                        shadowBlur: 1.0
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }
            }

            Rectangle {   // rayita naranja → azul
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                implicitWidth: 70; implicitHeight: 4; radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Paleta.naranja }
                    GradientStop { position: 1; color: Paleta.azul }
                }
            }

            Text {   // fecha
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 22
                text: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd  ·  dd MMMM").toUpperCase()
                color: Qt.alpha(Paleta.texto, 0.8)
                font { family: Paleta.fuente; pixelSize: 15; bold: true; letterSpacing: 4 }
            }

            // ── Campo de contraseña: píldora con borde naranja → azul ──
            Item {
                id: campo
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 56
                implicitWidth: 340; implicitHeight: 56

                // sacudida al fallar (un desplazamiento: dentro de un layout no valen los anchors)
                transform: Translate { id: desplazar; x: 0 }
                SequentialAnimation {
                    id: sacudida
                    NumberAnimation { target: desplazar; property: "x"; to: -14; duration: 50 }
                    NumberAnimation { target: desplazar; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: desplazar; property: "x"; to: -8; duration: 70 }
                    NumberAnimation { target: desplazar; property: "x"; to: 0; duration: 60 }
                }
                Connections {
                    target: superficie.estado
                    function onErrorChanged() { if (superficie.estado.error) sacudida.start(); }
                    // si la clave se vacía desde fuera (fallo, Esc), vaciar también la entrada
                    function onClaveChanged() { if (entrada.text !== superficie.estado.clave) entrada.text = superficie.estado.clave; }
                }

                Rectangle {   // borde con degradado (un rectángulo debajo, 2 px más grande)
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: superficie.estado.error ? Paleta.rojo
                                                         : superficie.estado.comprobando ? Paleta.amarillo
                                                         : superficie.estado.bloqMayus ? Paleta.verde : Paleta.naranja }
                        GradientStop { position: 1; color: superficie.estado.error ? "#f07178"
                                                         : superficie.estado.comprobando ? Paleta.naranja : Paleta.azul }
                    }
                }
                Rectangle {   // cristal oscuro
                    anchors { fill: parent; margins: 2 }
                    radius: height / 2
                    color: Qt.alpha("#0b0e14", 0.88)

                    // Puntos de la contraseña
                    Row {
                        anchors.centerIn: parent
                        spacing: 9
                        Repeater {
                            model: Math.min(superficie.estado.clave.length, 22)
                            Rectangle {
                                width: 11; height: 11; radius: 6
                                color: Paleta.texto
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }
                        }
                    }
                    Text {   // texto de ejemplo / error / comprobando
                        anchors.centerIn: parent
                        visible: superficie.estado.clave.length === 0
                        textFormat: Text.StyledText
                        text: superficie.estado.comprobando ? "<i>comprobando…</i>"
                            : superficie.estado.error ? "<b>Contraseña incorrecta</b>  <i>(" + superficie.estado.intentos + ")</i>"
                            : "<i>  contraseña…</i>"
                        color: superficie.estado.error ? "#f07178" : Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 14 }
                    }
                }

                // La entrada real (invisible): recibe el teclado
                TextInput {
                    id: entrada
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    enabled: !superficie.estado.comprobando
                    onTextChanged: superficie.estado.clave = text
                    Keys.onReturnPressed: superficie.estado.enviar()
                    Keys.onEnterPressed: superficie.estado.enviar()
                    Keys.onEscapePressed: superficie.estado.clave = ""
                    Keys.onPressed: (e) => { if (e.key === Qt.Key_CapsLock) avisoMayus.restart(); }
                    Component.onCompleted: forceActiveFocus()
                }
                Timer { id: avisoMayus; interval: 150; onTriggered: superficie.estado.leerMayus() }
            }

            Text {   // aviso de Bloq Mayús
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                opacity: superficie.estado.bloqMayus ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                text: String.fromCodePoint(0xF0A9B) + "  Bloq Mayús activado"
                color: Paleta.verde
                font { family: Paleta.fuente; pixelSize: 13 }
            }
        }

        // ── Pie: batería · estado · música ──
        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 40 }
            readonly property var bat: UPower.displayDevice
            readonly property int pct: Math.round(bat ? (bat.percentage > 1 ? bat.percentage : bat.percentage * 100) : 0)
            visible: bat?.isLaptopBattery ?? false
            textFormat: Text.StyledText
            text: `<font color="${Paleta.verde}">${String.fromCodePoint(0xF0079)}</font> ${pct}%    <font color="${Paleta.azul}">${String.fromCodePoint(0xF030C)}</font> latam`
            color: Qt.alpha(Paleta.texto, 0.7)
            font { family: Paleta.fuente; pixelSize: 14 }
        }
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
            textFormat: Text.StyledText
            text: `<font color="${Paleta.naranja}">${String.fromCodePoint(0xF033E)}</font>  BLOQUEADO`
            color: Qt.alpha(Paleta.texto, 0.5)
            font { family: Paleta.fuente; pixelSize: 13; bold: true; letterSpacing: 3 }
        }
        Text {
            anchors { right: parent.right; bottom: parent.bottom; margins: 40 }
            readonly property var j: Mpris.players.values.find(p => p.isPlaying) ?? null
            visible: j !== null
            width: Math.min(implicitWidth, 420)
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: j ? `<font color="${Paleta.naranja}">${String.fromCodePoint(0xF075A)}</font>  <i>${j.trackArtist} — ${j.trackTitle}</i>` : ""
            color: Qt.alpha(Paleta.texto, 0.7)
            font { family: Paleta.fuente; pixelSize: 14 }
        }
    }
}
