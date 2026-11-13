// Centro de control (SUPER+N o clic en la campana): todo lo que se AJUSTA.
//   botones rápidos · perfiles · volumen (general y por app) · brillo · música
//   abajo, en pestañas: avisos (con No molestar) · conexiones (Wi-Fi y Bluetooth) · móvil · más
//   qs ipc call notificaciones toggle · qs ipc call conexiones wifi|bluetooth · qs ipc call centroEscritorio toggle
import QtQuick
import QtQuick.Controls
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
        if (abierto) { cierre.stop(); mostrar = true; leerConmutadores.running = true; lectorBrillo.running = true; lectorMovil.running = true; salidaEscritorio = ""; }
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

    // ── Sección de abajo: notificaciones · conexiones · móvil · más ──────
    property string seccion: "notificaciones"
    property alias listaConexiones: listaConexiones
    function abrirEn(que, pestanaConexion) {
        seccion = que;
        if (pestanaConexion) listaConexiones.pestana = pestanaConexion;
        abierto = true;
    }
    onMostrarChanged: if (!mostrar) seccion = "notificaciones"

    // Móvil (KDE Connect): lo mismo que lee el panel de avisos (scripts/movil.py estado, JSON)
    property bool movilListo: false
    property string movilNombre: ""
    property int movilCarga: -1
    property bool movilCargando: false
    property bool movilEmparejado: false
    Process {
        id: lectorMovil
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/movil.py", "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(this.text); } catch (e) {}
                ventana.movilNombre = d.conectado ? (d.nombre || "Móvil") : "";
                ventana.movilCarga = d.bateria ?? -1;
                ventana.movilCargando = !!d.cargando;
                ventana.movilEmparejado = !!d.emparejado;
                ventana.movilListo = true;
            }
        }
    }
    function movil(args, cerrarPanel) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/movil.sh", ...args]);
        if (cerrarPanel) abierto = false;
    }

    // Acciones del escritorio (scripts/escritorio.py): perfiles, checkpoints, privacidad, replay
    property string salidaEscritorio: ""
    function escritorio(args) {
        if (procEscritorio.running) return;
        salidaEscritorio = "Procesando…";
        procEscritorio.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/escritorio.py", ...args];
        procEscritorio.running = true;
    }
    Process {
        id: procEscritorio
        stdout: StdioCollector { onStreamFinished: ventana.salidaEscritorio = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) ventana.salidaEscritorio = this.text.trim() }
    }

    // ── El panel ────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        width: 420
        anchors { top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
        x: ventana.abierto ? parent.width - width - 8 : parent.width + 10
        Behavior on x { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
        color: "transparent"
        FondoPanel { anchors.fill: parent; radio: 24 }
        MouseArea { anchors.fill: parent }
        focus: ventana.abierto
        Keys.onEscapePressed: ventana.abierto = false

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            // Título + borrar todo
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 40; implicitHeight: 40; radius: 12
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(Qt.lighter(Paleta.acento, 1.15), .40) }
                        GradientStop { position: 1; color: Qt.alpha(Paleta.acento, .12) }
                    }
                    border { width: 1; color: Qt.alpha(Paleta.acento, .5) }
                    Text { anchors.centerIn: parent; text: ventana.g(0xF0493); color: Qt.lighter(Paleta.acento, 1.2); font { family: Paleta.fuente; pixelSize: 20 } }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: relojCC.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM").toUpperCase()
                        color: Paleta.acento
                        font { family: EstiloPanel.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Centro de control"
                        color: Paleta.texto
                        font { family: EstiloPanel.fuente; pixelSize: 20; weight: Font.DemiBold }
                    }
                }
                Rectangle {
                    visible: Notificaciones.lista.length > 0
                    implicitWidth: textoBorrar.implicitWidth + 24; implicitHeight: 30; radius: height / 2
                    color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.peligro, 0.22) : EstiloPanel.rellenoActivo
                    border { width: 1; color: zonaBorrar.containsMouse ? Qt.alpha(Paleta.peligro, .5) : EstiloPanel.borde }
                    Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                    Text { id: textoBorrar; anchors.centerIn: parent; text: ventana.g(0xF0A7A) + "  Borrar todo"; color: zonaBorrar.containsMouse ? Paleta.peligro : Paleta.texto; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
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
                        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
                        FondoBoton {
                            anchors.fill: parent
                            radio: 16
                            tinte: Paleta.acento
                            destacado: boton.encendido
                            encima: zonaBoton.containsMouse
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ventana.g(boton.modelData.icono)
                                color: boton.encendido ? Qt.lighter(Paleta.acento, 1.2) : Paleta.texto
                                font { family: Paleta.fuente; pixelSize: 20 }
                                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: boton.modelData.nombre
                                color: boton.encendido ? Paleta.texto : Paleta.gris
                                font { family: Paleta.fuente; pixelSize: 11; bold: boton.encendido }
                            }
                        }
                        MouseArea {
                            id: zonaBoton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            // clic derecho en Wi-Fi/Bluetooth: su lista, en la pestaña Conexiones de abajo
                            onClicked: (e) => {
                                if (e.button === Qt.RightButton && (modelData.cosa === "wifi" || modelData.cosa === "bluetooth"))
                                    ventana.abrirEn("conexiones", modelData.cosa);
                                else if (e.button === Qt.LeftButton)
                                    modelData.cosa ? ventana.conmutar(modelData.cosa) : ventana.ejecutar(modelData.cmd, modelData.cerrar);
                            }
                        }
                    }
                }
            }

            // Perfiles del escritorio (antes en el centro del escritorio)
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        { id: "cristal", nombre: "Cristal", icono: 0xF030C, ayuda: "Luz y profundidad" },
                        { id: "lectura", nombre: "Lectura", icono: 0xF0474, ayuda: "Claridad al leer: sin transparencias" },
                        { id: "minimo", nombre: "Mínimo", icono: 0xF04C5, ayuda: "Solo lo esencial: sin animaciones ni sombras" },
                        { id: "rendimiento", nombre: "Rendimiento", icono: 0xF0493, ayuda: "Espacio y rapidez: sin huecos ni efectos" }
                    ]
                    Rectangle {
                        id: chipPerfil
                        required property var modelData
                        readonly property bool actual: EstadoEscritorio.perfil === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: height / 2
                        color: actual ? Qt.alpha(Paleta.acento, .22) : zonaPerfil.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                        border { width: 1; color: actual ? Qt.alpha(Paleta.acento, .55) : EstiloPanel.borde }
                        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: ventana.g(chipPerfil.modelData.icono); color: chipPerfil.actual ? Paleta.acento : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } anchors.verticalCenter: parent.verticalCenter }
                            Text { text: chipPerfil.modelData.nombre; color: chipPerfil.actual ? Paleta.texto : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11; bold: chipPerfil.actual } anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: zonaPerfil; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ventana.escritorio(["perfil", chipPerfil.modelData.id]) }
                        ToolTip.visible: zonaPerfil.containsMouse
                        ToolTip.text: modelData.ayuda
                        ToolTip.delay: 500
                    }
                }
            }

            // ── Pestañas: Inicio (sonido, música y avisos) · Conexiones · Móvil · Más ──
            Item {
                Layout.fillWidth: true
                implicitHeight: 34
                Rectangle { anchors.fill: parent; radius: height / 2; color: EstiloPanel.relleno; border { width: 1; color: EstiloPanel.borde } }
                Row {
                    anchors { fill: parent; margins: 2 }
                    Repeater {
                        model: [
                            { id: "notificaciones", nombre: "Inicio" + (Notificaciones.lista.length ? " · " + Notificaciones.lista.length : "") },
                            { id: "conexiones", nombre: "Conexiones" },
                            { id: "movil", nombre: "Móvil" },
                            { id: "mas", nombre: "Más" }
                        ]
                        Rectangle {
                            id: pestana
                            required property var modelData
                            readonly property bool actual: ventana.seccion === modelData.id
                            width: parent.width / 4; height: parent.height
                            radius: height / 2
                            color: actual ? Qt.alpha(Paleta.acento, .22) : "transparent"
                            border { width: actual ? 1 : 0; color: Qt.alpha(Paleta.acento, .5) }
                            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                            Text { anchors.centerIn: parent; text: pestana.modelData.nombre; color: pestana.actual ? Paleta.texto : EstiloPanel.tenue
                                   font { family: Paleta.fuente; pixelSize: 12; bold: pestana.actual } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ventana.seccion = pestana.modelData.id }
                        }
                    }
                }
            }

            // Sonido y brillo, juntos en una tarjeta
            TarjetaPanel {
                Layout.fillWidth: true
                visible: ventana.seccion === "notificaciones"
                espaciado: 8
                relleno: 12
                // Volumen general + por app
                Deslizador {
                    Layout.fillWidth: true
                    readonly property bool mudo: ventana.salida?.audio?.muted ?? false
                    icono: ventana.g(mudo ? 0xF075F : 0xF057E)
                    nombre: "Volumen"
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
                    spacing: 4
                    visible: ventana.salidas.length > 1
                    Repeater {
                        model: ventana.salidas
                        Rectangle {
                            required property var modelData
                            readonly property bool actual: modelData === ventana.salida
                            width: filaSalida.implicitWidth + 22; height: 28; radius: height / 2
                            color: actual ? Qt.alpha(Paleta.acento, 0.22) : Qt.alpha(Paleta.texto, zonaSalida.containsMouse ? 0.10 : 0.05)
                            border { width: 1; color: actual ? Qt.alpha(Paleta.acento, .55) : EstiloPanel.borde }
                            Row {
                                id: filaSalida
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: ventana.iconoSalida(modelData); color: actual ? Paleta.acento : Paleta.gris; font { family: Paleta.fuente; pixelSize: 12 } }
                                Text {
                                    text: (modelData.nickname || modelData.description || modelData.name).replace(/ (Analog|Digital) Stereo$/, "")
                                    color: actual ? Paleta.texto : Paleta.gris
                                    font { family: Paleta.fuente; pixelSize: 11; bold: actual }
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
                    nombre: "Micrófono"
                    apagado: mudo
                    valor: ventana.entrada?.audio?.volume ?? 0
                    onMovido: (v) => { if (ventana.entrada?.audio) ventana.entrada.audio.volume = v; }
                    onIconoPulsado: { if (ventana.entrada?.audio) ventana.entrada.audio.muted = !mudo; }
                }

                // Brillo
                Deslizador {
                    Layout.fillWidth: true
                    icono: ventana.g(0xF00E0)
                    nombre: "Brillo"
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
                visible: jugador !== null && ventana.seccion === "notificaciones"
            }

            // ── Avisos ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ventana.seccion === "notificaciones"
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4; Layout.rightMargin: 4
                    spacing: 8
                    Text {
                        text: ventana.g(Notificaciones.noMolestar ? 0xF009B : 0xF009A)
                        color: Notificaciones.noMolestar ? Paleta.acento : Paleta.gris
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
                        acento: Paleta.acento
                        onAlternado: Notificaciones.alternarNoMolestar()
                    }
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

            // ── Conexiones: Wi-Fi y Bluetooth aquí mismo ─────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ventana.seccion === "conexiones"
                contentHeight: listaConexiones.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ListaConexiones {
                    id: listaConexiones
                    width: parent.width
                    activa: ventana.abierto && ventana.seccion === "conexiones"
                    altoMaximo: Math.max(200, parent.parent.height - 50)
                }
            }

            // ── Móvil ─────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ventana.seccion === "movil"
                spacing: 12
                // conectado: nombre, batería y acciones
                RowLayout {
                    visible: ventana.movilNombre !== ""
                    Layout.fillWidth: true
                    spacing: 12
                    Text { text: ventana.g(0xF011C); color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 26 } }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: ventana.movilNombre; color: Paleta.texto; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                        Text {
                            text: ventana.movilCarga >= 0 ? `Batería ${ventana.movilCarga} %` + (ventana.movilCargando ? " · cargando" : "") : "Conectado"
                            color: ventana.movilCargando ? Paleta.exito : ventana.movilCarga >= 0 && ventana.movilCarga <= 15 ? Paleta.peligro : EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 12 }
                        }
                    }
                }
                GridLayout {
                    visible: ventana.movilNombre !== ""
                    Layout.fillWidth: true
                    columns: 2; columnSpacing: 8; rowSpacing: 8
                    BotonPanel { text: "Hacer sonar"; simbolo: ventana.g(0xF009E); onClicked: ventana.movil(["sonar"], false) }
                    BotonPanel { text: "Abrir lo copiado"; simbolo: ventana.g(0xF0339); onClicked: ventana.ejecutar(Quickshell.env("HOME") + "/.config/hypr/scripts/movil.py enlace", false) }
                    BotonPanel { text: "Enviar archivo"; simbolo: ventana.g(0xF0552); onClicked: ventana.movil(["elegir"], true) }
                    BotonPanel { text: "Sus archivos"; simbolo: ventana.g(0xF024B); onClicked: ventana.movil(["navegar"], true) }
                    BotonPanel { text: "Mensajes (SMS)"; simbolo: ventana.g(0xF0361); onClicked: ventana.ejecutar("kdeconnect-sms", true) }
                    BotonPanel { text: "Avisos y respuestas"; simbolo: ventana.g(0xF009A); onClicked: ventana.ejecutar("qs ipc call movil avisos", true) }
                }
                Text {
                    visible: !ventana.movilListo
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 24
                    text: "Buscando el móvil…"; color: EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 13; italic: true }
                }
                // sin conectar: una sola salida
                ColumnLayout {
                    visible: ventana.movilListo && ventana.movilNombre === ""
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: ventana.g(0xF011C); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 36 } }
                    Text { Layout.alignment: Qt.AlignHCenter; text: ventana.movilEmparejado ? "El móvil no está conectado" : "No hay ningún móvil emparejado"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: ventana.movilEmparejado ? "Abre KDE Connect en el móvil y conéctalo a la misma red Wi-Fi." : "Empareja tu móvil desde KDE Connect para ver sus avisos, su batería y enviarle archivos."
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    BotonPanel { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 200; Layout.fillWidth: false; text: "Abrir KDE Connect"; destacado: true; onClicked: ventana.ejecutar("kdeconnect-app", true) }
                }
                Item { Layout.fillHeight: true }
            }

            // ── Más: checkpoints, privacidad, juego, diagnóstico y replay ─
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ventana.seccion === "mas"
                contentHeight: columnaMas.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: columnaMas
                    width: parent.width
                    spacing: 8
                    Etiqueta { text: "VENTANAS" }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                        BotonPanel { text: "Guardar checkpoint"; simbolo: ventana.g(0xF0193); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["checkpoint", "guardar"]) }
                        BotonPanel { text: "Restaurar espacios"; simbolo: ventana.g(0xF006F); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["checkpoint", "restaurar"]) }
                        BotonPanel { text: "Deshacer restauración"; simbolo: ventana.g(0xF054C); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["checkpoint", "deshacer"]) }
                        BotonPanel { text: "Juego automático"; simbolo: ventana.g(0xF0297); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["juego", "automatico"]) }
                    }
                    Etiqueta { text: "PRIVACIDAD Y DIAGNÓSTICO"; Layout.topMargin: 4 }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                        BotonPanel {
                            text: Reunion.activa ? "Privacidad · reunión" : EstadoEscritorio.privacidad ? "Privacidad activada" : "Activar privacidad"
                            simbolo: ventana.g(0xF0483)
                            destacado: EstadoEscritorio.privacidad
                            enabled: !Reunion.activa && !procEscritorio.running
                            onClicked: ventana.escritorio(["privacidad"])
                        }
                        BotonPanel { text: "Diagnóstico"; simbolo: ventana.g(0xF02CA); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["diagnostico"]) }
                    }
                    Etiqueta { text: "REPLAY (ÚLTIMOS 30 s)"; Layout.topMargin: 4 }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                        BotonPanel { text: "Guardar ahora"; simbolo: ventana.g(0xF0567); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["replay", "save"]) }
                        BotonPanel { text: "Automático"; simbolo: ventana.g(0xF0450); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["replay", "auto"]) }
                        BotonPanel { text: "Pausar"; simbolo: ventana.g(0xF03E4); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["replay", "stop"]) }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: ventana.salidaEscritorio !== ""
                        text: ventana.salidaEscritorio
                        wrapMode: Text.Wrap
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: "La privacidad oculta títulos y pausa el replay. Los checkpoints duran esta sesión."
                        wrapMode: Text.Wrap
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
