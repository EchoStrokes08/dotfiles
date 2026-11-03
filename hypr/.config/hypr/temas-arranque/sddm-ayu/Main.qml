// ╭──────────────────────────────────────────────────────────╮
// │            SDDM · Ayu Dark Glass (gemelo de hyprlock)    │
// ╰──────────────────────────────────────────────────────────╯
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920; height: 1080
    color: "#0b0e14"

    // Paleta Ayu (la misma de hyprlock.conf)
    readonly property color cBg: "#0b0e14"
    readonly property color cText: "#e5e1cf"
    readonly property color cDim: "#5c6773"
    readonly property color cOrange: "#f19618"
    readonly property color cBlue: "#36a3d9"
    readonly property color cGreen: "#c2d94c"
    readonly property color cYellow: "#e6c446"
    readonly property color cRed: "#ff3333"
    readonly property color cPink: "#f07178"
    readonly property string fontName: config.font || "JetBrainsMono Nerd Font"
    readonly property var es: Qt.locale("es_MX")

    // Usuario y sesión: el último usado (o el primero de la lista)
    property var users: []
    property var sessions: []
    property string userName: userModel.lastUser !== "" ? userModel.lastUser : (users.length ? users[0] : "")
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property int attempts: 0
    property string failText: ""

    Repeater { model: userModel;    delegate: Item { Component.onCompleted: root.users = root.users.concat([model.name]) } }
    Repeater { model: sessionModel; delegate: Item { Component.onCompleted: { var s = root.sessions.slice(); s[index] = model.name; root.sessions = s } } }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    function greeting() {
        var h = now.getHours()
        return h < 6 ? "Dulces sueños" : h < 13 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches"
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.attempts++
            root.failText = "Contraseña incorrecta"
            password.text = ""; password.forceActiveFocus()
            failTimer.restart()
        }
        function onLoginSucceeded() { root.busy = false }
    }
    Timer { id: failTimer; interval: 2500; onTriggered: root.failText = "" }

    function doLogin() {
        if (password.text === "" || busy) return      // igual que ignore_empty_input
        busy = true
        sddm.login(userName, password.text, sessionIndex)
    }

    // ─────────────────────────── FONDO ───────────────────────────
    // Ya viene desenfocado y oscurecido (como blur + brightness 0.45 de hyprlock)
    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }

    // Todo se posiciona respecto al centro, como "position = x, y" en hyprlock
    // (en hyprlock y positivo = hacia arriba; aquí se resta)
    Item {
        id: center
        anchors.centerIn: parent
        width: 0; height: 0

        // ─── SALUDO ───
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -330 - height / 2
            text: "<i>" + root.greeting() + ", <b>" + root.userName + "</b></i>"
            textFormat: Text.StyledText
            color: Qt.rgba(0.898, 0.882, 0.812, 0.7)
            font.family: root.fontName; font.pixelSize: 21
        }

        // ─── RELOJ APILADO (HH / MM) ───
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -210 - height / 2
            text: Qt.formatTime(root.now, "HH")
            color: root.cOrange
            font.family: root.fontName; font.pixelSize: 186; font.weight: Font.ExtraBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -65 - height / 2
            text: Qt.formatTime(root.now, "mm")
            color: root.cBlue
            font.family: root.fontName; font.pixelSize: 186; font.weight: Font.ExtraBold
        }

        // Barrita con el degradado de tus bordes
        Rectangle {
            x: -35; y: 30 - 2
            width: 70; height: 4; radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.cOrange }
                GradientStop { position: 1; color: root.cBlue }
            }
        }

        // ─── FECHA ───
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 65 - height / 2
            text: root.now.toLocaleDateString(root.es, "dddd · dd MMMM").toUpperCase()
            color: Qt.rgba(0.898, 0.882, 0.812, 0.8)
            font.family: root.fontName; font.pixelSize: 17; font.weight: Font.Bold
            font.letterSpacing: 4
        }

        // ─── CONTRASEÑA (píldora con borde degradado) ───
        Rectangle {
            id: pill
            x: -170; y: 170 - 28
            width: 340; height: 56; radius: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.failText !== "" ? root.cRed : root.busy ? root.cYellow : keyboard.capsLock ? root.cGreen : root.cOrange
                               Behavior on color { ColorAnimation { duration: 300 } } }
                GradientStop { position: 1; color: root.failText !== "" ? root.cPink : root.busy ? root.cOrange : root.cBlue
                               Behavior on color { ColorAnimation { duration: 300 } } }
            }

            Rectangle {      // cristal oscuro
                anchors.fill: parent; anchors.margins: 2
                radius: height / 2
                color: "#0d1119"

                TextField {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 24; anchors.rightMargin: 24
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.cText
                    font.family: root.fontName; font.pixelSize: 18; font.letterSpacing: 3
                    background: Item {}
                    focus: true
                    enabled: !root.busy
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()
                    Component.onCompleted: forceActiveFocus()
                }
                // Placeholder / mensaje de error (como placeholder_text y fail_text)
                Text {
                    anchors.centerIn: parent
                    visible: password.text === ""
                    text: root.failText !== "" ? "<b>" + root.failText + "</b>  <i>(" + root.attempts + ")</i>" : "<i>  contraseña…</i>"
                    textFormat: Text.StyledText
                    color: root.failText !== "" ? root.cPink : root.cDim
                    font.family: root.fontName; font.pixelSize: 17
                }
            }
        }

        // Aviso de Bloq Mayús
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 225 - height / 2
            visible: keyboard.capsLock
            text: "󰪛  Bloq Mayús activado"
            color: root.cGreen
            font.family: root.fontName; font.pixelSize: 15
        }
    }

    // ───────────────────────── BARRA INFERIOR ────────────────────
    // Izquierda: teclado y sesión (clic en la sesión para cambiarla)
    Row {
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: 40; anchors.bottomMargin: 35
        spacing: 28
        Text {
            text: "<font color='#36a3d9'>󰌌</font> " + (keyboard.layouts.length ? keyboard.layouts[keyboard.currentLayout].shortName : "")
            textFormat: Text.StyledText
            color: Qt.rgba(0.898, 0.882, 0.812, 0.7)
            font.family: root.fontName; font.pixelSize: 16
        }
        Text {
            text: "<font color='#f19618'>󰖲</font> " + (root.sessions[root.sessionIndex] || "")
            textFormat: Text.StyledText
            color: sessMouse.containsMouse ? root.cText : Qt.rgba(0.898, 0.882, 0.812, 0.7)
            font.family: root.fontName; font.pixelSize: 16
            MouseArea {
                id: sessMouse; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount()); password.forceActiveFocus() }
            }
        }
    }

    // Centro: candado
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 35
        text: "<font color='#f19618'>󰌾</font>  INICIAR SESIÓN"
        textFormat: Text.StyledText
        color: Qt.rgba(0.898, 0.882, 0.812, 0.5)
        font.family: root.fontName; font.pixelSize: 15; font.weight: Font.Bold
        font.letterSpacing: 2
    }

    // Derecha: energía
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.rightMargin: 40; anchors.bottomMargin: 30
        spacing: 22
        Repeater {
            model: [
                { icon: "󰤄", tip: "Suspender", col: "#36a3d9", ok: sddm.canSuspend,  act: function() { sddm.suspend() } },
                { icon: "󰜉", tip: "Reiniciar", col: "#e6c446", ok: sddm.canReboot,   act: function() { sddm.reboot() } },
                { icon: "󰐥", tip: "Apagar",    col: "#ff3333", ok: sddm.canPowerOff, act: function() { sddm.powerOff() } }
            ]
            delegate: Text {
                visible: modelData.ok
                text: modelData.icon
                color: pm.containsMouse ? modelData.col : Qt.rgba(0.898, 0.882, 0.812, 0.6)
                font.family: root.fontName; font.pixelSize: 24
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
            }
        }
    }
}
