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
import Quickshell.Networking
import Quickshell.Bluetooth

PanelWindow {
    id: ventana
    Connections { target: EstadoEscritorio; function onCapturaPrivadaChanged() { if(EstadoEscritorio.capturaPrivada) ventana.abierto=false; } }
    property bool abierto: false
    signal apagadoSolicitado()
    property bool mostrar: false
    property bool sonidoAmpliado: false
    property bool musicaAmpliada: false
    property var preferenciaControles: null
    readonly property bool inicioCompacto: vistaContenido.height < 500
    readonly property bool controlesVisibles: preferenciaControles ?? !inicioCompacto
    readonly property bool microEnUso: Pipewire.nodes.values.some(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio")
    function nombreControl(cosa) { return ({replay:"Replay",rendimiento:"Energía alta",conservacion:"Conservar batería",luz:"Luz nocturna"})[cosa] || cosa; }
    function iconoControl(cosa) { return g(({replay:0xF044B,rendimiento:0xF140B,conservacion:0xF032A,luz:0xF0594})[cosa] || 0xF0493); }


    function g(cp) { return String.fromCodePoint(cp); }
    function ejecutar(cmd, cerrarPanel) {
        Quickshell.execDetached(["sh", "-c", cmd]);
        if (cerrarPanel) abierto = false;
    }

    // Abierto desde la barra (campana, Wi-Fi, volumen…): el panel nace del botón (Origen.qml) en vez de
    // entrar deslizándose, y al cerrarse vuelve a él. Con el teclado, entra deslizándose como siempre.
    property var nace: null              // {x, y} en coordenadas de esta ventana
    property bool dentro: false          // el panel está en su sitio (x); se fija aquí, después de `nace`
    onAbiertoChanged: {
        if (abierto) {
            cierre.stop(); encogerCentro.stop();
            const p = EstiloPanel.movimiento ? Origen.tomar(screen?.name ?? "") : null;
            // esta ventana empieza bajo la barra: las coordenadas de la pantalla bajan lo que ocupa la barra
            nace = p ? { x: p.x, y: p.y - ((screen?.height ?? height) - height) } : null;
            dentro = true;
            if (nace) crecerCentro.restart(); else { crecerCentro.stop(); escalaCentro.xScale = 1; escalaCentro.yScale = 1; }
            mostrar = true; leerConmutadores.running = true; lectorBrillo.running = true; lectorMovil.running = true; salidaEscritorio = ""; leerReplay.running = true;
        }
        else if (EstiloPanel.movimiento) { if (nace) encogerCentro.restart(); else dentro = false; cierre.restart(); }
        else { dentro = false; mostrar = false; nace = null; }
    }
    Timer {
        id: cierre; interval: EstiloPanel.normal
        onTriggered: { ventana.mostrar = false; ventana.dentro = false; ventana.nace = null; escalaCentro.xScale = 1; escalaCentro.yScale = 1; }
    }

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
    property var estados: ({})        // estado confirmado por servicio, disponibilidad y motivo
    property var revisionesControles: ({})
    property string avisoControl: ""
    function guardarEstado(cosa, dato) {
        const nuevos = Object.assign({}, estados); nuevos[cosa] = dato; estados = nuevos;
        const versiones = Object.assign({}, revisionesControles); versiones[cosa] = (versiones[cosa] || 0) + 1; revisionesControles = versiones;
    }
    Process {
        id: leerConmutadores
        property var revisiones: ({})
        onRunningChanged: if (running) revisiones = Object.assign({}, ventana.revisionesControles)
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/conmutadores.sh", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const datos = JSON.parse(text), nuevos = Object.assign({}, ventana.estados);
                    for (const cosa of Object.keys(datos))
                        if ((leerConmutadores.revisiones[cosa] || 0) === (ventana.revisionesControles[cosa] || 0)) nuevos[cosa] = datos[cosa];
                    ventana.estados = nuevos;
                }
                catch (e) { ventana.avisoControl = "No se pudieron consultar los controles. Reintenta la consulta."; }
            }
        }
        onExited: (codigo, estadoSalida) => {
            if (codigo !== 0 || estadoSalida !== 0) ventana.avisoControl = "La consulta de controles falló. Reintenta o revisa el servicio.";
        }
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
    onSeccionChanged: vistaContenido.contentY = 0
    property alias listaConexiones: listaConexiones
    function abrirEn(que, pestanaConexion) {
        seccion = que;
        if (pestanaConexion) listaConexiones.pestana = pestanaConexion;
        if (que === "sonido") sonidoAmpliado = false;
        abierto = true;
        if (que === "avisos") {
            const primero = Notificaciones.grupos[0];
            if (primero && !Notificaciones.expandidos[primero.clave]) Notificaciones.desplegar(primero.clave);
            Qt.callLater(() => listaAvisos.positionViewAtBeginning());
        }
    }
    onMostrarChanged: if (!mostrar) {
        seccion = "notificaciones";
        vistaContenido.contentY = 0;
    }

    // Móvil (KDE Connect): lo mismo que lee el panel de avisos (scripts/movil.py estado, JSON)
    property bool movilListo: false
    property string movilError: ""
    property real movilActualizado: 0
    property string movilNombre: ""
    property int movilCarga: -1
    property bool movilCargando: false
    property bool movilEmparejado: false
    property string movilVia: ""
    property var movilFunciones: []
    Process {
        id: lectorMovil
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/movil.py", "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(this.text); if (d.error) throw new Error(d.error); } catch (e) { ventana.movilError="No se pudo consultar el móvil. Los datos anteriores pueden estar desactualizados."; ventana.movilListo=true; return; }
                ventana.movilError="";ventana.movilActualizado=Date.now();
                ventana.movilNombre = d.conectado ? (d.nombre || "Móvil") : "";
                ventana.movilCarga = d.bateria ?? -1;
                ventana.movilCargando = !!d.cargando;
                ventana.movilEmparejado = !!d.emparejado;
                ventana.movilVia = d.via || "";
                ventana.movilFunciones = d.funciones || [];
                ventana.movilListo = true;
            }
        }
    }
    function movil(args, cerrarPanel) {
        if (EstadoEscritorio.privacidad) return;
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
        onExited: leerReplay.running = true
    }

    property int ticConexion: 0
    Timer { interval: 3000; repeat: true; running: ventana.abierto; triggeredOnStart: true; onTriggered: ventana.ticConexion++ }
    readonly property string redActual: {
        ticConexion;
        const w = Networking.devices.values.find(d => d.type === DeviceType.Wifi);
        return (w?.networks?.values ?? []).find(n => n.connected)?.name ?? "";
    }
    readonly property string btActual: {
        ticConexion;
        const c = (Bluetooth.defaultAdapter?.devices?.values ?? []).filter(d => d.connected).map(d => d.name);
        return c.length > 1 ? c[0] + " y " + (c.length - 1) + " más" : c[0] ?? "";
    }

    property string replayEstado: "Consultando replay…"
    Process {
        id: leerReplay
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/replay.py", "detalle"]
        stdout: StdioCollector { onStreamFinished: { try { ventana.replayEstado = JSON.parse(text).texto; } catch(e) { ventana.replayEstado = "Replay: no se pudo consultar el estado"; } } }
    }

    // ── El panel ────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        width: Math.min(420, Math.max(0, parent.width - 16))
        anchors { top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
        x: ventana.dentro ? parent.width - width - 8 : parent.width + 10
        Behavior on x { enabled: !ventana.nace; NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        opacity: ventana.abierto || !ventana.nace ? 1 : 0
        Behavior on opacity { enabled: !!ventana.nace; NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.InCubic } }
        transform: Scale {
            id: escalaCentro
            origin.x: ventana.nace ? ventana.nace.x - panel.x : panel.width
            origin.y: ventana.nace ? ventana.nace.y - panel.y : 0
        }
        NumberAnimation {
            id: crecerCentro
            target: escalaCentro; properties: "xScale,yScale"; from: .06; to: 1
            duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: .8
        }
        NumberAnimation {
            id: encogerCentro
            target: escalaCentro; properties: "xScale,yScale"; to: .06
            duration: EstiloPanel.normal; easing.type: Easing.InCubic
        }
        color: "transparent"
        FondoPanel { anchors.fill: parent; radio: 24 }
        MouseArea { anchors.fill: parent }
        focus: ventana.abierto
        Keys.onEscapePressed: ventana.abierto = false
        // Teclado (ORION 4.2): Ctrl+Tab / Ctrl+Shift+Tab cambian de sección, Ctrl+1…4 van directo; Tab recorre controles
        readonly property var secciones: ["notificaciones", "conexiones", "movil", "mas"]
        function irSeccion(paso) { const i = secciones.indexOf(ventana.seccion); ventana.seccion = secciones[(i + paso + secciones.length) % secciones.length]; }
        Shortcut { sequences: ["Ctrl+Tab"]; enabled: ventana.abierto; onActivated: panel.irSeccion(1) }
        Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]; enabled: ventana.abierto; onActivated: panel.irSeccion(-1) }
        Repeater { model: 4; Item { required property int index; Shortcut { sequence: "Ctrl+" + (index + 1); enabled: ventana.abierto; onActivated: ventana.seccion = panel.secciones[index] } } }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    visible: contenido.width >= 320
                    implicitWidth: 36; implicitHeight: 36; radius: EstiloPanel.rControl
                    color: Qt.alpha(Paleta.acento, .12)
                    border { width: 1; color: Qt.alpha(Paleta.acento, .28) }
                    Text {
                        anchors.centerIn: parent
                        text: ventana.g(ventana.seccion === "avisos" ? 0xF009A : ventana.seccion === "sonido" ? 0xF057E : 0xF062E)
                        color: Paleta.acento
                        font { family: Paleta.mono; pixelSize: EstiloPanel.t20 }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: ventana.seccion === "avisos" ? "Avisos" : ventana.seccion === "sonido" ? "Sonido" : "Centro de control"
                    elide: Text.ElideRight
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: EstiloPanel.t20; weight: Font.DemiBold }
                }
                Repeater {
                    model: [{icono: "󰌾", nombre: "Bloquear", accion: () => ventana.ejecutar("loginctl lock-session", true)},
                            {icono: "󰐥", nombre: "Opciones de apagado", accion: () => ventana.apagadoSolicitado()},
                            {icono: "×", nombre: "Cerrar centro de control", accion: () => ventana.abierto = false}]
                    BotonCompacto {
                        required property var modelData
                        text: modelData.icono
                        Accessible.name: modelData.nombre
                        ToolTip.visible: hovered
                        ToolTip.delay: 600
                        ToolTip.text: modelData.nombre
                        implicitWidth: 32
                        leftPadding: 0; rightPadding: 0
                        onClicked: modelData.accion()
                    }
                }
            }
            NavegacionPanel {
                readonly property bool conIconos: width >= 340
                opciones: [{texto:"Inicio", icono: conIconos ? ventana.g(0xF02DC) : ""},
                           {texto:"Redes", icono: conIconos ? ventana.g(0xF05A9) : ""},
                           {texto:"Móvil", icono: conIconos ? ventana.g(0xF0011) : ""},
                           {texto:"Más", icono: conIconos ? ventana.g(0xF01D8) : ""}]
                actual: panel.secciones.indexOf(ventana.seccion)
                onElegir: indice => ventana.seccion = panel.secciones[indice]
            }
            Flickable {
                id: vistaContenido
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: Math.max(height, contenido.Layout.minimumHeight)
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    parent: panel
                    y: vistaContenido.parent.y + vistaContenido.y
                    height: vistaContenido.height
                    anchors { right: parent.right; rightMargin: 4 }
                }
            }
        }

        ColumnLayout {
            id: contenido
            parent: vistaContenido.contentItem
            width: vistaContenido.contentWidth
            height: vistaContenido.contentHeight
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                visible: ventana.seccion === "notificaciones"
                spacing: 8
                SelectorEnergia {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    compacto: true
                }
                BotonCompacto {
                    implicitWidth: 136
                    text: ventana.controlesVisibles ? "Menos controles  ⌃" : "Más controles  ⌄"
                    Accessible.name: ventana.controlesVisibles ? "Plegar controles rápidos" : "Mostrar controles rápidos"
                    onClicked: ventana.preferenciaControles = !ventana.controlesVisibles
                }
            }
            GridLayout {
                Layout.fillWidth: true
                visible: ventana.seccion === "notificaciones" && ventana.controlesVisibles
                columns: 2; columnSpacing: 8; rowSpacing: 8
                Repeater {
                    model: [{cosa:"wifi",nombre:"Wi-Fi",icono:0xF0928},{cosa:"bluetooth",nombre:"Bluetooth",icono:0xF00AF}]
                    ControlRapido {
                        required property var modelData
                        compacto: true; conDetalle: true
                        Layout.preferredWidth: 1
                        nombre: modelData.nombre; simbolo: ventana.g(modelData.icono); cosa: modelData.cosa; dato: ventana.estados[cosa] ?? null
                        subtitulo: cosa === "wifi" ? ventana.redActual : ventana.btActual || "Sin dispositivos"
                        onConfirmado: (estado) => { ventana.guardarEstado(cosa,estado); ventana.avisoControl = ""; }
                        onFallo: (mensaje) => ventana.avisoControl = nombre + ": " + mensaje
                        onConsultar: if (!leerConmutadores.running) leerConmutadores.running = true
                        onDetalle: ventana.abrirEn("conexiones",cosa)
                    }
                }
                Repeater {
                    model: PreferenciasUI.favoritosControles
                    ControlRapido {
                        required property string modelData
                        compacto: true
                        Layout.preferredWidth: 1
                        cosa: modelData; nombre: ventana.nombreControl(cosa); simbolo: ventana.iconoControl(cosa); dato: ventana.estados[cosa] ?? null
                        onConfirmado: (estado) => ventana.guardarEstado(cosa,estado)
                        onFallo: (mensaje) => ventana.avisoControl = nombre + ": " + mensaje
                        onConsultar: if (!leerConmutadores.running) leerConmutadores.running = true
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: ventana.avisoControl !== ""
                spacing: 8
                Text { Layout.fillWidth: true; text: ventana.avisoControl; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: Paleta.peligro; font { family: Paleta.fuente; pixelSize: 12 } }
                BotonCompacto { text: "Consultar"; enabled: !leerConmutadores.running; onClicked: { ventana.avisoControl = ""; leerConmutadores.running = true; } }
            }

            // Sonido y brillo, juntos en una tarjeta
            TarjetaPanel {
                Layout.fillWidth: true
                visible: ventana.seccion === "notificaciones" || ventana.seccion === "sonido"
                espaciado: 8
                relleno: ventana.seccion === "sonido" ? EstiloPanel.e3 : EstiloPanel.e2
                Text {
                    Layout.fillWidth: true
                    visible: ventana.seccion === "sonido"
                    text: ventana.salida?.description || "Sin salida de audio"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 14; bold: true }
                    elide: Text.ElideRight
                }
                GridLayout {
                    id: controlesAudio
                    Layout.fillWidth: true
                    readonly property bool brilloEnFila: ventana.seccion === "notificaciones" && width >= 336
                    columns: brilloEnFila ? 3 : 2
                    columnSpacing: 8
                    rowSpacing: 8
                    Deslizador {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        readonly property bool mudo: ventana.salida?.audio?.muted ?? false
                        icono: ventana.g(mudo ? 0xF075F : 0xF057E)
                        nombre: "Volumen"
                        apagado: mudo
                        valor: ventana.salida?.audio?.volume ?? 0
                        onMovido: (v) => { if (ventana.salida?.audio) ventana.salida.audio.volume = v; }
                        onIconoPulsado: { if (ventana.salida?.audio) ventana.salida.audio.muted = !mudo; }
                    }
                    BotonCompacto {
                        text: ventana.sonidoAmpliado ? "⌃" : "⌄"
                        implicitWidth: 32
                        leftPadding: 0; rightPadding: 0
                        Accessible.name: ventana.sonidoAmpliado ? "Cerrar mezclador y dispositivos" : "Mezclador y dispositivos"
                        ToolTip.visible: hovered; ToolTip.delay: 500
                        ToolTip.text: ventana.sonidoAmpliado ? "Cerrar mezclador" : "Mezclador por app y salidas"
                        onClicked: ventana.sonidoAmpliado = !ventana.sonidoAmpliado
                    }
                    Deslizador {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.columnSpan: controlesAudio.brilloEnFila ? 1 : 2
                        icono: ventana.g(0xF00E0)
                        visible: ventana.seccion !== "sonido"
                        nombre: "Brillo"
                        valor: ventana.brillo
                        onMovido: (v) => {
                            const p = Math.max(5, Math.round(v * 100));        // nunca a 0 (pantalla negra)
                            ventana.brillo = p / 100;
                            Quickshell.execDetached(["brightnessctl", "set", p + "%"]);
                        }
                    }
                }
                Flickable {
                    id: mezclador
                    readonly property bool muestraApps: ventana.sonidoAmpliado && !EstadoEscritorio.privacidad && ventana.apps.length > 0
                    readonly property bool muestraSalidas: ventana.sonidoAmpliado && ventana.salidas.length > 1
                    readonly property bool muestraMicro: ventana.entrada?.audio !== undefined
                        && (ventana.sonidoAmpliado || microfono.mudo || ventana.microEnUso)
                    visible: muestraApps || muestraSalidas || muestraMicro
                    Layout.fillWidth: true
                    // En Inicio el mezclador se desplaza dentro de su tarjeta y deja espacio para los avisos.
                    Layout.preferredHeight: ventana.seccion === "sonido" ? contentHeight
                        : Math.min(contentHeight, ventana.inicioCompacto ? 48 : 120)
                    contentWidth: width
                    contentHeight: detallesSonido.implicitHeight
                    interactive: contentHeight > height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    ColumnLayout {
                        id: detallesSonido
                        width: mezclador.contentWidth
                        spacing: 8
                        Repeater {
                            model: mezclador.muestraApps ? ventana.apps : []
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
                            visible: mezclador.muestraSalidas
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
                            id: microfono
                            Layout.fillWidth: true
                            visible: mezclador.muestraMicro
                            readonly property bool mudo: ventana.entrada?.audio?.muted ?? true
                            icono: ventana.g(mudo ? 0xF036D : 0xF036C)
                            nombre: "Micrófono"
                            apagado: mudo
                            valor: ventana.entrada?.audio?.volume ?? 0
                            onMovido: (v) => { if (ventana.entrada?.audio) ventana.entrada.audio.volume = v; }
                            onIconoPulsado: { if (ventana.entrada?.audio) ventana.entrada.audio.muted = !mudo; }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: reproductor.jugador !== null && ventana.seccion === "notificaciones"
                Musica { id: reproductor; Layout.fillWidth: true; compacto: !ventana.musicaAmpliada }
                BotonCompacto { text: ventana.musicaAmpliada ? "⌃" : "⌄"; Accessible.name: "Detalle de música"; onClicked: ventana.musicaAmpliada = !ventana.musicaAmpliada }
            }
            Item { visible: ventana.seccion === "sonido"; Layout.fillHeight: true }
            // ── Avisos ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: ventana.seccion === "notificaciones" || ventana.seccion === "avisos"
                spacing: 8
                TarjetaPanel {
                    Layout.fillWidth: true
                    relleno: EstiloPanel.e2
                    acento: Notificaciones.noMolestar ? Paleta.acento : Paleta.texto
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            visible: contenido.width >= 320
                            implicitWidth: 32; implicitHeight: 32; radius: EstiloPanel.rControl
                            color: Notificaciones.noMolestar ? Qt.alpha(Paleta.acento, .16) : EstiloPanel.elevada
                            border { width: 1; color: Notificaciones.noMolestar ? Qt.alpha(Paleta.acento, .32) : EstiloPanel.borde }
                            Text {
                                anchors.centerIn: parent
                                text: ventana.g(Notificaciones.noMolestar ? 0xF009B : 0xF009A)
                                color: Notificaciones.noMolestar ? Paleta.acento : Paleta.gris
                                font { family: Paleta.mono; pixelSize: EstiloPanel.t16 }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { Layout.fillWidth: true; text: "No molestar"; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                            Text {
                                Layout.fillWidth: true
                                text: Notificaciones.explicacion
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: EstiloPanel.t11 }
                            }
                        }
                        SelectorPanel {
                            Layout.preferredWidth: 112
                            model: [{texto:"Pausar…",valor:""},{texto:"30 minutos",valor:"30"},{texto:"1 hora",valor:"60"},
                                ...(Concentracion.activo ? [{texto:"Hasta fin de concentración",valor:"concentracion"}] : []),...(Reunion.activa ? [{texto:"Hasta fin de reunión",valor:"reunion"}] : []),{texto:"Hasta desactivar",valor:"siempre"},{texto:"Quitar pausa manual",valor:"off"}]
                            textRole:"texto"; valueRole:"valor"
                            currentIndex:0
                            onActivated: { if (currentValue) Notificaciones.pausar(currentValue); currentIndex=0; }
                        }
                        Interruptor {
                            activo: Notificaciones.manual
                            acento: Paleta.acento
                            Accessible.name: "No molestar"
                            onAlternado: Notificaciones.alternarNoMolestar()
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: ventana.seccion === "avisos"
                            ? Notificaciones.lista.length + (Notificaciones.lista.length === 1 ? " aviso" : " avisos") : "Avisos"
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: EstiloPanel.t14; weight: Font.DemiBold }
                    }
                    Rectangle {
                        visible: ventana.seccion !== "avisos" && Notificaciones.lista.length > 0
                        implicitWidth: Math.max(24, cuentaAvisos.implicitWidth + 12)
                        implicitHeight: 20; radius: height / 2
                        color: EstiloPanel.elevada
                        border { width: 1; color: EstiloPanel.borde }
                        Text {
                            id: cuentaAvisos
                            anchors.centerIn: parent
                            text: Notificaciones.lista.length
                            color: EstiloPanel.secundario
                            font { family: Paleta.mono; pixelSize: EstiloPanel.t11 }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: Notificaciones.pendientes.length > 0
                        text: "Avisos borrados"
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    BotonCompacto { text: "Deshacer"; visible: Notificaciones.pendientes.length > 0; onClicked: Notificaciones.deshacerBorrado() }
                    BotonCompacto { text: "Borrar todo"; acento: Paleta.peligro; visible: Notificaciones.lista.length > 0; onClicked: Notificaciones.borrarTodo() }
                }
                ListView {
                    id: listaAvisos
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 72       // deja espacio para un grupo incluso con el mezclador abierto
                    Layout.preferredHeight: 180
                    clip: true
                    spacing: 8
                    ScrollBar.vertical: ScrollBar {}
                    model: Notificaciones.grupos       // las más nuevas arriba
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: GrupoAvisos {
                        required property var modelData
                        width: ListView.view.width
                        datos: modelData
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
                visible: ventana.seccion === "movil" && !EstadoEscritorio.privacidad
                spacing: 12
                Text { Layout.fillWidth: true; visible: ventana.movilError !== ""; text: ventana.movilError; wrapMode: Text.Wrap; color: Paleta.aviso; font { family: Paleta.fuente; pixelSize: 12 } }
                BotonCompacto { visible: ventana.movilError !== ""; text: "Reintentar"; enabled: !lectorMovil.running; onClicked: lectorMovil.running=true }
                Text { Layout.fillWidth:true; visible: ventana.movilActualizado>0; text: "Última lectura · "+Qt.formatDateTime(new Date(ventana.movilActualizado),"HH:mm:ss"); color: EstiloPanel.tenue; font.pixelSize:11 }
                // conectado: tarjeta con el teléfono dibujado, cuya pantalla se llena con la batería
                Rectangle {
                    id: heroMovil
                    visible: ventana.movilNombre !== ""
                    Layout.fillWidth: true
                    implicitHeight: 112
                    radius: EstiloPanel.rTarjeta
                    readonly property real carga: Math.max(0, ventana.movilCarga) / 100
                    readonly property color tono: ventana.movilCargando ? Paleta.exito
                        : ventana.movilCarga >= 0 && ventana.movilCarga <= 15 ? Paleta.peligro : Paleta.acento
                    color: EstiloPanel.superficie
                    border { width: 1; color: EstiloPanel.borde }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.tint(EstiloPanel.superficie, Qt.alpha(heroMovil.tono, .10)) }
                        GradientStop { position: .6; color: EstiloPanel.superficie }
                    }
                    RowLayout {
                        anchors { fill: parent; margins: 16 }
                        spacing: 16
                        // el teléfono
                        Item {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 80
                            RectangularShadow {
                                anchors.fill: cuerpo
                                visible: EstiloPanel.profundidad
                                radius: EstiloPanel.rControl; blur: 18; spread: -2
                                color: Qt.alpha(heroMovil.tono, .35)
                            }
                            Rectangle {
                                id: cuerpo
                                anchors.fill: parent
                                radius: EstiloPanel.rControl
                                color: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .08))
                                border { width: 1.5; color: Qt.alpha(heroMovil.tono, .7) }
                                Rectangle {   // pantalla: se llena desde abajo con la carga
                                    anchors { fill: parent; margins: 4 }
                                    radius: EstiloPanel.rChip
                                    color: Qt.alpha(Paleta.fondo, .9)
                                    clip: true
                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: parent.height * heroMovil.carga
                                        radius: EstiloPanel.rChip
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: Qt.lighter(heroMovil.tono, 1.15) }
                                            GradientStop { position: 1; color: Qt.alpha(heroMovil.tono, .55) }
                                        }
                                        Behavior on height { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: ventana.movilCargando
                                        text: ventana.g(0xF0E7)
                                        color: Paleta.fondo
                                        font { family: Paleta.fuente; pixelSize: 16 }
                                    }
                                }
                                Rectangle {   // cámara
                                    width: 10; height: 3; radius: height / 2
                                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                                    color: Qt.alpha(Paleta.texto, .35)
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { Layout.fillWidth: true; text: ventana.movilNombre; color: Paleta.texto; elide: Text.ElideRight; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
                            Text {
                                Layout.fillWidth: true
                                text: (ventana.movilVia === "LAN" ? "Conectado por Wi-Fi" : ventana.movilVia ? "Conectado por " + ventana.movilVia : "Conectado")
                                      + (ventana.movilCargando ? " · cargando" : "")
                                color: EstiloPanel.tenue; elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 12 }
                            }
                            RowLayout {
                                visible: ventana.movilCarga >= 0
                                Layout.fillWidth: true; Layout.topMargin: 4
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 6; radius: height / 2
                                    color: EstiloPanel.velo
                                    Rectangle {
                                        width: parent.width * heroMovil.carga; height: parent.height; radius: height / 2
                                        color: heroMovil.tono
                                        Behavior on width { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Text { text: ventana.movilCarga + " %"; color: heroMovil.tono; font { family: Paleta.mono; pixelSize: 12; bold: true } }
                            }
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
                // Qué está compartido con el móvil (KDE Connect); se cambia en Avisos y respuestas
                Text {
                    visible: ventana.movilNombre !== "" && ventana.movilFunciones.length > 0
                    Layout.topMargin: 4
                    text: "COMPARTIDO CON EL MÓVIL"
                    color: EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1 }
                }
                // Etiquetas compactas en filas: caben siempre en el panel (la explicación, al pasar el ratón)
                Flow {
                    visible: ventana.movilNombre !== ""
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: ventana.movilNombre !== "" ? ventana.movilFunciones : []
                        Rectangle {
                            id: chipFuncion
                            required property var modelData
                            implicitWidth: filaChip.implicitWidth + 24
                            implicitHeight: 30
                            radius: height / 2
                            color: zonaChip.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                            border { width: 1; color: modelData.activa ? Qt.alpha(Paleta.exito, .35) : EstiloPanel.borde }
                            Row {
                                id: filaChip
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8; height: 8; radius: height / 2
                                    color: chipFuncion.modelData.activa ? Paleta.exito : EstiloPanel.velo
                                }
                                Text {
                                    text: chipFuncion.modelData.nombre
                                    color: chipFuncion.modelData.activa ? Paleta.texto : EstiloPanel.tenue
                                    font { family: Paleta.fuente; pixelSize: 12; weight: Font.Medium }
                                }
                            }
                            MouseArea { id: zonaChip; anchors.fill: parent; hoverEnabled: true }
                            ToolTip.visible: zonaChip.containsMouse && !!chipFuncion.modelData.detalle
                            ToolTip.text: chipFuncion.modelData.detalle || ""
                            ToolTip.delay: 400
                        }
                    }
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
                    Etiqueta { text: "ACTIVIDADES" }
                    Text { Layout.fillWidth: true; text: "La reunión activa privacidad y No molestar, y pausa el replay. Concentración oculta distracciones. Terminar restaura sus políticas."; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    RowLayout {
                        Layout.fillWidth: true
                        BotonPanel { text: Reunion.activa ? "Terminar reunión" : "Reunión · 30 min"; onClicked: AccionesServicio.ejecutar({tipo:"actividad",id:"reunion"},Reunion.activa ? "terminar" : "iniciar",{minutos:30}) }
                        BotonPanel { text: Concentracion.activo ? "Terminar concentración" : "Concentración · 25 min"; onClicked: AccionesServicio.ejecutar({tipo:"actividad",id:"concentracion"},Concentracion.activo ? "terminar" : "iniciar",{minutos:25}) }
                    }
                    Etiqueta { text: "APARIENCIA" }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Continuar proyecto en el lanzador"; color: Paleta.texto; font.family: Paleta.fuente }
                        Interruptor {
                            activo: PreferenciasUI.mostrarContinuidad
                            Accessible.name: "Continuar proyecto en el lanzador"
                            onAlternado: { PreferenciasUI.mostrarContinuidad = !activo; PreferenciasUI.guardar(); }
                        }
                    }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Perfil visual"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    SelectorPanel {
                        Layout.fillWidth: true
                        model: [{nombre:"Cristal",id:"cristal"},{nombre:"Lectura · opaco",id:"lectura"},{nombre:"Mínimo · sin movimiento",id:"minimo"},{nombre:"Sin efectos ni huecos",id:"rendimiento"}]
                        textRole: "nombre"; valueRole: "id"
                        currentIndex: model.findIndex(p => p.id === EstadoEscritorio.perfil)
                        onActivated: ventana.escritorio(["perfil",currentValue])
                    }
                }
                    AjustesApariencia { Layout.fillWidth: true }
                    Text { Layout.fillWidth: true; text: "Automatizaciones: " + EstadoEscritorio.motivos; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    Etiqueta { text: "MÁS CONTROLES · ★ FIJA HASTA DOS" }
                    Repeater {
                        model: ["replay","rendimiento","conservacion","luz"]
                        RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            ControlRapido {
                                compacto: true
                                cosa: modelData; nombre: ventana.nombreControl(cosa); simbolo: ventana.iconoControl(cosa); dato: ventana.estados[cosa] ?? null
                                onConfirmado: (estado) => { ventana.guardarEstado(cosa,estado); if (cosa === "replay") leerReplay.running = true; }
                                onFallo: (mensaje) => ventana.avisoControl = nombre + ": " + mensaje
                                onConsultar: if (!leerConmutadores.running) leerConmutadores.running = true
                            }
                            BotonCompacto { Layout.preferredWidth: 40; Layout.fillHeight: true; text: PreferenciasUI.favoritosControles.includes(modelData) ? "★" : "☆"; Accessible.name: "Fijar " + ventana.nombreControl(modelData); onClicked: PreferenciasUI.alternarFavorito("control",modelData) }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "Energía alta cambia el rendimiento del equipo. El perfil visual solo cambia la apariencia."; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    Text { Layout.fillWidth: true; text: ventana.replayEstado; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                    RowLayout {
                        Layout.fillWidth: true
                        BotonPanel { text: "Capturar"; onClicked: ventana.ejecutar("qs ipc call menu capturas",true) }
                        BotonPanel { text: "Buds Manager"; onClicked: ventana.ejecutar("buds-manager",true) }
                    }
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
                        BotonPanel { text: "Encender"; simbolo: ventana.g(0xF0450); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["replay", "start"]) }
                        BotonPanel { text: "Apagar"; simbolo: ventana.g(0xF03E4); enabled: !procEscritorio.running; onClicked: ventana.escritorio(["replay", "stop"]) }
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
                        text: "La privacidad oculta títulos, silencia los avisos y pausa el replay. Los checkpoints duran esta sesión."
                        wrapMode: Text.Wrap
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
