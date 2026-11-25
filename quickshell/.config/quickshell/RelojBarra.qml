// Isla viva: la isla del reloj se transforma según lo que pasa (estado compartido en Isla.qml).
//   reposo   ◷ 23:43 │ mar 24 nov          (o la cita cercana en lugar de la fecha)
//   música   carátula · canción · ondas │ 23:43       (pasa el ratón: se abre el minirreproductor)
//   aviso    icono ━━━━━━○── 41 %   o   icono texto   (volumen, brillo, micro, carga… durante 1,6 s)
// El ancho cambia con un pequeño rebote y el contenido entra deslizándose.
// Clic: Brújula · clic central con música: pausa / reanuda.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

IslaBarra {
    id: reloj
    required property date fecha
    property var cita: null
    property real anchoDisponible: 0
    property var ayuda: null
    property var ventana: null          // la barra (para anclar el minirreproductor)
    property bool avisos: true          // esta isla enseña los avisos (la del monitor enfocado)
    signal pulsado()

    readonly property string hora: Qt.formatTime(fecha, "HH:mm")
    readonly property string fechaBreve: fecha.toLocaleDateString(Qt.locale("es_CO"), "ddd d MMM").replace(/\./g, "")
    readonly property string fechaCompleta: fecha.toLocaleDateString(Qt.locale("es_CO"), "dddd, d 'de' MMMM")
    readonly property bool conFecha: !cita && anchoDisponible >= 180
    readonly property bool conCita: !!cita && anchoDisponible >= 130

    readonly property bool privado: EstadoEscritorio.privacidad || EstadoEscritorio.capturaPrivada
    readonly property string modo: avisos && Isla.aviso && Isla.enBarra ? "aviso"
                                 : Isla.suena && !privado && anchoDisponible >= 300 ? "musica"
                                 : "reposo"
    readonly property Item capa: modo === "aviso" ? capaAviso : modo === "musica" ? capaMusica : capaReposo

    function g(cp) { return String.fromCodePoint(cp); }




    tinte: modo === "aviso" ? .10 : zona.containsMouse ? .09 : modo === "musica" ? .06 : .04
    acento: modo === "aviso" ? Isla.tono : Paleta.acento
    implicitWidth: capa.implicitWidth + 24
    Behavior on implicitWidth {
        enabled: EstiloPanel.movimiento
        NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }
    Behavior on tinte { NumberAnimation { duration: EstiloPanel.normal } }

    Accessible.role: Accessible.Button
    Accessible.name: modo === "musica" ? hora + ", sonando " + Isla.titulo + (Isla.artista ? " de " + Isla.artista : "")
                   : hora + ", " + fechaCompleta + (conCita ? ", " + cita.titulo + ", " + cita.cuando : "")
    Accessible.onPressAction: reloj.pulsado()

    // Halo del acento que destella con cada aviso
    RectangularShadow {
        id: destello
        anchors.fill: parent; z: -1
        visible: EstiloPanel.profundidad && opacity > 0
        radius: height / 2; blur: 18; spread: -2
        color: Qt.alpha(Isla.tono, .55)
        opacity: 0
    }
    Connections {
        target: Isla
        function onNumeroChanged() {
            if (reloj.modo !== "aviso" || !EstiloPanel.movimiento) return;
            latido.restart();
        }
    }
    ParallelAnimation {
        id: latido
        SequentialAnimation {
            NumberAnimation { target: iconoAviso; property: "scale"; to: 1.25; duration: 70; easing.type: Easing.OutCubic }
            NumberAnimation { target: iconoAviso; property: "scale"; to: 1; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
        }
        SequentialAnimation {
            NumberAnimation { target: destello; property: "opacity"; to: 1; duration: 70 }
            NumberAnimation { target: destello; property: "opacity"; to: 0; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    Item {
        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
        clip: true

        // ── Reposo: hora y fecha (o la cita cercana) ──
        IslaCapa {
            id: capaReposo
            activa: reloj.modo === "reposo"
            Glifo { text: "󰥔"; color: Paleta.acento; font.pixelSize: 14 }
            Text {
                text: reloj.hora
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; bold: true; features: { "tnum": 1 } }
            }
            Rectangle {
                visible: reloj.conFecha || reloj.conCita
                implicitWidth: 1; implicitHeight: 12
                color: EstiloPanel.bordeFuerte
            }
            Text {
                visible: reloj.conFecha
                text: reloj.fechaBreve
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12; weight: Font.Medium }
            }
            Text {
                visible: reloj.conCita
                Layout.preferredWidth: Math.min(implicitWidth, Math.max(36, Math.min(170, reloj.anchoDisponible - 112)))
                text: reloj.cita ? (reloj.anchoDisponible >= 210 ? reloj.cita.titulo + " · " : "") + reloj.cita.cuando : ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Paleta.acento
                font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
            }
        }

        // ── Música: carátula, canción, ondas y la hora ──
        IslaCapa {
            id: capaMusica
            activa: reloj.modo === "musica"
            IslaCaratula { lado: 22; Layout.alignment: Qt.AlignVCenter }
            Text {
                Layout.maximumWidth: Math.max(60, Math.min(200, reloj.anchoDisponible - 260))
                text: Isla.titulo
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
            }
            Row {   // ondas de cava (las mismas que antes iban a la derecha de la barra)
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        width: 3; radius: width / 2
                        height: 3 + (Isla.ondas[index + 2] / 100) * 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.tint(Paleta.acento, Qt.alpha(Paleta.aviso, index / 8))
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
            Rectangle { implicitWidth: 1; implicitHeight: 12; color: EstiloPanel.bordeFuerte }
            Text {
                text: reloj.hora
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; bold: true; features: { "tnum": 1 } }
            }
        }

        // ── Aviso: volumen, brillo, micro, mensajes ──
        IslaCapa {
            id: capaAviso
            activa: reloj.modo === "aviso"
            spacing: 12
            Glifo {
                id: iconoAviso
                text: Isla.icono
                color: Isla.apagado ? Paleta.gris : Qt.lighter(Isla.tono, 1.08)
                font { family: Paleta.mono; pixelSize: 16 }
            }
            Rectangle {   // barra con punta luminosa
                visible: Isla.valor >= 0
                implicitWidth: 120; implicitHeight: 4
                radius: height / 2
                color: EstiloPanel.velo
                Rectangle {
                    id: relleno
                    height: parent.height; radius: height / 2
                    width: parent.width * Math.min(1, Math.max(0, Isla.valor))
                    color: Isla.tono
                    Behavior on width { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    visible: !Isla.apagado
                    x: relleno.width - width / 2; anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: height / 2
                    color: Qt.lighter(Isla.tono, 1.25)
                    RectangularShadow {
                        anchors.fill: parent; z: -1
                        visible: EstiloPanel.profundidad
                        radius: parent.radius; blur: 8
                        color: Qt.alpha(Isla.tono, .7)
                    }
                }
            }
            Text {
                visible: Isla.valor >= 0
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(Isla.valor * 100) + " %"
                color: Isla.apagado ? Paleta.gris : Paleta.texto
                font { family: Paleta.fuente; pixelSize: 12; bold: true; features: { "tnum": 1 } }
            }
            Text {
                visible: Isla.valor < 0 && Isla.texto !== ""
                Layout.maximumWidth: Math.max(80, Math.min(280, reloj.anchoDisponible - 80))
                text: Isla.texto
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: Isla.apagado ? EstiloPanel.tenue : Paleta.texto
                font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
            }
        }
    }

    // Progreso de la canción: un hilo de luz en el borde inferior de la isla
    Rectangle {
        visible: reloj.modo === "musica" && (Isla.jugador?.lengthSupported ?? false) && Isla.jugador.length > 0
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 16; bottomMargin: 2 }
        height: 1.5; radius: height / 2
        width: (parent.width - 32) * Math.min(1, (Isla.jugador?.position ?? 0) / Math.max(1, Isla.jugador?.length ?? 1))
        color: Qt.alpha(Paleta.acento, .7)
        Behavior on width { NumberAnimation { duration: 900 } }
    }
    Timer {   // la posición no se actualiza sola
        interval: 1000; repeat: true
        running: (reloj.modo === "musica" || mini.visible) && Isla.suena
        onTriggered: Isla.jugador?.positionChanged()
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.MiddleButton) { if (Isla.jugador?.canTogglePlaying) Isla.jugador.togglePlaying(); return; }
            mini.cerrar();
            reloj.pulsado();
        }
        onEntered: { if (reloj.modo === "musica") abrirMini.restart(); else reloj.ayuda?.mostrar(reloj, reloj.fechaCompleta); }
        onExited: { abrirMini.stop(); reloj.ayuda?.ocultar(); cerrarMini.restart(); }
    }
    Timer { id: abrirMini; interval: 350; onTriggered: if (reloj.modo === "musica" && zona.containsMouse) mini.abrir() }
    Timer { id: cerrarMini; interval: 300; onTriggered: if (!zona.containsMouse && !zonaMini.containsMouse) mini.cerrar() }
    onModoChanged: if (modo !== "musica") mini.cerrar()

    // ── Minirreproductor: la isla «se abre» hacia abajo ──
    PopupWindow {
        id: mini
        property bool abierto: false
        function abrir() { if (!reloj.ventana) return; cerrando.stop(); visible = true; abierto = true; }
        function cerrar() { if (!abierto) return; abierto = false; cerrando.restart(); }
        Timer { id: cerrando; interval: EstiloPanel.normal + 20; onTriggered: if (!mini.abierto) mini.visible = false }

        anchor.window: reloj.ventana
        anchor.rect.x: reloj.mapToItem(null, 0, 0).x + reloj.width / 2 - implicitWidth / 2
        anchor.rect.y: reloj.mapToItem(null, 0, 0).y
        implicitWidth: 360
        implicitHeight: 150
        color: "transparent"

        Item {
            id: tarjetaMini
            x: 12; y: 0
            width: parent.width - 24; height: 128
            transformOrigin: Item.Top
            // nace con el tamaño de la isla y crece con rebote
            scale: mini.abierto ? 1 : .55
            opacity: mini.abierto ? 1 : 0
            Behavior on scale { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }

            FondoPanel { anchors.fill: parent; radio: EstiloPanel.rPanel; acento: Paleta.acento }

            MouseArea {
                id: zonaMini
                anchors.fill: parent
                hoverEnabled: true
                onExited: cerrarMini.restart()
            }

            RowLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 16
                IslaCaratula { lado: 80; Layout.alignment: Qt.AlignVCenter }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: Isla.titulo
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 14; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: Isla.artista
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    RowLayout {
                        Layout.topMargin: 4
                        spacing: 8
                        IslaBoton { glifo: reloj.g(0xF04AE); onPulsado: Isla.jugador?.previous() }
                        IslaBoton { glifo: reloj.g((Isla.jugador?.isPlaying ?? false) ? 0xF03E4 : 0xF040A); principal: true; onPulsado: Isla.jugador?.togglePlaying() }
                        IslaBoton { glifo: reloj.g(0xF04AD); onPulsado: Isla.jugador?.next() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: (Isla.jugador?.lengthSupported ?? false) && Isla.jugador.length > 0
                        implicitHeight: 4; radius: height / 2
                        color: EstiloPanel.velo
                        Rectangle {
                            height: parent.height; radius: height / 2
                            width: parent.width * Math.min(1, (Isla.jugador?.position ?? 0) / Math.max(1, Isla.jugador?.length ?? 1))
                            color: Paleta.acento
                            Behavior on width { NumberAnimation { duration: 900 } }
                        }
                    }
                }
            }
        }
    }


}
