import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

Superpuesta {
    id: menu
    espacio: "apagado"
    anchoTarjeta: Math.max(0, Math.min(580, width - EstiloPanel.e6))
    margenPanel: EstiloPanel.e5
    alturaRelativa: (height - altoPanel) / (2 * Math.max(1, height))

    readonly property var acciones: [
        { texto: "Bloquear", icono: "M8 12 V9 A6 6 0 0 1 20 9 V12 M7 12 H21 Q23 12 23 14 V23 Q23 25 21 25 H7 Q5 25 5 23 V14 Q5 12 7 12 Z M14 17.5 V20", comando: ["loginctl", "lock-session"] },
        { texto: "Suspender", icono: "M23.5 17.5 A10 10 0 1 1 10.5 4.5 A10.5 10.5 0 0 0 23.5 17.5 Z M20.5 4 V10 M17.5 7 H23.5", comando: ["systemctl", "suspend"], reposo: true },
        { texto: "Hibernar", icono: "M15 5 H24 L15 15 H24 M4 14 H11 L4 22 H11", comando: ["systemctl", "hibernate"], reposo: true },
        { texto: "Cerrar sesión", icono: "M13 4 H6 Q4 4 4 6 V22 Q4 24 6 24 H13 M11 14 H24 M19 9 L24 14 L19 19", comando: ["loginctl", "terminate-user", Quickshell.env("USER")] },
        { texto: "Reiniciar", icono: "M23.5 6.5 V12.5 H17.5 M23.5 12.5 A10 10 0 1 0 22 20", comando: ["systemctl", "reboot"] },
        { texto: "Apagar", icono: "M14 3 V13 M20.5 7 A9.5 9.5 0 1 1 7.5 7", comando: ["systemctl", "poweroff"], peligro: true }
    ]

    function ejecutar(indice: int): void {
        if (!abierto) return;
        const comando = acciones[indice].comando;
        // Apagar, reiniciar y cerrar sesión se despiden (Despedida.qml); el resto es inmediato
        const tipo = ({ "Cerrar sesión": "salir", "Reiniciar": "reiniciar", "Apagar": "apagar" })[acciones[indice].texto];
        cerrarY(() => tipo ? Despedida.hacer(comando, tipo) : Quickshell.execDetached(comando));
    }

    onAbriendose: contenidoApagado.forceActiveFocus()

    FocusScope {
        id: contenidoApagado
        width: parent.width
        implicitHeight: contenido.implicitHeight
        focus: true

        Keys.onPressed: evento => {
            const indice = evento.key - Qt.Key_1;
            if (indice < 0 || indice >= menu.acciones.length || (evento.modifiers & ~Qt.KeypadModifier)) return;
            evento.accepted = true;
            if (!evento.isAutoRepeat) menu.ejecutar(indice);
        }

        ColumnLayout {
            id: contenido
            width: parent.width
            spacing: EstiloPanel.e4

            RowLayout {
                Layout.fillWidth: true
                spacing: EstiloPanel.e3

                Text {
                    Layout.fillWidth: true
                    text: "Sesión y energía"
                    color: Paleta.texto
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: EstiloPanel.t26; weight: Font.DemiBold }
                }

                BotonCompacto {
                    Layout.preferredWidth: 52
                    implicitHeight: 30
                    text: "Esc"
                    Accessible.name: "Cerrar menú de apagado"
                    onClicked: menu.abierto = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: EstiloPanel.bordeFuerte
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 350 ? 3 : 2
                columnSpacing: EstiloPanel.e3
                rowSpacing: EstiloPanel.e3
                uniformCellWidths: true

                Repeater {
                    model: menu.acciones

                    AbstractButton {
                        id: tarjeta
                        required property int index
                        required property var modelData
                        readonly property color acento: modelData.peligro ? Paleta.peligro : modelData.reposo ? Paleta.acento2 : Paleta.acento
                        readonly property bool resaltada: hovered || visualFocus
                        readonly property real tinte: down ? .22 : resaltada ? .17 : modelData.peligro ? .10 : .07
                        Layout.fillWidth: true
                        Layout.preferredHeight: 126
                        padding: 0
                        hoverEnabled: true
                        focusPolicy: Qt.TabFocus
                        text: modelData.texto
                        Accessible.name: text + ", tecla " + (index + 1)
                        onClicked: menu.ejecutar(index)

                        background: Rectangle {
                            radius: EstiloPanel.rTarjeta
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: Qt.tint(EstiloPanel.elevada, Qt.alpha(tarjeta.acento, tarjeta.tinte))
                                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.tint(EstiloPanel.superficie, Qt.alpha(tarjeta.acento, tarjeta.tinte * .28))
                                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                }
                            }
                            border.color: Qt.alpha(tarjeta.acento, tarjeta.resaltada ? .85 : tarjeta.modelData.peligro ? .46 : .24)
                            border.width: 1
                        }

                        contentItem: Item {
                            Rectangle {
                                anchors { right: parent.right; top: parent.top; margins: EstiloPanel.e2 }
                                width: 26; height: 26; radius: EstiloPanel.rChip
                                color: Qt.tint(Paleta.fondo, Qt.alpha(tarjeta.acento, .20))

                                Rectangle {
                                    anchors { fill: parent; bottomMargin: 2 }
                                    radius: parent.radius
                                    color: Qt.tint(EstiloPanel.elevada, Qt.alpha(tarjeta.acento, tarjeta.resaltada ? .26 : .09))
                                    border { width: 1; color: Qt.alpha(tarjeta.acento, .28) }

                                    Text {
                                        anchors.centerIn: parent
                                        text: tarjeta.index + 1
                                        color: Paleta.texto
                                        font { family: Paleta.mono; pixelSize: EstiloPanel.t14; weight: Font.DemiBold }
                                    }
                                }
                            }

                            Rectangle {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: EstiloPanel.e4 }
                                width: Math.min(57, parent.width * .42)
                                height: width
                                radius: height / 2
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.alpha(tarjeta.acento, tarjeta.resaltada ? .35 : .27) }
                                    GradientStop { position: 1; color: Qt.alpha(tarjeta.acento, .065) }
                                }
                                border { width: 1; color: Qt.alpha(tarjeta.acento, .48) }

                                Rectangle {
                                    anchors { fill: parent; margins: 2 }
                                    radius: height / 2
                                    color: "transparent"
                                    border { width: 1; color: Qt.alpha(tarjeta.acento, .13) }
                                }

                                Shape {
                                    anchors.centerIn: parent
                                    width: 28; height: 28
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        strokeWidth: 2
                                        strokeColor: Qt.tint(tarjeta.acento, Qt.alpha(Paleta.texto, .23))
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        PathSvg { path: tarjeta.modelData.icono }
                                    }
                                }
                            }

                            Text {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: EstiloPanel.e2; bottomMargin: EstiloPanel.e4 }
                                text: tarjeta.text
                                color: Paleta.texto
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: EstiloPanel.t16; weight: Font.DemiBold }
                            }
                        }
                    }
                }
            }
        }
    }
}
