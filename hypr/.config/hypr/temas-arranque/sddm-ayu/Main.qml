// Inicio de sesión de SDDM. sincronizar-sddm.sh publica el fondo, la foto y los colores activos.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1920; height: 1080
    color: cFondo

    Tema { id: tema }
    readonly property color cFondo: tema.fondo
    readonly property color cTexto: tema.texto
    readonly property color cAcento: tema.acento
    readonly property color cAcento2: tema.acento2
    readonly property color cAviso: tema.aviso
    readonly property color cPeligro: tema.peligro
    readonly property color cTenue: Qt.tint(cFondo, Qt.alpha(cTexto, tema.claro ? .82 : .68))
    readonly property color cSuperficie: Qt.tint(cFondo, Qt.alpha(cTexto, .065))
    readonly property color cBorde: Qt.alpha(cTexto, .14)
    readonly property color cImagen: "#f3efe0"
    readonly property color cLuz: Qt.tint(cAcento, Qt.alpha(cImagen, tema.claro ? .58 : .24))
    readonly property color cReflejo: Qt.tint(cAcento2, Qt.alpha(cImagen, tema.claro ? .58 : .24))
    readonly property string fuente: config.font || "Adwaita Sans"
    readonly property bool horizontal: width >= 790 || height < 385
    readonly property bool compacto: !horizontal || height < 620
    readonly property real margen: compacto ? 16 : Math.round(Math.min(32, width * .022))
    readonly property real division: horizontal ? Math.round(width * (width >= 1050 ? .61 : .54)) : 0
    readonly property real altoImagen: horizontal ? height - margen * 2 : Math.round(Math.min(360, height * .42))

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

    Item {
        id: escena
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.tint(root.cFondo, Qt.alpha(root.cAcento2, .065)) }
                GradientStop { position: 1; color: root.cFondo }
            }
        }

        Item {
            id: panorama
            x: root.margen
            y: root.margen
            width: Math.max(1, (root.horizontal ? root.division : root.width - root.margen) - x)
            height: Math.max(1, root.altoImagen)
            clip: true

            Image {
                anchors.fill: parent
                source: config.background
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: .38; color: Qt.alpha("black", .04) }
                    GradientStop { position: .75; color: Qt.alpha("black", .58) }
                    GradientStop { position: 1; color: Qt.alpha("black", .86) }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border { width: 1; color: Qt.alpha("white", .18) }
            }

            ColumnLayout {
                anchors {
                    left: parent.left; right: parent.right; bottom: parent.bottom
                    margins: root.compacto ? 20 : 36
                }
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: root.cImagen
                    elide: Text.ElideRight
                    readonly property int cuerpo: panorama.width < 410 ? 44 : root.compacto ? 62 : panorama.width < 640 ? 76 : 104
                    topPadding: -Math.round(cuerpo * .18)
                    bottomPadding: -Math.round(cuerpo * .15)
                    font { family: root.fuente; pixelSize: cuerpo; weight: Font.DemiBold; letterSpacing: -2; features: { "tnum": 1 } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 20; implicitHeight: 2; radius: height / 2
                        color: root.cLuz
                    }
                    Text {
                        Layout.fillWidth: true
                        readonly property string fecha: root.now.toLocaleDateString(Qt.locale("es_CO"), "dddd, d 'de' MMMM")
                        text: fecha.charAt(0).toUpperCase() + fecha.slice(1)
                        color: root.cImagen
                        elide: Text.ElideRight
                        font { family: root.fuente; pixelSize: root.compacto ? 12 : 16; weight: Font.Medium }
                    }
                }
            }
        }

        Item {
            id: acceso
            x: root.horizontal ? root.division : 0
            y: root.horizontal ? root.margen : panorama.y + panorama.height
            width: Math.max(1, parent.width - x)
            height: Math.max(1, parent.height - y - root.margen)

            ColumnLayout {
                id: formulario
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.horizontal ? -14 : -16
                width: Math.max(1, Math.min(350, parent.width - (root.compacto ? 48 : 76)))
                spacing: root.compacto ? 8 : 16

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: root.compacto ? 0 : 8
                    text: "Inicia sesión"
                    color: root.cTexto
                    elide: Text.ElideRight
                    font { family: root.fuente; pixelSize: root.compacto ? 26 : 44; weight: Font.DemiBold; letterSpacing: -1 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        implicitWidth: root.compacto ? 36 : 48
                        implicitHeight: implicitWidth
                        radius: height / 2
                        color: Qt.tint(root.cSuperficie, Qt.alpha(root.cAcento, .07))
                        border { width: 1; color: Qt.alpha(root.cAcento, .8) }
                        Text {
                            anchors.centerIn: parent
                            visible: !retrato.visible
                            text: (root.userName || "?").charAt(0).toUpperCase()
                            color: root.cAcento
                            font { family: root.fuente; pixelSize: 20; bold: true }
                        }
                        Image {
                            id: foto
                            anchors { fill: parent; margins: 2 }
                            source: Qt.resolvedUrl("avatar")
                            fillMode: Image.PreserveAspectCrop
                            sourceSize { width: 96; height: 96 }
                            asynchronous: true
                            visible: false
                        }
                        MultiEffect {
                            id: retrato
                            anchors.fill: foto
                            source: foto
                            maskEnabled: true
                            maskSource: mascara
                            visible: foto.status === Image.Ready && GraphicsInfo.api !== GraphicsInfo.Software
                        }
                        Rectangle {
                            id: mascara
                            anchors.fill: foto
                            radius: height / 2
                            visible: false
                            layer.enabled: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: {
                                const h = root.now.getHours();
                                return h < 6 ? "Dulces sueños" : h < 13 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches";
                            }
                            color: root.cTenue
                            font { family: root.fuente; pixelSize: 12 }
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.userName.charAt(0).toUpperCase() + root.userName.slice(1)
                            textFormat: Text.PlainText
                            color: root.cTexto
                            font { family: root.fuente; pixelSize: 16; weight: Font.DemiBold }
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    id: campo
                    Layout.fillWidth: true
                    implicitHeight: root.compacto ? 44 : 52
                    readonly property color tono: root.error ? root.cPeligro : root.busy ? root.cAviso : root.cAcento
                    transform: Translate { id: desplazar }
                    SequentialAnimation {
                        id: sacudida
                        NumberAnimation { target: desplazar; property: "x"; to: -8; duration: 45 }
                        NumberAnimation { target: desplazar; property: "x"; to: 6; duration: 60 }
                        NumberAnimation { target: desplazar; property: "x"; to: -3; duration: 60 }
                        NumberAnimation { target: desplazar; property: "x"; to: 0; duration: 45 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: root.cSuperficie
                        border { width: password.activeFocus ? 2 : 1; color: campo.tono }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 8
                        Text {
                            text: String.fromCodePoint(root.error ? 0xF0026 : 0xF033E)
                            color: campo.tono
                            font { family: root.fuente; pixelSize: 16 }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            visible: !root.busy && password.text.length > 0
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Repeater {
                                    model: Math.min(password.text.length, Math.floor(parent.width / 12), 22)
                                    Rectangle { width: 8; height: width; radius: height / 2; color: root.cTexto }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            visible: root.busy || password.text.length === 0
                            text: root.busy ? "Contraseña" : root.error ? "Contraseña incorrecta" : "Contraseña"
                            color: root.error && !root.busy ? root.cPeligro : root.cTenue
                            font { family: root.fuente; pixelSize: 14 }
                            elide: Text.ElideRight
                        }
                    }

                    TextInput {
                        id: password
                        anchors.fill: parent
                        opacity: 0
                        focus: true
                        echoMode: TextInput.Password
                        Accessible.name: "Contraseña"
                        enabled: !root.busy
                        Keys.onReturnPressed: root.doLogin()
                        Keys.onEnterPressed: root.doLogin()
                        Keys.onEscapePressed: password.text = ""
                        Component.onCompleted: forceActiveFocus()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: keyboard.capsLock || root.error
                    text: keyboard.capsLock ? "Bloq Mayús activado"
                        : root.attempts + (root.attempts === 1 ? " intento fallido" : " intentos fallidos")
                    color: keyboard.capsLock ? root.cAviso : root.cTenue
                    font { family: root.fuente; pixelSize: 12 }
                    elide: Text.ElideRight
                }

                Button {
                    id: entrar
                    Layout.fillWidth: true
                    implicitHeight: root.compacto ? 38 : 44
                    text: root.busy ? "Verificando…" : "Entrar"
                    enabled: !root.busy
                    hoverEnabled: true
                    background: Rectangle {
                        radius: 12
                        color: entrar.down ? Qt.tint(root.cAcento, Qt.alpha(root.cFondo, .22))
                            : entrar.hovered ? Qt.tint(root.cAcento, Qt.alpha(root.cTexto, .13))
                            : root.cAcento
                        opacity: entrar.enabled ? 1 : .58
                        border { width: entrar.activeFocus ? 2 : 0; color: root.cTexto }
                    }
                    contentItem: Text {
                        text: entrar.text
                        color: root.cFondo
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font { family: root.fuente; pixelSize: 14; weight: Font.Bold }
                    }
                    onClicked: {
                        if (password.text.length > 0) root.doLogin();
                        else password.forceActiveFocus();
                    }
                }
            }
        }

        RowLayout {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: acceso.x + (root.horizontal ? 24 : root.margen)
                rightMargin: root.horizontal ? 24 : root.margen
                bottomMargin: root.compacto ? 8 : 24
            }
            spacing: 8

            Text {
                text: String.fromCodePoint(0xF030C)
                color: root.cReflejo
                font { family: root.fuente; pixelSize: 14 }
            }
            Text {
                text: keyboard.layouts[keyboard.currentLayout]?.shortName || "latam"
                color: root.cTenue
                font { family: root.fuente; pixelSize: 12 }
            }
            Button {
                id: sesion
                Layout.maximumWidth: Math.min(220, root.width * .32)
                Layout.minimumWidth: 0
                visible: textoSesion.text !== ""
                hoverEnabled: true
                Accessible.name: "Cambiar sesión · " + textoSesion.text
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Cambiar sesión"
                horizontalPadding: 8
                background: Rectangle {
                    radius: height / 2
                    color: sesion.hovered || sesion.activeFocus ? root.cSuperficie : "transparent"
                    border.color: sesion.activeFocus ? root.cLuz : "transparent"
                }
                contentItem: Text {
                    id: textoSesion
                    text: root.sessions[root.sessionIndex] || ""
                    textFormat: Text.PlainText
                    color: root.cTenue
                    elide: Text.ElideRight
                    font { family: root.fuente; pixelSize: 12; weight: Font.DemiBold }
                }
                onClicked: { root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount()); password.forceActiveFocus(); }
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [
                    { icon: 0xF0904, color: root.cReflejo, available: sddm.canSuspend, label: "Suspender", action: () => sddm.suspend() },
                    { icon: 0xF0709, color: root.cAviso, available: sddm.canReboot, label: "Reiniciar", action: () => sddm.reboot() },
                    { icon: 0xF0425, color: root.cPeligro, available: sddm.canPowerOff, label: "Apagar", action: () => sddm.powerOff() }
                ]
                Button {
                    id: energia
                    required property var modelData
                    visible: modelData.available
                    implicitWidth: root.compacto ? 32 : 36
                    implicitHeight: implicitWidth
                    padding: 0
                    hoverEnabled: true
                    Accessible.name: modelData.label
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: modelData.label
                    background: Rectangle {
                        radius: height / 2
                        color: energia.hovered || energia.activeFocus ? root.cSuperficie : "transparent"
                        border.color: energia.activeFocus ? root.cAcento : root.cBorde
                    }
                    contentItem: Text {
                        text: String.fromCodePoint(energia.modelData.icon)
                        color: energia.hovered ? energia.modelData.color : root.cTenue
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font { family: root.fuente; pixelSize: 16 }
                    }
                    onClicked: modelData.action()
                }
            }
        }
    }
}
