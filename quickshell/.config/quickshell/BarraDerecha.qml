// Lado derecho de la barra: bandeja · Buds · volumen · red · brillo · batería · energía ·
// CPU · RAM · modo juego · notificaciones (los mismos módulos que tenía waybar).
//
// Para que un script avise de un cambio al momento (en vez de esperar al sondeo):
//   qs ipc call barra refrescar buds        (también: modo-juego, red, brillo)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

RowLayout {
    id: derecha
    property var ventana: null              // la PanelWindow (para tooltip y menús de la bandeja)
    spacing: 0

    function g(cp) { return String.fromCodePoint(cp); }   // icono Nerd Font por su código
    function ejecutar(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    function refrescar(que) {
        if (que === "buds" || que === "todo") buds.leer();
        if (que === "modo-juego" || que === "todo") modoJuego.leer();
        if (que === "red" || que === "todo") red.leer();
        if (que === "brillo" || que === "todo") brillo.leer();
    }

    Ayuda { id: ayuda; ventana: derecha.ventana }

    // ── Bandeja del sistema ─────────────────────────────────────────────
    RowLayout {
        Layout.rightMargin: 4
        spacing: 8
        Repeater {
            model: SystemTray.items.values
            IconImage {
                id: iconoBandeja
                required property var modelData
                implicitSize: 16
                source: modelData.icon
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (e) => {
                        const it = iconoBandeja.modelData;
                        if (e.button === Qt.MiddleButton) it.secondaryActivate();
                        else if (e.button === Qt.RightButton || it.onlyMenu) {
                            if (it.hasMenu) {
                                const p = iconoBandeja.mapToItem(null, 0, iconoBandeja.height);
                                it.display(derecha.ventana, p.x, p.y + 8);
                            }
                        } else it.activate();
                    }
                    onContainsMouseChanged: containsMouse
                        ? ayuda.mostrar(iconoBandeja, iconoBandeja.modelData.tooltipTitle || iconoBandeja.modelData.title || iconoBandeja.modelData.id)
                        : ayuda.ocultar()
                }
            }
        }
    }

    // ── Redmi Buds: izquierdo · derecho · estuche ────────────────────────
    Item {
        id: buds
        property var partes: []        // [{ parte, texto, icono, clase }]
        property string ayudaTexto: ""
        readonly property var visibles: partes.filter(p => p.texto !== "")
        visible: visibles.length > 0
        implicitWidth: filaBuds.implicitWidth + 12
        implicitHeight: 34

        function leer() { if (!lectorBuds.running) lectorBuds.running = true; }
        Timer { interval: 120000; running: true; repeat: true; triggeredOnStart: true; onTriggered: buds.leer() }

        Process {
            id: lectorBuds
            // por cada parte: una línea JSON y otra con la ruta del icono
            command: ["sh", "-c", "for p in left right case; do ~/.local/bin/buds waybar --part $p; echo; ~/.local/bin/buds waybar --part $p --icon; echo; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const l = this.text.split("\n").filter(x => x.trim() !== "");
                    const nombres = ["left", "right", "case"], res = [];
                    for (let i = 0; i + 1 < l.length && res.length < 3; i += 2) {
                        let d = {};
                        try { d = JSON.parse(l[i]); } catch (e) {}
                        res.push({ parte: nombres[res.length], texto: d.text ?? "", icono: l[i + 1].trim(),
                                   clase: [].concat(d.class ?? []), version: Date.now() });
                        if (d.tooltip) buds.ayudaTexto = d.tooltip;
                    }
                    buds.partes = res;
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4; anchors.bottomMargin: 4
            radius: 7
            color: Qt.alpha(Paleta.texto, zonaBuds.containsMouse ? 0.08 : 0)
        }

        RowLayout {
            id: filaBuds
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: buds.visibles
                RowLayout {
                    required property var modelData
                    spacing: 3
                    Image {
                        sourceSize { width: 22; height: 22 }
                        source: "file://" + modelData.icono + "?" + modelData.version   // ?… = no usar la caché
                        cache: false
                    }
                    Text {
                        text: modelData.texto
                        font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
                        color: modelData.clase.includes("low") || modelData.clase.includes("critical") ? Paleta.rojo
                             : modelData.clase.includes("charging") ? Paleta.amarillo
                             : modelData.clase.includes("anc") ? Paleta.azul
                             : modelData.clase.includes("transparency") ? Paleta.verde
                             : Paleta.texto
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

    // ── Volumen (PipeWire) ──────────────────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Modulo {
        readonly property var salida: Pipewire.defaultAudioSink
        readonly property real vol: salida?.audio?.volume ?? 0
        readonly property bool mudo: salida?.audio?.muted ?? false
        gestorAyuda: ayuda
        icono: mudo ? derecha.g(0xF075F) : derecha.g(vol < 0.34 ? 0xF057F : vol < 0.67 ? 0xF0580 : 0xF057E)
        texto: mudo ? "" : Math.round(vol * 100) + "%"
        color: mudo ? Paleta.rojo : Paleta.texto
        ayuda: (salida?.description ?? "") + "\nClic: silenciar · Rueda: volumen"
        onClic: derecha.ejecutar("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")   // el OSD reacciona solo
        onRueda: (arriba) => derecha.ejecutar(arriba ? "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" : "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    }

    // ── Red (NetworkManager) ─────────────────────────────────────────────
    Modulo {
        id: red
        property string tipo: ""        // wifi | ethernet | ""
        property string nombre: ""
        property string detalle: ""
        function leer() { if (!lectorRed.running) lectorRed.running = true; }
        Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: red.leer() }
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
        texto: tipo === "" ? "sin red" : tipo === "wifi" ? nombre : ""
        color: tipo === "" ? Paleta.rojo : Paleta.texto
        ayuda: (detalle || "Sin conexión") + "\nClic: nmtui"
        onClic: derecha.ejecutar("kitty -e nmtui")
    }

    // ── Brillo ──────────────────────────────────────────────────────────
    Modulo {
        id: brillo
        property int porcentaje: 0
        function leer() { if (!lectorBrillo.running) lectorBrillo.running = true; }
        Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: brillo.leer() }
        Process {
            id: lectorBrillo
            command: ["brightnessctl", "-m"]
            stdout: StdioCollector { onStreamFinished: brillo.porcentaje = parseInt(this.text.split(",")[3]) || 0 }
        }
        gestorAyuda: ayuda
        icono: derecha.g(porcentaje < 34 ? 0xF00DE : porcentaje < 67 ? 0xF00DF : 0xF00E0)
        texto: porcentaje + "%"
        ayuda: "Brillo · Rueda: subir/bajar"
        onRueda: (arriba) => {
            derecha.ejecutar("brightnessctl -e4 -n2 set " + (arriba ? "5%+" : "5%-") + " && qs ipc call osd brillo");
            espera.restart();
        }
        Timer { id: espera; interval: 250; onTriggered: brillo.leer() }
    }

    // ── Batería (UPower) ─────────────────────────────────────────────────
    Modulo {
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
        color: cargando ? Paleta.verde : pct <= 15 ? Paleta.rojo : pct <= 30 ? Paleta.amarillo : Paleta.texto
        ayuda: cargando ? (bat?.timeToFull > 0 ? "Enchufada · llena en " + duracion(bat.timeToFull) : "Enchufada")
                        : (bat?.timeToEmpty > 0 ? "Quedan " + duracion(bat.timeToEmpty) : "Batería")
    }

    // ── Modo de energía (power-profiles-daemon) ──────────────────────────
    Modulo {
        readonly property int perfil: PowerProfiles.profile
        gestorAyuda: ayuda
        tamIcono: 16
        icono: derecha.g(perfil === PowerProfile.Performance ? 0xF04C5 : perfil === PowerProfile.PowerSaver ? 0xF0F86 : 0xF0F85)
        color: perfil === PowerProfile.Performance ? Paleta.rojo : perfil === PowerProfile.PowerSaver ? Paleta.verde : Paleta.texto
        ayuda: "Modo de energía: " + (perfil === PowerProfile.Performance ? "rendimiento" : perfil === PowerProfile.PowerSaver ? "ahorro" : "equilibrado")
             + "\nClic: cambiar · SUPER+SHIFT+P"
        onClic: derecha.ejecutar("~/.config/hypr/scripts/modo-energia.sh")
    }

    // ── CPU y RAM (Sistema.qml) ──────────────────────────────────────────
    Modulo {
        icono: derecha.g(0xF0EE0)
        texto: Math.round(Sistema.cpu * 100) + "%"
        color: Paleta.gris
        colorTexto: Sistema.cpu > 0.85 ? Paleta.rojo : Paleta.gris
        onClic: derecha.ejecutar("kitty -e btop")
    }
    Modulo {
        gestorAyuda: ayuda
        icono: derecha.g(0xF035B)
        texto: Math.round(Sistema.ram * 100) + "%"
        color: Paleta.gris
        ayuda: Sistema.ramUsadaGiB.toFixed(1) + " GiB / " + Sistema.ramTotalGiB.toFixed(1) + " GiB"
        onClic: derecha.ejecutar("kitty -e btop")
    }

    // ── Modo concentración (solo durante una sesión) ─────────────────────
    Modulo {
        visible: Concentracion.activo
        gestorAyuda: ayuda
        icono: derecha.g(0xF04FE)
        texto: Concentracion.texto()
        color: Paleta.naranja
        ayuda: "Concentración: " + Concentracion.minutos + " min · apps que distraen escondidas\nClic: añadir tiempo o terminar"
        onClic: derecha.ejecutar("qs ipc call menu concentracion")
    }

    // ── Modo juego ───────────────────────────────────────────────────────
    Modulo {
        id: modoJuego
        property bool activo: false
        property string ayudaTexto: ""
        function leer() { if (!lectorJuego.running) lectorJuego.running = true; }
        Component.onCompleted: leer()
        Process {
            id: lectorJuego
            command: ["sh", "-c", "~/.config/hypr/scripts/modo-juego-waybar.sh"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let d = {};
                    try { d = JSON.parse(this.text); } catch (e) {}
                    modoJuego.activo = d.class === "activo";
                    modoJuego.ayudaTexto = d.tooltip ?? "";
                }
            }
        }
        gestorAyuda: ayuda
        tamIcono: 16
        icono: derecha.g(0xF0297)
        color: activo ? Paleta.naranja : Paleta.gris
        ayuda: ayudaTexto
        onClic: Hyprland.dispatch("modo_juego.alternar() or hl.dsp.no_op()")
    }

    // ── Notificaciones (Notificaciones.qml) ──────────────────────────────
    Modulo {
        readonly property int cuantas: Notificaciones.lista.length
        readonly property bool dnd: Notificaciones.noMolestar
        gestorAyuda: ayuda
        relleno: 11
        tamIcono: 16
        icono: derecha.g(dnd ? 0xF009B : cuantas > 0 ? 0xF116B : 0xF009A)
        texto: !dnd && cuantas > 0 ? String(cuantas) : ""
        color: dnd ? Paleta.gris : cuantas > 0 ? Paleta.naranja : Paleta.texto
        ayuda: (dnd ? "No molestar activo" : cuantas > 0 ? cuantas + " notificaciones" : "Sin notificaciones")
             + "\nClic: centro de control · Clic derecho: no molestar"
        onClic: (b) => {
            if (b === Qt.RightButton) Notificaciones.alternarNoMolestar();
            else derecha.ejecutar("qs ipc call notificaciones toggle");
        }
    }
}
