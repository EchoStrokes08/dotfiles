// Reposo: si dejas el equipo quieto un rato (5 min enchufado, 2½ con batería; antes de que baje el brillo),
// la pantalla se convierte en un reloj de mesa: tu fondo desenfocado que se mueve muy despacio, la hora
// enorme con los dos puntos que respiran, la fecha, el clima, la batería, lo próximo de la agenda y lo que
// suena con su carátula. Al tocar cualquier cosa se deshace en un instante.
// No sale con pantalla completa, jugando, presentando, en reunión ni si una app impide la inactividad
// (vídeo, llamada). Con privacidad no enseña la música ni la agenda. Interruptor en Apariencia.
// Todo el bloque se desplaza unos px cada minuto para no marcar la pantalla.
// Al volver (ya desbloqueado, si se llegó a bloquear) la isla dice cuánto estuviste fuera y cuántos avisos
// llegaron mientras tanto.
//   qs ipc call reposo probar      (se va al mover el ratón)
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: r

    // ── cuándo ─────────────────────────────────────────────────────────────────────────────────────
    readonly property bool permitido: PreferenciasUI.reposo && !Isla.pantallaCompleta
        && EstadoEscritorio.datos.juego_activo !== "true" && EstadoEscritorio.datos.presentacion !== "true"
        && EstadoEscritorio.datos.reunion !== "true"
    IdleMonitor {
        id: quieto
        enabled: r.permitido
        respectInhibitors: true
        timeout: Cargador.conBateria ? 150 : 300
        onIsIdleChanged: isIdle ? r.entrar() : r.salir()
    }
    IpcHandler {
        target: "reposo"
        function probar(): void { r.entrar(); }
        function salir(): void { r.salir(); }
    }

    property bool activo: false
    property real p: 0                       // 0 → 1 al entrar (fundido lento), de vuelta rápido al salir
    property bool saliendo: false
    property real desde: 0                   // Date.now() al entrar: el movimiento del ratón de justo después no cuenta
    property real fuera: 0                   // desde cuándo no se toca el equipo
    property int avisosAntes: 0
    function entrar() {
        if (activo) return;
        fuera = Date.now() - (quieto.isIdle ? quieto.timeout * 1000 : 0);
        avisosAntes = Notificaciones.lista.length;
        ruta.running = true;
        screen = Quickshell.screens.find(s => s.name === Isla.enfocado) ?? Quickshell.screens[0];
        desde = Date.now();
        saliendo = false;
        activo = true;
        salida.stop();
        entrada.restart();
    }
    function salir() {
        if (!activo) return;
        activo = false;
        entrada.stop();
        saliendo = true;
        salida.restart();
        if (Date.now() - fuera >= 180000) libre.running = true;   // «volviste»: cuando no haya bloqueo
    }
    // espera a que la pantalla de bloqueo se haya ido (si la hubo) y saluda desde la isla
    Process {
        id: libre
        command: ["qs", "ipc", "call", "bloqueo", "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "libre" || text.indexOf("not found") >= 0) {
                    otra.stop();
                    const min = Math.round((Date.now() - r.fuera) / 60000);
                    const t = min < 60 ? `${min} min` : `${Math.floor(min / 60)} h ${String(min % 60).padStart(2, "0")} min`;
                    const n = Math.max(0, Notificaciones.lista.length - r.avisosAntes);
                    Isla.mostrar(String.fromCodePoint(0xF1821), -1,
                                 `Volviste · ${t} fuera` + (n ? ` · ${n} aviso${n > 1 ? "s" : ""}` : ""), false, 3200);
                } else otra.restart();
            }
        }
    }
    Timer { id: otra; interval: 1000; onTriggered: libre.running = true }
    NumberAnimation { id: entrada; target: r; property: "p"; to: 1; duration: EstiloPanel.movimiento ? 1800 : 0; easing.type: Easing.InOutSine }
    NumberAnimation {
        id: salida; target: r; property: "p"; to: 0; duration: EstiloPanel.normal; easing.type: Easing.OutCubic
        onFinished: r.saliendo = false
    }

    visible: activo || saliendo
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-reposo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── datos ──────────────────────────────────────────────────────────────────────────────────────
    property string fondo: ""
    Process {
        id: ruta
        command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/tema/wallpaper"]
        stdout: StdioCollector { onStreamFinished: r.fondo = text.trim() }
    }
    SystemClock { id: reloj; precision: SystemClock.Minutes; enabled: r.visible }
    readonly property bool privado: EstadoEscritorio.privacidad
    readonly property var proximo: {
        reloj.date;
        const e = privado ? [] : Eventos.proximos(1);
        return e.length && e[0].inicio - Date.now() < 18 * 3600000 ? e[0] : null;
    }
    readonly property var bateria: UPower.displayDevice
    readonly property bool hayBateria: bateria?.isLaptopBattery ?? false
    readonly property bool cargando: bateria?.state === UPowerDeviceState.Charging
    readonly property bool llena: bateria?.state === UPowerDeviceState.FullyCharged
    readonly property bool musica: Isla.suena && !privado && Isla.titulo !== ""

    // el bloque se mueve un poco cada minuto (contra el marcado de la pantalla)
    property real dx: 0
    property real dy: 0
    Connections {
        target: reloj
        enabled: r.activo
        function onDateChanged() { r.dx = (Math.random() * 2 - 1) * 24; r.dy = (Math.random() * 2 - 1) * 16; }
    }
    Behavior on dx { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }
    Behavior on dy { NumberAnimation { duration: 4000; easing.type: Easing.InOutSine } }

    // ── fondo: la imagen desenfocada que deriva muy despacio ───────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: r.p
        clip: true

        Rectangle { anchors.fill: parent; color: Paleta.cieloNoche }
        Image {
            id: imagen
            anchors.centerIn: parent
            width: parent.width; height: parent.height
            source: r.fondo ? "file://" + r.fondo : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(960, 540)            // va desenfocada: con poca resolución basta
            asynchronous: true
            visible: false
        }
        MultiEffect {
            id: deriva
            anchors.fill: parent
            source: imagen
            visible: imagen.status === Image.Ready
            blurEnabled: true; blur: 1; blurMax: 48
            saturation: .15
            brightness: -.28
            property real fase: 0
            scale: 1.12 + .04 * Math.sin(fase)
            x: 28 * Math.sin(fase * .7)
            y: 18 * Math.cos(fase * .5)
            NumberAnimation on fase {
                running: r.visible && EstiloPanel.movimiento
                from: 0; to: Math.PI * 20; duration: 600000; loops: Animation.Infinite
            }
        }
        // viñeta: más oscuro en los bordes, la hora queda en una luz
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Paleta.cieloNoche, .55) }
                GradientStop { position: .45; color: Qt.alpha(Paleta.cieloNoche, .12) }
                GradientStop { position: 1; color: Qt.alpha(Paleta.cieloNoche, .7) }
            }
        }
    }

    // ── el reloj ───────────────────────────────────────────────────────────────────────────────────
    Item {
        id: bloque
        width: columna.width; height: columna.height
        x: (parent.width - width) / 2 + r.dx
        y: (parent.height - height) / 2 - 24 + r.dy + (1 - r.p) * 40
        opacity: Math.max(0, (r.p - .35) / .65)
        scale: r.saliendo ? 1 + (1 - r.p) * .06 : 1

        Column {
            id: columna
            spacing: 16

            Row {
                id: hora
                anchors.horizontalCenter: parent.horizontalCenter
                layer.enabled: true
                layer.effect: MultiEffect {   // un halo del acento detrás de las cifras
                    shadowEnabled: true; shadowBlur: 1; shadowColor: Qt.alpha(Paleta.acento, .45)
                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; blurMax: 64
                }
                readonly property string hh: Qt.formatTime(reloj.date, "HH")
                readonly property string mm: Qt.formatTime(reloj.date, "mm")
                Text {
                    text: hora.hh; color: Paleta.sobreImagen
                    font { family: Paleta.fuente; pixelSize: 150; weight: Font.Light; features: { "tnum": 1 } }
                }
                Text {
                    id: dosPuntos
                    text: ":"; color: Paleta.acento
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -12
                    font { family: Paleta.fuente; pixelSize: 150; weight: Font.Light }
                    SequentialAnimation on opacity {
                        running: r.visible && EstiloPanel.movimiento
                        loops: Animation.Infinite
                        NumberAnimation { to: .3; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: hora.mm; color: Paleta.sobreImagen
                    font { family: Paleta.fuente; pixelSize: 150; weight: Font.Light; features: { "tnum": 1 } }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const t = reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM");
                    return t.charAt(0).toUpperCase() + t.slice(1);
                }
                color: Qt.alpha(Paleta.sobreImagen, .8)
                font { family: Paleta.fuente; pixelSize: 26 }
            }

            // clima · batería · agenda
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                topPadding: 16

                Chip {
                    visible: Clima.listo
                    icono: Clima.icono(Clima.codigo, Clima.deDia)
                    texto: `${Math.round(Clima.temp)}°  ${Clima.texto(Clima.codigo)}`
                }
                Chip {
                    visible: r.hayBateria
                    tono: r.cargando || r.llena ? Paleta.exito : Cargador.porcentaje <= 15 ? Paleta.peligro : Paleta.sobreImagen
                    icono: String.fromCodePoint(r.cargando ? 0xF0084 : r.llena ? 0xF06A5 : 0xF0079)
                    texto: `${Cargador.porcentaje} %` + (r.cargando ? "  cargando" : r.llena ? "  llena" : "")
                    progreso: r.cargando ? Cargador.porcentaje / 100 : -1
                }
                Chip {
                    visible: r.proximo !== null
                    icono: String.fromCodePoint(0xF00ED)
                    texto: r.proximo ? `${Eventos.cuando(r.proximo)} · ${r.proximo.titulo}` : ""
                }
            }

            // lo que suena
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: tarjeta.width; height: r.musica ? tarjeta.height + 16 : 0
                visible: r.musica
                Rectangle {
                    id: tarjeta
                    y: 16
                    width: Math.min(520, filaMusica.implicitWidth + 24); height: 80
                    radius: 16
                    color: Qt.alpha(Paleta.cieloNoche, .35)
                    border.color: Qt.alpha(Paleta.sobreImagen, .1)
                    Row {
                        id: filaMusica
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                        spacing: 12
                        Rectangle {
                            width: 56; height: 56; radius: 12
                            color: Qt.alpha(Paleta.sobreImagen, .08)
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: Isla.caratula
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(112, 112)
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true; maskThresholdMin: .5; maskSpreadAtMin: 1
                                    maskSource: ShaderEffectSource {
                                        sourceItem: Rectangle { width: 56; height: 56; radius: 12 }
                                    }
                                }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, 420)
                            spacing: 4
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: Isla.titulo; color: Paleta.sobreImagen
                                font { family: Paleta.fuente; pixelSize: 16; weight: Font.DemiBold }
                            }
                            Row {
                                spacing: 8
                                // ondas de la isla (cava): late con la música
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Repeater {
                                        model: 5
                                        Rectangle {
                                            required property int index
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3; radius: width / 2
                                            height: 3 + 11 * Math.min(1, Isla.ondas[index * 2] ?? 0)
                                            color: Paleta.acento
                                            Behavior on height { SmoothedAnimation { duration: 90 } }
                                        }
                                    }
                                }
                                Text {
                                    width: Math.min(implicitWidth, 380); elide: Text.ElideRight
                                    text: Isla.artista; color: Qt.alpha(Paleta.sobreImagen, .7)
                                    font { family: Paleta.fuente; pixelSize: 13 }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // pista discreta abajo
    Text {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 32 }
        opacity: Math.max(0, (r.p - .7) / .3) * .45
        text: "Toca cualquier tecla o mueve el ratón para volver"
        color: Paleta.sobreImagen
        font { family: Paleta.fuente; pixelSize: 12 }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        onPositionChanged: if (Date.now() - r.desde > 900) r.salir()
        onPressed: r.salir()
        onWheel: r.salir()
    }

    // ── una pastilla: icono + texto, con anillo opcional ───────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property string icono: ""
        property string texto: ""
        property color tono: Paleta.sobreImagen
        property real progreso: -1
        width: filaChip.implicitWidth + 32; height: 36
        radius: height / 2
        color: Qt.alpha(Paleta.cieloNoche, .35)
        border.color: Qt.alpha(Paleta.sobreImagen, .1)
        Row {
            id: filaChip
            anchors.centerIn: parent
            spacing: 8
            Item {
                width: 20; height: 20
                anchors.verticalCenter: parent.verticalCenter
                Shape {
                    anchors.fill: parent
                    visible: chip.progreso >= 0
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"; strokeColor: chip.tono; strokeWidth: 2; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 10; centerY: 10; radiusX: 9; radiusY: 9; startAngle: -90; sweepAngle: 360 * chip.progreso }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: chip.icono; color: chip.tono
                    font { family: Paleta.fuente; pixelSize: chip.progreso >= 0 ? 11 : 16 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.texto; color: Qt.alpha(Paleta.sobreImagen, .9)
                font { family: Paleta.fuente; pixelSize: 14 }
            }
        }
    }
}
