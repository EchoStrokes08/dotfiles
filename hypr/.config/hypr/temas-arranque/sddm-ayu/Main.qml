// ╭──────────────────────────────────────────────────────────╮
// │   SDDM · Ayu Dark Glass (gemelo de la pantalla de bloqueo │
// │   de Quickshell: quickshell/PantallaBloqueo.qml)          │
// ╰──────────────────────────────────────────────────────────╯
// SDDM corre como otro usuario y no puede leer el tema vivo de ~/.local/state/tema,
// así que la paleta va fija aquí (la de Paleta.qml en modo ayu oscuro).
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1920; height: 1080
    color: cFondo

    // Paleta (Paleta.qml · ayu oscuro)
    readonly property color cFondo:   "#121519"
    readonly property color cTexto:   "#edf0f5"
    readonly property color cAcento:  "#f19618"
    readonly property color cAcento2: "#36a3d9"
    readonly property color cExito:   "#b8cc52"
    readonly property color cAviso:   "#e6c446"
    readonly property color cPeligro: "#ff3333"
    readonly property color cGris:    "#aab3c0"
    // EstiloPanel.qml
    readonly property color cTenue:      Qt.tint(cFondo, Qt.alpha(cTexto, .68))
    readonly property color cSecundario: Qt.alpha(cTexto, .85)
    readonly property color cApagado:    Qt.alpha(cTexto, .45)
    readonly property string fuente: config.font || "Adwaita Sans"

    // Usuario y sesión: el último usado (o el primero de la lista)
    property var users: []
    property var sessions: []
    property string userName: userModel.lastUser !== "" ? userModel.lastUser : (users.length ? users[0] : "")
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property int attempts: 0
    property bool error: false

    Repeater { model: userModel;    delegate: Item { Component.onCompleted: root.users = root.users.concat([model.name]) } }
    Repeater { model: sessionModel; delegate: Item { Component.onCompleted: { var s = root.sessions.slice(); s[index] = model.name; root.sessions = s } } }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.attempts++
            root.error = true
            password.text = ""; password.forceActiveFocus()
            sacudida.start()
            failTimer.restart()
        }
        function onLoginSucceeded() { root.busy = false }
    }
    Timer { id: failTimer; interval: 2500; onTriggered: root.error = false }

    function doLogin() {
        if (password.text === "" || busy) return
        busy = true
        sddm.login(userName, password.text, sessionIndex)
    }

    // Todo aparece con un fundido
    Item {
        id: todo
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // ── Fondo: desenfocado y oscurecido ──
        Image {
            id: fondo
            anchors { fill: parent; margins: -80 }   // más grande que la pantalla: el desenfoque no deja bordes claros
            source: config.background
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors { fill: parent; margins: -80 }
            source: fondo
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            brightness: -0.42
            saturation: 0.45
        }
        // Luz del acento detrás del reloj y contraluz del segundo color abajo
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0;   color: Qt.alpha(root.cFondo, .15) }
                GradientStop { position: .55; color: "transparent" }
                GradientStop { position: 1;   color: Qt.alpha(root.cFondo, .65) }
            }
        }
        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -150
            width: 900; height: 600
            opacity: .55
            Rectangle {
                anchors.centerIn: parent
                width: 520; height: 360; radius: height / 2
                color: Qt.alpha(root.cAcento, .45)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
            }
        }
        Item {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -120 }
            width: 1100; height: 420
            opacity: .12
            Rectangle {
                anchors.centerIn: parent
                width: 760; height: 240; radius: height / 2
                color: Qt.alpha(root.cAcento2, .5)
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
            }
        }

        // ── Centro ──
        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: 0

            // Tu inicial en un círculo con aro en degradado
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 12
                implicitWidth: 64; implicitHeight: 64
                RectangularShadow {
                    anchors.fill: parent
                    radius: width / 2; blur: 32; spread: -4
                    color: Qt.alpha(root.cAcento, .45)
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.cAcento }
                        GradientStop { position: 1; color: root.cAcento2 }
                    }
                }
                Rectangle {
                    anchors { fill: parent; margins: 4 }
                    radius: width / 2
                    color: Qt.darker(root.cFondo, 1.2)
                    Text {
                        anchors.centerIn: parent
                        text: (root.userName || "?").charAt(0).toUpperCase()
                        color: root.cTexto
                        font { family: root.fuente; pixelSize: 26; weight: Font.Bold }
                    }
                }
            }

            Text {   // saludo
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 14
                readonly property int h: root.now.getHours()
                text: (h < 6 ? "Dulces sueños" : h < 13 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches")
                      + ", <b>" + root.userName + "</b>"
                textFormat: Text.StyledText
                color: root.cTenue
                font { family: root.fuente; pixelSize: 20; italic: true }
            }

            // Hora naranja y minutos azules, con resplandor de su color
            Repeater {
                model: [
                    { txt: Qt.formatTime(root.now, "HH"), col: root.cAcento },
                    { txt: Qt.formatTime(root.now, "mm"), col: root.cAcento2 }
                ]
                Text {
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: -34
                    text: modelData.txt
                    color: modelData.col
                    font { family: root.fuente; pixelSize: 150; weight: Font.ExtraBold }
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
                implicitWidth: 70; implicitHeight: 4; radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.cAcento }
                    GradientStop { position: 1; color: root.cAcento2 }
                }
            }

            Text {   // fecha
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 22
                text: root.now.toLocaleDateString(Qt.locale("es_ES"), "dddd  ·  dd MMMM").toUpperCase()
                color: root.cSecundario
                font { family: root.fuente; pixelSize: 14; bold: true; letterSpacing: 4 }
            }

            // ── Campo de contraseña: píldora con borde naranja → azul ──
            Item {
                id: campo
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 32
                implicitWidth: 340; implicitHeight: 56

                transform: Translate { id: desplazar; x: 0 }
                SequentialAnimation {
                    id: sacudida
                    NumberAnimation { target: desplazar; property: "x"; to: -14; duration: 50 }
                    NumberAnimation { target: desplazar; property: "x"; to: 12; duration: 70 }
                    NumberAnimation { target: desplazar; property: "x"; to: -8; duration: 70 }
                    NumberAnimation { target: desplazar; property: "x"; to: 0; duration: 60 }
                }

                RectangularShadow {   // resplandor del campo, del color de su estado
                    anchors.fill: parent
                    radius: height / 2; blur: 28; spread: -6
                    color: Qt.alpha(root.error ? root.cPeligro : root.cAcento, .45)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Rectangle {   // borde con degradado
                    anchors.fill: parent
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: root.error ? root.cPeligro
                                                         : root.busy ? root.cAviso
                                                         : keyboard.capsLock ? root.cExito : root.cAcento }
                        GradientStop { position: 1; color: root.error ? root.cPeligro
                                                         : root.busy ? root.cAcento : root.cAcento2 }
                    }
                }
                Rectangle {   // cristal oscuro
                    anchors { fill: parent; margins: 2 }
                    radius: height / 2
                    color: Qt.alpha(Qt.darker(root.cFondo, 1.3), 0.88)

                    Row {   // puntos de la contraseña
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: Math.min(password.text.length, 22)
                            Rectangle {
                                width: 11; height: 11; radius: 8
                                color: root.cTexto
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Text {   // texto de ejemplo / error / comprobando
                        anchors.centerIn: parent
                        visible: password.text.length === 0
                        textFormat: Text.StyledText
                        text: root.busy ? "<i>comprobando…</i>"
                            : root.error ? "<b>Contraseña incorrecta</b>  <i>(" + root.attempts + ")</i>"
                            : "<i>  contraseña…</i>"
                        color: root.error ? root.cPeligro : root.cGris
                        font { family: root.fuente; pixelSize: 14 }
                    }
                }

                // La entrada real (invisible): recibe el teclado
                TextInput {
                    id: password
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    enabled: !root.busy
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()
                    Keys.onEscapePressed: password.text = ""
                    Component.onCompleted: forceActiveFocus()
                }
            }

            Text {   // aviso de Bloq Mayús
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                opacity: keyboard.capsLock ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                text: String.fromCodePoint(0xF0A9B) + "  Bloq Mayús activado"
                color: root.cExito
                font { family: root.fuente; pixelSize: 13 }
            }
        }

        // ── Pie ──
        // Izquierda: teclado y sesión (clic en la sesión para cambiarla)
        Row {
            anchors { left: parent.left; bottom: parent.bottom; margins: 40 }
            spacing: 28
            Text {
                textFormat: Text.StyledText
                text: `<font color="${root.cAcento2}">${String.fromCodePoint(0xF030C)}</font> `
                      + (keyboard.layouts.length ? keyboard.layouts[keyboard.currentLayout].shortName : "latam")
                color: root.cTenue
                font { family: root.fuente; pixelSize: 14 }
            }
            Text {
                textFormat: Text.StyledText
                text: `<font color="${root.cAcento}">${String.fromCodePoint(0xF05B2)}</font> ` + (root.sessions[root.sessionIndex] || "")
                color: sessMouse.containsMouse ? root.cTexto : root.cTenue
                font { family: root.fuente; pixelSize: 14 }
                MouseArea {
                    id: sessMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount()); password.forceActiveFocus() }
                }
            }
        }

        // Centro: candado
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
            textFormat: Text.StyledText
            text: `<font color="${root.cAcento}">${String.fromCodePoint(0xF033E)}</font>  INICIAR SESIÓN`
            color: root.cApagado
            font { family: root.fuente; pixelSize: 13; bold: true; letterSpacing: 3 }
        }

        // Derecha: energía
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 40; bottomMargin: 36 }
            spacing: 22
            Repeater {
                model: [
                    { icon: 0xF0904, col: root.cAcento2, ok: sddm.canSuspend,  act: function() { sddm.suspend() } },
                    { icon: 0xF0709, col: root.cAviso,   ok: sddm.canReboot,   act: function() { sddm.reboot() } },
                    { icon: 0xF0425, col: root.cPeligro, ok: sddm.canPowerOff, act: function() { sddm.powerOff() } }
                ]
                delegate: Text {
                    visible: modelData.ok
                    text: String.fromCodePoint(modelData.icon)
                    color: pm.containsMouse ? modelData.col : root.cTenue
                    font { family: root.fuente; pixelSize: 22 }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                }
            }
        }
    }
}
