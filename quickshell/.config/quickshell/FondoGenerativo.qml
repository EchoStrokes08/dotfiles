// FondoGenerativo: el fondo deja de ser una imagen y pasa a ser una aurora viva (shaders/aurora.frag) con
// los colores del tema. Cambia con la hora (de noche, más oscuro y con estrellas), con el clima (si llueve,
// más frío) y con la música (las cortinas de luz laten con los graves). Entre espacios la cámara se desliza
// como el panorama, también siguiendo a los dedos (Gestos.qml).
// Ahorra: se dibuja a media resolución y se congela (queda la última imagen) cuando hay ventanas en el
// espacio, con el perfil rendimiento o jugando. Preferencia: PreferenciasUI.fondoGenerativo.
// El shader se compila con qsb a ~/.cache/quickshell/aurora.frag.qsb la primera vez (y si cambia la fuente).
// Una por pantalla (shell.qml), encima de awww y del panorama.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: fg
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int espacio: monitor?.activeWorkspace?.id ?? 1
    readonly property bool vacio: (monitor?.activeWorkspace?.toplevels.values.length ?? 0) === 0
    readonly property bool juego: EstadoEscritorio.datos.juego_activo === "true"
    readonly property bool vivo: vacio && !juego && EstadoEscritorio.perfil !== "rendimiento" && !Paleta.reducirMovimiento

    visible: PreferenciasUI.fondoGenerativo && compilado !== ""
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-fondo-generativo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // ── Compilar el shader (una vez; otra si la fuente es más nueva) ──────
    property string compilado: ""
    readonly property string fuente: Qt.resolvedUrl("shaders/aurora.frag").toString().replace("file://", "")
    Process {
        running: PreferenciasUI.fondoGenerativo && fg.compilado === ""
        command: ["sh", "-c",
            'o="$HOME/.cache/quickshell/aurora.frag.qsb"; mkdir -p "${o%/*}"; ' +
            '[ "$o" -nt "$1" ] || /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o "$o" "$1" >&2 || exit 1; echo "$o"',
            "sh", fg.fuente];
        stdout: StdioCollector { onStreamFinished: { const r = text.trim(); if (r) fg.compilado = "file://" + r; } }
    }

    // ── Lo que mueve la aurora ──────────────────────────────────────────
    property real tiempo: 0
    Timer {   // 30 fps bastan para algo tan lento; parado si no se ve
        interval: 33; repeat: true
        running: fg.visible && fg.vivo
        onTriggered: fg.tiempo += .033 * (1 + .5 * fg.energia)
    }
    // Música: los graves, suavizados
    property real energia: Isla.suena ? Math.min(1, ((Isla.ondas[0] ?? 0) + (Isla.ondas[1] ?? 0) + (Isla.ondas[2] ?? 0)) / 240) : 0
    Behavior on energia { NumberAnimation { duration: 90 } }
    // Hora: noche de 20:00 a 5:00, con transición de 17:30 a 20:00 y de 5:00 a 7:00
    SystemClock { id: reloj; precision: SystemClock.Minutes }
    readonly property real noche: {
        const h = reloj.date.getHours() + reloj.date.getMinutes() / 60;
        if (h >= 20 || h < 5) return 1;
        if (h >= 17.5) return (h - 17.5) / 2.5;
        if (h < 7) return 1 - (h - 5) / 2;
        return 0;
    }
    property real lluvia: ({ llovizna: .4, lluvia: .7, chubasco: .85, tormenta: 1, niebla: .5, nubes: .25 })[Clima.vivo] ?? 0
    Behavior on lluvia { NumberAnimation { duration: 3000 } }

    // Cámara entre espacios (como Panorama.qml), siguiendo a los dedos durante el gesto
    readonly property bool siguiendo: Gestos.activo && Gestos.dedos === 3 && Gestos.eje === "h"
    property real arrastre: 0
    property real desplazamiento: (Math.max(1, Math.min(10, espacio)) - 1 + arrastre) * .45
    Behavior on desplazamiento {
        enabled: !fg.siguiendo
        NumberAnimation { duration: EstiloPanel.movimiento ? 1100 : 0; easing.type: Easing.OutCubic }
    }
    Connections {
        target: Gestos
        function onDxChanged() { if (fg.siguiendo) fg.arrastre = Math.max(-1, Math.min(1, -Gestos.dx / 300)); }
        function onTermino() { if (fg.arrastre !== 0) soltar.restart(); }
    }
    Timer { id: soltar; interval: 300; onTriggered: fg.arrastre = 0 }
    onEspacioChanged: if (arrastre !== 0) { soltar.stop(); arrastre = 0; }

    // ── El dibujo, a media resolución ───────────────────────────────────
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.textureSize: Qt.size(Math.ceil(width / 2), Math.ceil(height / 2))
        layer.smooth: true
        ShaderEffect {
            anchors.fill: parent
            fragmentShader: fg.compilado
            property real tiempo: fg.tiempo
            property real energia: fg.energia
            property real noche: fg.noche
            property real lluvia: fg.lluvia
            property real desplazamiento: fg.desplazamiento
            property size resolucion: Qt.size(width, height)
            property color color1: Paleta.acento
            property color color2: Paleta.acento2
            property color color3: Paleta.serie[4]
            property color fondo: Qt.darker(Paleta.fondo, 1.35)
        }
    }
}
