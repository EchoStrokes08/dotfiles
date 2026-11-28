// Lado derecho de la barra. Siempre: bandeja · volumen · red (solo icono) · batería · avisos.
// Solo cuando importan: grabación, cámara en uso (Camara.qml), móvil con batería baja, actualizaciones, Buds conectados,
// CPU o RAM altas, concentración y modo juego activos. Energía siempre permite abrir el selector.
//
// Para que un script avise de un cambio al momento (en vez de esperar al sondeo):
//   qs ipc call barra refrescar buds        (también: modo-juego, red, grabacion)
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

RowLayout {
    id: derecha
    property bool prioridad: false
    property bool compacto: false
    property var ventana: null              // la PanelWindow (para tooltip y menús de la bandeja)
    spacing: 0

    function g(cp) { return String.fromCodePoint(cp); }   // icono Nerd Font por su código
    signal antesDeEjecutar()   // la barra marca el origen: el panel que se abra nace del botón pulsado
    function ejecutar(cmd) { antesDeEjecutar(); Quickshell.execDetached(["sh", "-c", cmd]); }

    function refrescar(que) {
        if (que === "buds" || que === "todo") buds.leer();
        if (que === "modo-juego" || que === "todo") modoJuego.leer();
        if (que === "red" || que === "todo") red.leer();
        if (que === "grabacion" || que === "todo") grabacion.leer();
    }

    Ayuda { id: ayuda; ventana: derecha.ventana }

    // Las ondas de la música (cava) viven ahora en la isla del reloj: RelojBarra.qml / Isla.qml

    // ── Grabando / dictando (solo visible mientras pasa) ─────────────────
    // grabar.sh y dictado.sh avisan con «qs ipc call barra refrescar grabacion»
    Modulo {
        id: grabacion
        property string modo: ""          // modo de grabar.sh ("" = no graba)
        property int inicio: 0
        property bool dictando: false
        property int ahora: 0
        function leer() { if (!lectorGrab.running) lectorGrab.running = true; }
        Component.onCompleted: leer()
        Process {
            id: lectorGrab
            command: ["sh", "-c", 'r=${XDG_RUNTIME_DIR:-/tmp}; p=$(cat $r/grabar.pid 2>/dev/null); ' +
                      '[ -n "$p" ] && kill -0 $p 2>/dev/null && cat $r/grabar.estado; echo "|"; ' +
                      'd=$(cat $r/dictado.pid 2>/dev/null); [ -n "$d" ] && kill -0 $d 2>/dev/null && echo si']
            stdout: StdioCollector {
                onStreamFinished: {
                    const [g, d] = this.text.split("|");
                    const c = g.trim().split(" ");
                    grabacion.modo = c.length >= 3 ? c[0] : "";
                    grabacion.inicio = c.length >= 3 ? Number(c[c.length - 1]) : 0;
                    grabacion.dictando = d.trim() === "si";
                    grabacion.ahora = Math.floor(Date.now() / 1000);
                }
            }
        }
        Timer { interval: 1000; repeat: true; running: grabacion.visible; onTriggered: grabacion.ahora = Math.floor(Date.now() / 1000) }
        readonly property int seg: Math.max(0, ahora - inicio)
        visible: modo !== "" || dictando
        gestorAyuda: ayuda
        icono: derecha.g(modo !== "" ? 0xF044A : 0xF036C)
        texto: modo !== "" ? `${derecha.compacto ? "" : "Grabando pantalla "}${Math.floor(seg / 60)}:${String(seg % 60).padStart(2, "0")}${modo === "gif" ? " GIF" : ""}` : "dictando"
        color: Paleta.peligro
        ayuda: modo !== "" ? "Grabando la pantalla · clic o SUPER+ALT+R para parar" : "Dictando · clic o SUPER+ALT+D para terminar"
        onClic: derecha.ejecutar(modo !== "" ? "~/.config/hypr/scripts/grabar.sh parar" : "~/.config/hypr/scripts/dictado.sh")
    }

    Bandeja { ventana: derecha.ventana; ocultarBuds: buds.visible }

    // ── Móvil (KDE Connect): batería; solo si hay uno emparejado y conectado ──
    Modulo {
        id: movil
        property string nombre: ""
        property int carga: -1
        property bool cargando: false
        function leer() { if (!lectorMovil.running) lectorMovil.running = true; }
        Timer { interval: 120000; running: true; repeat: true; triggeredOnStart: true; onTriggered: movil.leer() }
        Process {
            id: lectorMovil
            command: ["sh", "-c", "~/.config/hypr/scripts/movil.sh estado"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = this.text.trim().split("|");
                    movil.nombre = p.length >= 3 ? p[0] : "";
                    movil.carga = p.length >= 3 && p[1] !== "" ? +p[1] : -1;
                    movil.cargando = p[2] === "true";
                }
            }
        }
        visible: nombre !== "" && carga >= 0 && carga <= 20 && !cargando   // solo si pide atención: batería baja
        gestorAyuda: ayuda
        icono: derecha.g(0xF011C)
        texto: carga >= 0 ? carga + "%" : ""
        color: cargando ? Paleta.exito : carga >= 0 && carga <= 15 ? Paleta.peligro : Paleta.texto
        ayuda: nombre + (cargando ? " · cargando" : "") + "\nClic: centro de control › Móvil · clic derecho: hacer sonar"
        onClic: (b) => derecha.ejecutar("~/.config/hypr/scripts/movil.sh " + (b === Qt.RightButton ? "sonar" : "menu"))
    }

    // ── Actualizaciones pendientes: solo aparece si hay algo (Actualizaciones.qml, cada 3 h) ──
    Modulo {
        visible: Actualizaciones.total > 0 || Actualizaciones.noticias > 0
        gestorAyuda: ayuda
        icono: derecha.g(0xF03D6)
        texto: Actualizaciones.total > 0 ? String(Actualizaciones.total) : "!"
        color: Actualizaciones.noticias > 0 ? Paleta.peligro : Actualizaciones.vulnerables > 0 ? Paleta.aviso : Paleta.texto
        ayuda: `${Actualizaciones.repos} de los repos · ${Actualizaciones.aur} del AUR`
               + (Actualizaciones.noticias > 0 ? `\n${Actualizaciones.noticias} noticia(s) de Arch sin leer (se muestran antes de actualizar)` : "")
               + (Actualizaciones.vulnerables > 0 ? `\n${Actualizaciones.vulnerables} con arreglos de seguridad` : "")
               + (Actualizaciones.lista ? "\n" + Actualizaciones.lista : "")
               + "\nClic: actualizar · clic derecho: volver a comprobar"
        onClic: (b) => b === Qt.RightButton ? Actualizaciones.refrescar() : derecha.ejecutar("~/.config/hypr/scripts/actualizaciones.sh instalar")
    }

    // ── Redmi Buds: izquierdo · derecho · estuche ────────────────────────
    Item {
        id: buds
        readonly property string macPreferida: (Quickshell.env("REDMI_BUDS_MAC") ?? "").toUpperCase()
        readonly property string mac: (Bluetooth.defaultAdapter?.devices?.values ?? [])
            .find(d => d.connected && (macPreferida ? d.address.toUpperCase() === macPreferida
                                                    : /redmi buds|xiaomi buds/i.test(d.deviceName + " " + d.name)))?.address ?? ""
        property var partes: []
        property string ultimaLectura: ""
        property bool lecturaPendiente: false
        property int conexion: 0
        readonly property string ayudaTexto: partes[0]?.tooltip ?? "Redmi Buds conectados · esperando lectura de batería"
        visible: mac !== ""
        implicitWidth: filaBuds.implicitWidth + 20
        implicitHeight: 34

        function leer() {
            if (!mac) return;
            if (lectorBuds.running) {
                lecturaPendiente = true;
                return;
            }
            lecturaPendiente = false;
            lectorBuds.conexion = conexion;
            lectorBuds.command = [Quickshell.env("HOME") + "/.local/bin/buds", "--mac", mac, "waybar", "--parts"];
            lectorBuds.running = true;
        }
        onMacChanged: {
            conexion++;
            partes = [];
            ultimaLectura = "";
            leer();
        }
        Component.onCompleted: leer()
        onAyudaTextoChanged: if (zonaBuds.containsMouse) ayuda.texto = ayudaTexto
        Timer { interval: 10000; running: buds.visible; repeat: true; onTriggered: buds.leer() }

        Process {
            id: lectorBuds
            property int conexion: -1
            onExited: if (buds.lecturaPendiente) Qt.callLater(buds.leer)
            stdout: StdioCollector {
                onStreamFinished: {
                    if (lectorBuds.conexion !== buds.conexion || this.text === buds.ultimaLectura) return;
                    try {
                        const datos = JSON.parse(this.text);
                        if (!Array.isArray(datos)) return;
                        buds.partes = datos;
                        buds.ultimaLectura = this.text;
                    } catch (e) {}
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 5; anchors.bottomMargin: 5
            radius: height / 2
            // Una sola cápsula para las tres partes: se leen como un dispositivo (ORION 5.7)
            color: zonaBuds.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
            border { width: 1; color: EstiloPanel.borde }
        }

        RowLayout {
            id: filaBuds
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: buds.partes.length === 0
                text: derecha.g(0xF02CB)
                font { family: Paleta.mono; pixelSize: EstiloPanel.t16 }
                color: Paleta.texto
            }
            Repeater {
                model: buds.partes
                RowLayout {
                    id: pieza
                    required property var modelData
                    readonly property bool cargando: modelData.class.includes("charging")
                    spacing: 2
                    Image {
                        sourceSize { width: 18; height: 18 }
                        source: "file://" + modelData.icon + "?v=" + modelData.icon_version
                        cache: false
                    }
                    Text {
                        text: modelData.text
                        font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
                        color: modelData.class.includes("low") || modelData.class.includes("critical") ? Paleta.peligro
                             : pieza.cargando ? Paleta.aviso
                             : modelData.class.includes("anc") ? Paleta.acento2
                             : modelData.class.includes("transparency") ? Paleta.exito
                             : Paleta.texto
                    }
                    Rectangle {
                        visible: pieza.cargando
                        implicitWidth: 14
                        implicitHeight: 16
                        Layout.leftMargin: 2
                        radius: width / 2
                        color: Qt.alpha(Paleta.aviso, 0.12)
                        border { width: 1; color: Qt.alpha(Paleta.aviso, 0.26) }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Paleta.aviso
                                strokeWidth: 1.5
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: 8.1; startY: 3.4
                                PathLine { x: 4.8; y: 8.3 }
                                PathLine { x: 9.2; y: 7.7 }
                                PathLine { x: 5.9; y: 12.6 }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: zonaBuds
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (e) => derecha.ejecutar(
                e.button === Qt.MiddleButton ? "~/.local/bin/buds-manager"
              : e.button === Qt.RightButton  ? "~/.local/bin/buds mode toggle --notify"
              : "~/.local/bin/buds mode next --notify")
            onContainsMouseChanged: containsMouse && buds.ayudaTexto ? ayuda.mostrar(buds, buds.ayudaTexto) : ayuda.ocultar()
        }
    }

    DivisorBarra {}   // separa grupos: bandeja · sonido y red · sistema · avisos

    // ── Volumen (PipeWire) ──────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Modulo {
        readonly property var salida: Pipewire.defaultAudioSink
        readonly property real vol: salida?.audio?.volume ?? 0
        readonly property bool mudo: salida?.audio?.muted ?? false
        gestorAyuda: ayuda
        icono: mudo ? derecha.g(0xF075F) : derecha.g(vol < 0.34 ? 0xF057F : vol < 0.67 ? 0xF0580 : 0xF057E)
        texto: mudo ? "" : Math.round(vol * 100) + "%"
        color: mudo ? Paleta.peligro : Paleta.texto
        ayuda: (salida?.description ?? "") + "\nClic: sonido · Clic derecho: silenciar · Rueda: volumen"
        onClic: boton => derecha.ejecutar(boton === Qt.RightButton ? "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" : "qs ipc call notificaciones sonido")   // el OSD reacciona solo
        onRueda: (arriba) => derecha.ejecutar(arriba ? "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    }

    Modulo {
        id: microActividad
        readonly property var flujos: Pipewire.nodes.values.filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio")
        readonly property string aplicaciones: EstadoEscritorio.privacidad ? "" : [...new Set(flujos.map(n => n.properties["application.name"]).filter(Boolean))].join(", ")
        visible: flujos.length > 0
        texto: derecha.compacto ? "" : aplicaciones ? "Micrófono · " + (aplicaciones.length > 18 ? aplicaciones.slice(0, 17) + "…" : aplicaciones) : "Micrófono en uso"
        icono: derecha.g(0xF036C)
        color: Paleta.peligro
        ayuda: "Micrófono en uso" + (aplicaciones ? " · " + aplicaciones : "") + "\nClic: sonido · Clic derecho: silenciar"
        gestorAyuda: ayuda
        onClic: boton => derecha.ejecutar(boton === Qt.RightButton ? "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" : "qs ipc call notificaciones sonido")
    }

    Modulo {
        id: camaraActividad
        visible: Camara.enUso
        texto: derecha.compacto ? "" : "Cámara"
        icono: derecha.g(0xF05A0)
        color: Paleta.exito
        ayuda: "Cámara en uso\nUna app tiene abierta la webcam"
        gestorAyuda: ayuda
    }

    // ── Red (NetworkManager) ─────────────────────────────────────────────
    Modulo {
        id: red
        property string tipo: ""        // wifi | ethernet | ""
        property string nombre: ""
        property string detalle: ""
        function leer() { if (!lectorRed.running) lectorRed.running = true; }
        Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: red.leer() }
        // Por eventos: NetworkManager avisa de cada cambio (conectar, desconectar, cambiar de red)
        Process {
            running: true
            command: ["nmcli", "monitor"]
            stdout: SplitParser { onRead: (linea) => { if (/connect|disconnect|unavailable|using connection/i.test(linea)) esperaRed.restart(); } }
        }
        Timer { id: esperaRed; interval: 800; onTriggered: red.leer() }   // agrupa la ráfaga de mensajes de un cambio
        Process {
            id: lectorRed
            command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION,DEVICE device | grep ':connected:' | head -1 | " +
                      "{ IFS=: read t s c d; [ -n \"$d\" ] && echo \"$t|$c|$d|$(nmcli -g IP4.ADDRESS device show $d | head -1)\"; }"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const p = this.text.trim().split("|");
                    red.tipo = p[0] === "802-11-wireless" || p[0] === "wifi" ? "wifi" : p[0] === "ethernet" ? "ethernet" : "";
                    red.nombre = p[1] ?? "";
                    red.detalle = p.length > 3 ? `${p[2]}: ${p[3]}` : "";
                }
            }
        }
        gestorAyuda: ayuda
        icono: derecha.g(tipo === "wifi" ? 0xF0928 : tipo === "ethernet" ? 0xF0200 : 0xF092D)
        texto: tipo === "" ? "sin red" : ""     // el nombre de la red, en la ayuda
        color: tipo === "" ? Paleta.peligro : Paleta.texto
        ayuda: (tipo === "wifi" ? nombre + "\n" : "") + (detalle || "Sin conexión") + "\nClic: redes Wi-Fi · clic derecho: nmtui"
        onClic: (b) => derecha.ejecutar(b === Qt.RightButton ? "kitty -e nmtui" : "qs ipc call conexiones wifi")
    }

    // ── Batería (UPower) ─────────────────────────────────────────────────
    Modulo {
        id: bateria
        readonly property var bat: UPower.displayDevice
        readonly property real carga: bat ? (bat.percentage > 1 ? bat.percentage / 100 : bat.percentage) : 0
        readonly property int pct: Math.round(carga * 100)
        // enchufada = hay corriente (aunque no cargue: el modo conservación de Lenovo para en ~80 %)
        readonly property bool cargando: !UPower.onBattery
        function duracion(s) { const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h > 0 ? `${h} h ${m} min` : `${m} min`; }
        visible: bat?.isLaptopBattery ?? false
        gestorAyuda: ayuda
        icono: derecha.g(cargando ? 0xF0084 : pct >= 95 ? 0xF0079 : 0xF007A + Math.max(0, Math.min(8, Math.floor(pct / 10) - 1)))
        texto: pct + "%"
        color: cargando ? Paleta.exito : pct <= 15 ? Paleta.peligro : pct <= 30 ? Paleta.aviso : Paleta.texto
        ayuda: (cargando ? (bat?.timeToFull > 0 ? "Enchufada · llena en " + duracion(bat.timeToFull) : "Enchufada")
                         : (bat?.timeToEmpty > 0 ? "Quedan " + duracion(bat.timeToEmpty) : "Batería"))
             + (conservacion ? "\nModo conservación: carga hasta ~80 %" : "\nCarga completa (100 %)")
             + "\nBotón «Conservar» en el centro de control"
        // Modo conservación de Lenovo (lo cambia el botón del centro de control; se lee cada 30 s)
        property bool conservacion: false
        FileView { id: archivoConserv; path: "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"; blockLoading: true }
        Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: { archivoConserv.reload(); bateria.conservacion = archivoConserv.text().trim() === "1"; } }
    }

    // ── Modo de energía (power-profiles-daemon) ──────────────────────────
    Modulo {
        readonly property int perfil: PowerProfiles.profile
        gestorAyuda: ayuda
        tamIcono: 16
        icono: derecha.g(perfil === PowerProfile.Performance ? 0xF04C5 : perfil === PowerProfile.PowerSaver ? 0xF0F86 : 0xF0F85)
        color: perfil === PowerProfile.Performance ? Paleta.peligro : perfil === PowerProfile.PowerSaver ? Paleta.exito : Paleta.texto
        ayuda: "Modo de energía: " + (perfil === PowerProfile.Performance ? "rendimiento" : perfil === PowerProfile.PowerSaver ? "ahorro" : "equilibrado")
             + "\nClic: elegir perfil · SUPER+SHIFT+P: alternar"
        onClic: derecha.ejecutar("qs ipc call notificaciones toggle")
    }

    DivisorBarra { visible: cpuMod.visible || ramMod.visible || modoJuego.activo }

    // ── CPU y RAM (Sistema.qml): solo cuando van altas (aparecen > 85 %, se van < 70 %) ──
    Modulo {
        id: cpuMod
        property bool alta: false
        Timer { interval: 5000; running: Sistema.cpu > .85 && !cpuMod.alta; onTriggered: cpuMod.alta = true }
        Connections { target: Sistema; function onCpuChanged() { if (Sistema.cpu < .70) cpuMod.alta = false; } }
        visible: alta
        icono: derecha.g(0xF0EE0)
        texto: Math.round(Sistema.cpu * 100) + "%"
        color: Paleta.aviso
        colorTexto: Sistema.cpu > 0.85 ? Paleta.peligro : Paleta.aviso
        onClic: derecha.ejecutar("kitty -e btop")
    }
    Modulo {
        id: ramMod
        property bool alta: false
        Timer { interval: 5000; running: Sistema.ram > .85 && !ramMod.alta; onTriggered: ramMod.alta = true }
        Connections { target: Sistema; function onRamChanged() { if (Sistema.ram < .70) ramMod.alta = false; } }
        visible: alta
        gestorAyuda: ayuda
        icono: derecha.g(0xF035B)
        texto: Math.round(Sistema.ram * 100) + "%"
        color: Sistema.ram > 0.85 ? Paleta.peligro : Paleta.aviso
        ayuda: Sistema.ramUsadaGiB.toFixed(1) + " GiB / " + Sistema.ramTotalGiB.toFixed(1) + " GiB"
        onClic: derecha.ejecutar("kitty -e btop")
    }

    // La cuenta atrás de la concentración vive en la isla del reloj (modo zen, RelojBarra.qml)

    // ── Modo juego ───────────────────────────────────────────────────────
    Modulo {
        id: modoJuego
        property bool activo: false
        property string ayudaTexto: ""
        function leer() { if (!lectorJuego.running) lectorJuego.running = true; }
        Component.onCompleted: leer()
        Process {
            id: lectorJuego
            command: ["sh", "-c", "~/.config/hypr/scripts/modo-juego-estado.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let d = {};
                    try { d = JSON.parse(this.text); } catch (e) {}
                    modoJuego.activo = d.class === "activo";
                    modoJuego.ayudaTexto = d.tooltip ?? "";
                }
            }
        }
        visible: activo                // solo mientras está activo; se enciende con SUPER+SHIFT+G o solo con un juego
        gestorAyuda: ayuda
        tamIcono: 16
        icono: derecha.g(0xF0297)
        color: activo ? Paleta.acento : Paleta.gris
        ayuda: ayudaTexto
        onClic: Hyprland.dispatch("modo_juego.alternar() or hl.dsp.no_op()")
    }

    DivisorBarra {}

    // ── Notificaciones (Notificaciones.qml) ──────────────────────────────
    Modulo {
        readonly property int cuantas: Notificaciones.lista.length
        readonly property bool dnd: Notificaciones.noMolestar
        gestorAyuda: ayuda
        relleno: 11
        tamIcono: 16
        icono: derecha.g(dnd ? 0xF009B : cuantas > 0 ? 0xF116B : 0xF009A)
        texto: !dnd && cuantas > 0 ? String(cuantas) : ""
        color: dnd ? Paleta.gris : cuantas > 0 ? Paleta.acento : Paleta.texto
        ayuda: (dnd ? "No molestar activo" : cuantas > 0 ? cuantas + " notificaciones" : "Sin notificaciones")
             + "\nClic: avisos · Clic derecho: no molestar"
        onClic: (b) => {
            if (b === Qt.RightButton) Notificaciones.alternarNoMolestar();
            else derecha.ejecutar("qs ipc call notificaciones avisos");
        }
    }
}
