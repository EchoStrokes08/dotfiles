// IslaActividades: la burbuja de lo que está en marcha (Actividades.qml), pegada a la isla del reloj.
// Aparece «separándose» de la isla: nace pequeña pegada a su borde y se despega con un rebote, como una gota;
// al acabar vuelve a pegarse y desaparece.
// Compacta: hasta tres círculos (icono con su anillo de progreso; la grabación late) y el tiempo de la primera.
// Con el ratón encima se despliega una tarjeta con todas: título, detalle, barra de progreso y su acción.
//   En Barra.qml: IslaActividades { ventana: barra; isla: centro }
import QtQuick
import QtQuick.Shapes
import Quickshell

Item {
    id: ia
    property var ventana: null
    property Item isla: null             // la isla del reloj: de ahí sale
    readonly property var lista: Actividades.lista
    readonly property bool hay: lista.length > 0
    readonly property var primera: lista[0] ?? null

    implicitWidth: burbuja.width
    implicitHeight: 34
    visible: burbuja.opacity > .01 || hay

    function g(cp) { return String.fromCodePoint(cp); }

    IslaBarra {
        id: burbuja
        height: 34
        width: fila.implicitWidth + 20
        acento: ia.primera?.color ?? Paleta.acento
        tinte: .08
        Behavior on width { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        // Se separa de la isla: sale de detrás (a la izquierda) hasta su sitio
        transform: Translate {
            id: fuera
            x: ia.hay ? 0 : -16
            Behavior on x { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        opacity: ia.hay ? 1 : 0
        scale: ia.hay ? 1 : .3
        transformOrigin: Item.Left
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
        Behavior on scale { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack } }

        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 8
            Repeater {
                model: ia.lista.slice(0, 3)
                Item {
                    id: circulo
                    required property var modelData
                    required property int index
                    width: 22; height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: Qt.alpha(circulo.modelData.color, .18)
                        // la grabación late
                        SequentialAnimation on opacity {
                            running: circulo.modelData.late === true && EstiloPanel.movimiento
                            loops: Animation.Infinite
                            NumberAnimation { to: .35; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                    // Anillo de progreso (si lo tiene)
                    Shape {
                        anchors.fill: parent
                        visible: circulo.modelData.progreso >= 0
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: circulo.modelData.color
                            strokeWidth: 2
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 11; centerY: 11; radiusX: 10; radiusY: 10
                                startAngle: -90
                                sweepAngle: 360 * Math.max(0, Math.min(1, circulo.modelData.progreso))
                            }
                        }
                    }
                    Glifo {
                        anchors.centerIn: parent; alto: 22
                        text: ia.g(circulo.modelData.icono)
                        color: circulo.modelData.color
                        font { family: Paleta.mono; pixelSize: 12 }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: ia.primera?.corto ?? ""
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 12; bold: true; features: { "tnum": 1 } }
            }
            Text {   // «+2» si hay más de tres
                anchors.verticalCenter: parent.verticalCenter
                visible: ia.lista.length > 3
                text: "+" + (ia.lista.length - 3)
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 11; bold: true }
            }
        }

        HoverHandler {
            id: encima
            onHoveredChanged: hovered ? (cerrarT.stop(), abrirT.restart()) : (abrirT.stop(), cerrarT.restart())
        }
    }
    Timer { id: abrirT; interval: 250; onTriggered: if (ia.hay) tarjeta.abrir() }
    Timer { id: cerrarT; interval: 300; onTriggered: if (!encima.hovered && !sobreTarjeta.hovered) tarjeta.cerrar() }
    onHayChanged: if (!hay) tarjeta.cerrar()

    // ── La tarjeta desplegada ──
    PopupWindow {
        id: tarjeta
        property bool abierto: false
        function abrir() { if (!ia.ventana) return; cerrando.stop(); visible = true; abierto = true; }
        function cerrar() { if (!abierto) return; abierto = false; cerrando.restart(); }
        Timer { id: cerrando; interval: EstiloPanel.normal + 20; onTriggered: if (!tarjeta.abierto) tarjeta.visible = false }

        anchor.window: ia.ventana
        anchor.rect.x: ia.mapToItem(null, 0, 0).x + ia.width / 2 - implicitWidth / 2
        anchor.rect.y: ia.mapToItem(null, 0, 0).y + ia.height + 6
        implicitWidth: 340
        implicitHeight: columna.implicitHeight + 32 + 24
        color: "transparent"

        Item {
            x: 12; y: 0
            width: parent.width - 24; height: columna.implicitHeight + 32
            transformOrigin: Item.Top
            scale: tarjeta.abierto ? 1 : .55
            opacity: tarjeta.abierto ? 1 : 0
            Behavior on scale { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }

            FondoPanel { anchors.fill: parent; radio: EstiloPanel.rPanel; acento: ia.primera?.color ?? Paleta.acento }
            MouseArea { anchors.fill: parent }
            HoverHandler { id: sobreTarjeta; onHoveredChanged: hovered ? cerrarT.stop() : cerrarT.restart() }

            Column {
                id: columna
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 12
                Repeater {
                    model: ia.lista
                    Item {
                        id: filaA
                        required property var modelData
                        width: columna.width
                        height: 40 + (modelData.progreso >= 0 ? 12 : 0)
                        Rectangle {
                            id: icono
                            width: 36; height: 36; radius: height / 2
                            color: Qt.alpha(filaA.modelData.color, .16)
                            Glifo { anchors.centerIn: parent; alto: 36; text: ia.g(filaA.modelData.icono); color: filaA.modelData.color; font { family: Paleta.mono; pixelSize: 16 } }
                        }
                        Column {
                            anchors { left: icono.right; leftMargin: 12; right: accion.left; rightMargin: 8; top: parent.top }
                            spacing: 2
                            Text { width: parent.width; elide: Text.ElideRight; text: filaA.modelData.titulo; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                            Text { width: parent.width; elide: Text.ElideRight; text: filaA.modelData.detalle ?? ""; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12; features: { "tnum": 1 } } }
                        }
                        Rectangle {   // progreso
                            visible: filaA.modelData.progreso >= 0
                            anchors { left: icono.right; leftMargin: 12; right: parent.right; bottom: parent.bottom }
                            height: 4; radius: height / 2
                            color: Qt.alpha(Paleta.texto, .1)
                            Rectangle {
                                height: parent.height; radius: height / 2
                                width: parent.width * Math.max(0, Math.min(1, filaA.modelData.progreso))
                                color: filaA.modelData.color
                                Behavior on width { NumberAnimation { duration: EstiloPanel.normal } }
                            }
                        }
                        Rectangle {
                            id: accion
                            visible: !!filaA.modelData.accion
                            anchors { right: parent.right; top: parent.top; topMargin: 2 }
                            width: visible ? 32 : 0; height: 32; radius: height / 2
                            color: botonA.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                            Glifo { anchors.centerIn: parent; alto: 32; text: filaA.modelData.accion ? ia.g(filaA.modelData.accion.icono) : ""; color: Paleta.texto; font { family: Paleta.mono; pixelSize: 14 } }
                            MouseArea {
                                id: botonA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const a = filaA.modelData.accion;
                                    if (a?.fn) a.fn(); else if (a?.cmd) Quickshell.execDetached(a.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
