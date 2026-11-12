// Centro de control (SUPER+N o clic en la campana): sustituye al panel de swaync.
//   botones rápidos · volumen (general y por app) · brillo · música · no molestar · historial
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: ventana
    property bool abierto: false
    property bool mostrar: false

    function g(cp) { return String.fromCodePoint(cp); }
    function ejecutar(cmd, cerrarPanel) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        if (cerrarPanel) abierto = false;
    }

    onAbiertoChanged: {
        if (abierto) { cierre.stop(); mostrar = true; leerConmutadores.running = true; lectorBrillo.running = true; }
        else cierre.restart();
    }
    Timer { id: cierre; interval: 240; onTriggered: ventana.mostrar = false }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-centro"
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: ventana.abierto = false }   // clic fuera = cerrar

    // ── Estado de los conmutadores ──────────────────────────────────────
    property var estados: ({})        // { wifi: true, bluetooth: false, … }
    Process {
        id: leerConmutadores
        command: ["sh", "-c", "~/.config/hypr/scripts/conmutadores.sh todos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const e = {};
                for (const l of this.text.trim().split("\n")) { const p = l.split(" "); e[p[0]] = p[1] === "on"; }
                ventana.estados = e;
            }
        }
    }
    Timer { id: releer; interval: 700; onTriggered: leerConmutadores.running = true }
    function conmutar(cosa) {
        const nuevo = !estados[cosa];
        const e = Object.assign({}, estados); e[cosa] = nuevo; estados = e;   // respuesta inmediata
        Quickshell.execDetached(["sh", "-c", `~/.config/hypr/scripts/conmutadores.sh ${cosa} ${nuevo ? "on" : "off"}`]);
        releer.restart();                                                        // y luego confirmar
    }

    // ── Brillo ──────────────────────────────────────────────────────────
    property real brillo: 0
    Process {
        id: lectorBrillo
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: ventana.brillo = (parseInt(this.text.split(",")[3]) || 0) / 100 }
    }

    // ── Audio ───────────────────────────────────────────────────────────
    readonly property var salida: Pipewire.defaultAudioSink
    // solo apps que SUENAN (Stream/Output); las que graban (p. ej. el replay) son Stream/Input
    readonly property var apps: Pipewire.nodes.values.filter(n => n.isStream && n.audio && n.properties["media.class"] === "Stream/Output/Audio")
    // dispositivos de salida (altavoces, Buds, HDMI…) y el micrófono por defecto
    readonly property var salidas: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && n.name !== "easyeffects_sink")   // el sink virtual de EasyEffects no es una salida que elegir
    readonly property var entrada: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [ventana.salida, ventana.entrada, ...ventana.apps] }
    function iconoSalida(n) {
        const id = n.name ?? "";
        return g(id.startsWith("bluez") ? 0xF02CB : id.includes("hdmi") ? 0xF0379 : 0xF04C3);
    }

    SystemClock { id: relojCC; precision: SystemClock.Hours }

    // ── El panel ────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        width: 420
        anchors { top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
        x: ventana.abierto ? parent.width - width - 8 : parent.width + 10
        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        color: "transparent"
        FondoPanel { anchors.fill: parent; radio: 22; opacidad: .86 }
        MouseArea { anchors.fill: parent }
        focus: ventana.abierto
        Keys.onEscapePressed: ventana.abierto = false

        ColumnLayout {
            anchors { fill: parent; margins: 18 }
            spacing: 14

            // Título + borrar todo
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 40; implicitHeight: 40; radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(Qt.lighter(Paleta.naranja, 1.15), .40) }
                        GradientStop { position: 1; color: Qt.alpha(Paleta.naranja, .12) }
                    }
                    border { width: 1; color: Qt.alpha(Paleta.naranja, .5) }
                    Text { anchors.centerIn: parent; text: ventana.g(0xF0493); color: Qt.lighter(Paleta.naranja, 1.2); font { family: Paleta.fuente; pixelSize: 19 } }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: relojCC.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM").toUpperCase()
                        color: Paleta.naranja
                        font { family: EstiloPanel.fuente; pixelSize: 9; bold: true; letterSpacing: 1.8 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Centro de control"
                        color: Paleta.texto
                        font { family: EstiloPanel.fuente; pixelSize: 19; weight: Font.DemiBold }
                    }
                }
                Rectangle {
                    visible: Notificaciones.lista.length > 0
                    implicitWidth: textoBorrar.implicitWidth + 24; implicitHeight: 30; radius: 15
                    color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.rojo, 0.22) : Qt.alpha(Paleta.texto, 0.06)
                    border { width: 1; color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.rojo, .5) : Qt.alpha(Paleta.texto, .1) }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text { id: textoBorrar; anchors.centerIn: parent; text: ventana.g(0xF0A7A) + "  Borrar todo"; color: zonaBorrar.containsMouse ? Paleta.rojo : Paleta.texto; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                    MouseArea { id: zonaBorrar; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notificaciones.borrarTodo() }
                }
            }

            // Botones rápidos (5 por fila)
            GridLayout {
                Layout.fillWidth: true
                columns: 5
                columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: [
                        { icono: 0xF0928, nombre: "Wi-Fi",       cosa: "wifi" },
                        { icono: 0xF00AF, nombre: "Bluetooth",   cosa: "bluetooth" },
                        { icono: 0xF044B, nombre: "Replay",      cosa: "replay" },
                        { icono: 0xF140B, nombre: "Rendimiento", cosa: "rendimiento" },
                        { icono: 0xF032A, nombre: "Conservar",   cosa: "conservacion" },   // batería hasta ~80 %
                        { icono: 0xF0594, nombre: "Luz noche",   cosa: "luz" },
                        { icono: 0xF02CB, nombre: "Buds",        cmd: "~/.local/bin/buds mode next --notify" },
                        { icono: 0xF0E51, nombre: "Captura",     cmd: "sleep 0.4 && mkdir -p ~/Imágenes/screenshots && grim -g \"$(slurp)\" - | tee ~/Imágenes/screenshots/$(date +'%Y%m%d_%H%M%S_grim.png') | wl-copy", cerrar: true },
                        { icono: 0xF033E, nombre: "Bloquear",    cmd: "loginctl lock-session", cerrar: true },
                        { icono: 0xF0425, nombre: "Apagar",      cmd: "wlogout", cerrar: true }
                    ]
                    Item {
                        id: boton
                        required property var modelData
                        readonly property bool encendido: modelData.cosa ? (ventana.estados[modelData.cosa] ?? false) : false
                        Layout.fillWidth: true
                        implicitHeight: 70
                        scale: zonaBoton.pressed ? .94 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        FondoBoton {
                            anchors.fill: parent
                            radio: 16
                            tinte: Paleta.naranja
                            destacado: boton.encendido
                            encima: zonaBoton.containsMouse
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ventana.g(boton.modelData.icono)
                                color: boton.encendido ? Qt.lighter(Paleta.naranja, 1.2) : Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 21 }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: boton.modelData.nombre
                                color: boton.encendido ? Paleta.texto : Paleta.gris
                                font { family: Paleta.fuente; pixelSize: 9; bold: boton.encendido }
                            }
                        }
                        MouseArea {
                            id: zonaBoton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // clic derecho en Wi-Fi/Bluetooth: abrir la lista (Conexiones.qml)
                            onClicked: (e) => {
                                if (e.button === Qt.RightButton && (modelData.cosa === "wifi" || modelData.cosa === "bluetooth"))
                                    ventana.ejecutar("qs ipc call conexiones " + modelData.cosa, true);
                                else if (e.button === Qt.LeftButton)
                                    modelData.cosa ? ventana.conmutar(modelData.cosa) : ventana.ejecutar(modelData.cmd, modelData.cerrar);
                            }
                        }
                    }
                }
            }

            // Sonido y brillo, juntos en una tarjeta
            TarjetaPanel {
                Layout.fillWidth: true
                espaciado: 8
                relleno: 12
                // Volumen general + por app
                Deslizador {
                    Layout.fillWidth: true
                    readonly property bool mudo: ventana.salida?.audio?.muted ?? false
                    icono: ventana.g(mudo ? 0xF075F : 0xF057E)
                    apagado: mudo
                    valor: ventana.salida?.audio?.volume ?? 0
                    onMovido: (v) => { if (ventana.salida?.audio) ventana.salida.audio.volume = v; }
                    onIconoPulsado: { if (ventana.salida?.audio) ventana.salida.audio.muted = !mudo; }
                }
                Repeater {
                    model: ventana.apps
                    Deslizador {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        icono: ventana.g(0xF075A)
                        etiqueta: modelData.properties["application.name"] || modelData.description || modelData.name
                        apagado: modelData.audio.muted
                        valor: modelData.audio.volume
                        onMovido: (v) => modelData.audio.volume = v
                        onIconoPulsado: modelData.audio.muted = !modelData.audio.muted
                    }
                }

                // Salida de audio: un chip por dispositivo; clic = sonar por ahí (solo si hay más de uno)
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: ventana.salidas.length > 1
                    Repeater {
                        model: ventana.salidas
                        Rectangle {
                            required property var modelData
                            readonly property bool actual: modelData === ventana.salida
                            width: filaSalida.implicitWidth + 22; height: 28; radius: 14
                            color: actual ? Qt.alpha(Paleta.naranja, 0.22) : Qt.alpha(Paleta.texto, zonaSalida.containsMouse ? 0.10 : 0.05)
                            border { width: 1; color: actual ? Qt.alpha(Paleta.naranja, .55) : Qt.alpha(Paleta.texto, .08) }
                            Row {
                                id: filaSalida
                                anchors.centerIn: parent
                                spacing: 6
                                Text { text: ventana.iconoSalida(modelData); color: actual ? Paleta.naranja : Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 } }
                                Text {
                                    text: (modelData.nickname || modelData.description || modelData.name).replace(/ (Analog|Digital) Stereo$/, "")
                                    color: actual ? Paleta.texto : Paleta.gris
                                    font { family: Paleta.fuente; pixelSize: 10; bold: actual }
                                }
                            }
                            MouseArea { id: zonaSalida; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Pipewire.preferredDefaultAudioSink = modelData }
                        }
                    }
                }

                // Micrófono (clic en el icono = silenciar / activar)
                Deslizador {
                    Layout.fillWidth: true
                    visible: ventana.entrada?.audio !== undefined
                    readonly property bool mudo: ventana.entrada?.audio?.muted ?? true
                    icono: ventana.g(mudo ? 0xF036D : 0xF036C)
                    apagado: mudo
                    valor: ventana.entrada?.audio?.volume ?? 0
                    onMovido: (v) => { if (ventana.entrada?.audio) ventana.entrada.audio.volume = v; }
                    onIconoPulsado: { if (ventana.entrada?.audio) ventana.entrada.audio.muted = !mudo; }
                }

                // Brillo
                Deslizador {
                    Layout.fillWidth: true
                    icono: ventana.g(0xF00E0)
                    valor: ventana.brillo
                    onMovido: (v) => {
                        const p = Math.max(5, Math.round(v * 100));        // nunca a 0 (pantalla negra)
                        ventana.brillo = p / 100;
                        Quickshell.execDetached(["brightnessctl", "set", p + "%"]);
                    }
                }
            }

            // Música (el mismo componente del dashboard)
            Musica {
                Layout.fillWidth: true
                visible: jugador !== null
            }

            // No molestar
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4; Layout.rightMargin: 4
                spacing: 10
                Text {
                    text: ventana.g(Notificaciones.noMolestar ? 0xF009B : 0xF009A)
                    color: Notificaciones.noMolestar ? Paleta.naranja : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 16 }
                }
                Text {
                    Layout.fillWidth: true
                    text: Notificaciones.porAutomatizacion ? "No molestar · automático" : "No molestar"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 13; bold: true }
                }
                Interruptor {
                    activo: Notificaciones.manual
                    acento: Paleta.naranja
                    onAlternado: Notificaciones.alternarNoMolestar()
                }
            }

            // Historial
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Text { text: "NOTIFICACIONES"; color: Paleta.gris; font { family: EstiloPanel.fuente; pixelSize: 10; bold: true; letterSpacing: 1.8 } }
                Rectangle {
                    visible: Notificaciones.lista.length > 0
                    implicitWidth: Math.max(20, cuenta.implicitWidth + 12); implicitHeight: 18; radius: 9
                    color: Qt.alpha(Paleta.naranja, .2)
                    Text { id: cuenta; anchors.centerIn: parent; text: Notificaciones.lista.length; color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 10; bold: true } }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Paleta.texto, 0.08) }
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: Notificaciones.lista.slice().reverse()       // las más nuevas arriba
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotiTarjeta {
                    required property var modelData
                    width: ListView.view.width
                    noti: modelData
                }
                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: ventana.g(0xF009A) + "  Sin notificaciones"
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 13; italic: true }
                }
            }
        }
    }
}
