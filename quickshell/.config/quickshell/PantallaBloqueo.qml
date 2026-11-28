// Una superficie por monitor. Bloqueo.qml comparte la entrada y coordina la sesión.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

WlSessionLockSurface {
    id: superficie
    required property var estado
    color: Paleta.fondo

    SystemClock { id: reloj; precision: SystemClock.Minutes }
    // El escritorio se aleja al bloquear y vuelve al desbloquear (encima de todo, solo durante la transición)
    TransicionBloqueo { anchors.fill: parent; z: 100; estado: superficie.estado; pantalla: superficie.screen?.name ?? "" }

    Item {
        id: escena
        anchors.fill: parent
        readonly property bool compacto: width < 760 || height < 620
        readonly property bool horizontal: width >= 760
        readonly property real margen: compacto ? EstiloPanel.e5 : Math.round(Math.min(136, width * .077))
        readonly property color claro: Paleta.sobreImagen
        readonly property color tenue: Qt.alpha(claro, .78)
        readonly property color luz: Qt.tint(Paleta.acento, Qt.alpha(claro, EstiloPanel.fondoClaro ? .58 : .24))
        readonly property color reflejo: Qt.tint(Paleta.acento2, Qt.alpha(claro, EstiloPanel.fondoClaro ? .58 : .24))

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
        states: State { when: superficie.estado.saliendo; PropertyChanges { target: escena; opacity: 0 } }

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.local/state/tema/wallpaper"
            sourceSize.width: Math.max(1280, Math.min(2560, escena.width))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: escena.horizontal ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0; color: Qt.alpha("black", .90) }
                GradientStop { position: .37; color: Qt.alpha("black", escena.horizontal ? .78 : .67) }
                GradientStop { position: .72; color: Qt.alpha("black", escena.horizontal ? .26 : .58) }
                GradientStop { position: 1; color: Qt.alpha("black", escena.horizontal ? .08 : .80) }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * .34
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha("black", .75) }
            }
        }

        ColumnLayout {
            id: centro
            x: escena.horizontal ? escena.margen : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: escena.compacto ? -12 : -24
            width: Math.max(1, Math.min(480, parent.width - escena.margen * 2))
            spacing: escena.compacto ? EstiloPanel.e2 : EstiloPanel.e4

            RowLayout {
                spacing: 8
                Glifo {
                    text: String.fromCodePoint(0xF033E)
                    alto: 20
                    color: escena.luz
                    font.pixelSize: 14
                }
                Text {
                    text: "SESIÓN BLOQUEADA"
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 }
                }
            }

            Row {
                id: cifras
                readonly property int tam: escena.width < 400 ? 62 : escena.compacto ? 104 : 150
                spacing: 4
                Accessible.name: Qt.formatTime(reloj.date, "HH:mm")

                Repeater {
                    model: [Qt.formatTime(reloj.date, "HH"), ":", Qt.formatTime(reloj.date, "mm")]
                    Text {
                        required property string modelData
                        required property int index
                        text: modelData
                        color: index === 0 ? escena.claro : index === 1 ? escena.tenue : escena.reflejo
                        topPadding: -Math.round(cifras.tam * .18)
                        bottomPadding: -Math.round(cifras.tam * .15)
                        font { family: Paleta.fuente; pixelSize: cifras.tam; weight: Font.Bold; letterSpacing: -3 }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                readonly property string fecha: reloj.date.toLocaleDateString(Qt.locale("es_CO"), "dddd, d 'de' MMMM")
                text: fecha.charAt(0).toUpperCase() + fecha.slice(1)
                color: escena.claro
                elide: Text.ElideRight
                font { family: Paleta.fuente; pixelSize: escena.compacto ? 16 : 20; weight: Font.DemiBold }
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

            Item {
                id: tarjeta
                Layout.fillWidth: true
                Layout.topMargin: escena.compacto ? EstiloPanel.e2 : EstiloPanel.e4
                readonly property int margen: escena.compacto ? EstiloPanel.e3 : EstiloPanel.e4
                implicitHeight: formulario.implicitHeight + margen * 2

                FondoPanel {
                    anchors.fill: parent
                    radio: EstiloPanel.rPanel
                    opacidad: 1
                }
                ColumnLayout {
                    id: formulario
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: tarjeta.margen }
                    spacing: escena.compacto ? EstiloPanel.e2 : EstiloPanel.e3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Item {
                            id: avatar
                            implicitWidth: escena.compacto ? 36 : 48
                            implicitHeight: implicitWidth
                            readonly property string usuario: Quickshell.env("USER") || "?"
                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: EstiloPanel.seleccionado
                                border { width: 1; color: EstiloPanel.bordeSeleccion }
                            }
                            MarcoFondo {
                                anchors { fill: parent; margins: 2 }
                                radio: height / 2
                                Image {
                                    id: foto
                                    anchors.fill: parent
                                    source: "file://" + Quickshell.env("HOME") + "/.face"
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize { width: 96; height: 96 }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: foto.status !== Image.Ready
                                text: avatar.usuario.charAt(0).toUpperCase()
                                color: Paleta.acento
                                font { family: Paleta.fuente; pixelSize: 20; weight: Font.Bold }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const h = reloj.date.getHours();
                                    return h < 6 ? "Dulces sueños" : h < 13 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches";
                                }
                                color: EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 12 }
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: avatar.usuario.charAt(0).toUpperCase() + avatar.usuario.slice(1)
                                textFormat: Text.PlainText
                                color: Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 16; weight: Font.DemiBold }
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        id: campo
                        Layout.fillWidth: true
                        implicitHeight: escena.compacto ? 44 : 52
                        readonly property color tono: superficie.estado.error ? Paleta.peligro
                            : superficie.estado.comprobando ? Paleta.aviso : Paleta.acento

                        transform: Translate { id: desplazar; x: 0 }
                        SequentialAnimation {
                            id: sacudida
                            NumberAnimation { target: desplazar; property: "x"; to: -8; duration: 45 }
                            NumberAnimation { target: desplazar; property: "x"; to: 6; duration: 60 }
                            NumberAnimation { target: desplazar; property: "x"; to: -3; duration: 60 }
                            NumberAnimation { target: desplazar; property: "x"; to: 0; duration: 45 }
                        }
                        Connections {
                            target: superficie.estado
                            function onErrorChanged() {
                                if (superficie.estado.error && EstiloPanel.movimiento) sacudida.restart();
                            }
                            function onClaveChanged() {
                                if (entrada.text !== superficie.estado.clave) entrada.text = superficie.estado.clave;
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: EstiloPanel.rControl
                            color: EstiloPanel.elevada
                            border { width: entrada.activeFocus ? 2 : 1; color: campo.tono }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 8

                            Glifo {
                                text: String.fromCodePoint(superficie.estado.error ? 0xF0026 : 0xF033E)
                                alto: campo.height
                                color: campo.tono
                                font.pixelSize: 16
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.fillHeight: true
                                visible: !superficie.estado.comprobando && superficie.estado.clave.length > 0

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Repeater {
                                        model: Math.min(superficie.estado.clave.length, Math.floor(parent.width / 12), 22)
                                        Rectangle {
                                            width: 8; height: width
                                            radius: height / 2
                                            color: Paleta.texto
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                visible: superficie.estado.comprobando || superficie.estado.clave.length === 0
                                text: superficie.estado.comprobando ? "Verificando…"
                                    : superficie.estado.error ? "Contraseña incorrecta" : "Contraseña"
                                color: superficie.estado.error ? Paleta.peligro : EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 14 }
                                elide: Text.ElideRight
                            }
                            Tecla {
                                visible: !superficie.estado.comprobando && campo.width >= 172
                                texto: "↵"
                            }
                        }

                        TextInput {
                            id: entrada
                            anchors.fill: parent
                            opacity: 0
                            focus: true
                            echoMode: TextInput.Password
                            Accessible.name: "Contraseña"
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

                    Text {
                        Layout.fillWidth: true
                        text: superficie.estado.bloqMayus ? "Bloq Mayús activado"
                            : superficie.estado.error ? superficie.estado.intentos + (superficie.estado.intentos === 1 ? " intento fallido" : " intentos fallidos")
                            : "Enter para desbloquear"
                        color: superficie.estado.bloqMayus ? Paleta.aviso : EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: escena.margen; rightMargin: escena.margen; bottomMargin: escena.compacto ? 12 : 32 }
            spacing: 16
            visible: escena.height >= 360

            RowLayout {
                readonly property var bat: UPower.displayDevice
                readonly property int pct: Math.round(bat ? (bat.percentage > 1 ? bat.percentage : bat.percentage * 100) : 0)
                visible: bat?.isLaptopBattery ?? false
                spacing: 8
                Glifo { text: String.fromCodePoint(0xF0079); alto: 20; color: escena.luz; font.pixelSize: 14 }
                Text {
                    text: parent.pct + " %"
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
                }
            }
            RowLayout {
                spacing: 8
                Glifo { text: String.fromCodePoint(0xF030C); alto: 20; color: escena.reflejo; font.pixelSize: 14 }
                Text {
                    text: "latam"
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: 12 }
                }
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                id: musica
                readonly property var j: Mpris.players.values.find(p => p.isPlaying) ?? null
                readonly property real ancho: Math.min(380, escena.width * .55, pista.implicitWidth + 24)
                visible: !!j && escena.height >= 440
                Layout.preferredWidth: ancho
                Layout.maximumWidth: ancho
                Layout.minimumWidth: 0
                spacing: 8
                Glifo { text: String.fromCodePoint(0xF075A); alto: 20; color: escena.reflejo; font.pixelSize: 14 }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    id: pista
                    text: [musica.j?.trackArtist, musica.j?.trackTitle].filter(Boolean).join(" · ")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: escena.claro
                    font { family: Paleta.fuente; pixelSize: 12 }
                }
            }
        }
    }
}
