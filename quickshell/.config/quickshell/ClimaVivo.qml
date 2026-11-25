// ClimaVivo: el clima de verdad sobre el wallpaper (Clima.vivo, de Open-Meteo).
//   llovizna · lluvia · chubasco   gotas finas en diagonal (más o menos) y salpicaduras abajo
//   tormenta                       lluvia fuerte y, cada 6–14 s, un relámpago suave (máx. 0,25)
//   nieve                          copos lentos que se mecen
//   niebla                         bancos de bruma que cruzan despacio
//   nubes                          sombras de nubes pasando sobre el paisaje
// Como las estrellas de Escritorio.qml: solo con el espacio vacío, perfil Cristal y movimiento.
// Debajo de los widgets del escritorio; los clics la atraviesan. Una por pantalla (shell.qml).
//   qs ipc call clima simular <tipo>   para verlo sin esperar al tiempo ("" vuelve al real)
import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: v
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool vacio: (monitor?.activeWorkspace?.toplevels.values.length ?? 0) === 0
    readonly property string tipo: Clima.vivo
    readonly property bool activo: vacio && tipo !== "" && EstiloPanel.efectos && EstiloPanel.movimiento
    readonly property bool lluvioso: tipo === "llovizna" || tipo === "lluvia" || tipo === "chubasco" || tipo === "tormenta"
    readonly property real intensidad: tipo === "llovizna" ? .35 : tipo === "lluvia" ? .7 : 1
    readonly property color claro: Paleta.sobreImagen

    visible: lienzo.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-clima"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Item {
        id: lienzo
        anchors.fill: parent
        opacity: v.activo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1500; easing.type: Easing.InOutSine } }

        ParticleSystem {
            id: sistema
            running: v.visible && (v.lluvioso || v.tipo === "nieve")
        }

        // ── Lluvia ──
        Emitter {
            system: sistema
            group: "gota"
            enabled: v.lluvioso
            x: -v.width * .15; y: -40
            width: v.width * 1.15; height: 1
            emitRate: 170 * v.intensidad
            lifeSpan: 1100; lifeSpanVariation: 200
            startTime: 1300                    // al aparecer ya está lloviendo
            velocity: AngleDirection { angle: 100; angleVariation: 3; magnitude: 950; magnitudeVariation: 150 }
            size: 1
        }
        ItemParticle {
            system: sistema
            groups: ["gota"]
            fade: false
            delegate: Rectangle {
                width: 2; height: 24 + Math.random() * 14
                rotation: 10
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.alpha(v.claro, .42) }
                }
            }
        }
        Emitter {   // salpicaduras en el borde de abajo
            system: sistema
            group: "salpica"
            enabled: v.lluvioso
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
            height: 24
            emitRate: 40 * v.intensidad
            lifeSpan: 320
            velocity: AngleDirection { angle: 270; angleVariation: 50; magnitude: 70; magnitudeVariation: 30 }
            acceleration: PointDirection { y: 300 }
            size: 1
        }
        ItemParticle {
            system: sistema
            groups: ["salpica"]
            delegate: Rectangle { width: 2.5; height: 2.5; radius: width / 2; color: Qt.alpha(v.claro, .35) }
        }

        // ── Nieve ──
        Emitter {
            system: sistema
            group: "copo"
            enabled: v.tipo === "nieve"
            x: -40; y: -20; width: v.width + 80; height: 1
            emitRate: 28
            lifeSpan: 14000
            startTime: 14000                   // al aparecer ya hay copos por toda la pantalla
            velocity: AngleDirection { angle: 90; angleVariation: 12; magnitude: 70; magnitudeVariation: 30 }
            size: 1
        }
        Wander { system: sistema; groups: ["copo"]; xVariance: 60; pace: 40 }
        ItemParticle {
            system: sistema
            groups: ["copo"]
            delegate: Rectangle {
                readonly property real lado: 2 + Math.random() * 4
                width: lado; height: lado; radius: width / 2
                color: Qt.alpha(v.claro, .55 + Math.random() * .3)
            }
        }

        // ── Niebla: bancos de bruma que cruzan (manchas sin bordes) ──
        Repeater {
            model: v.tipo === "niebla" ? 4 : 0
            Bruma {
                required property int index
                width: v.width * (1.1 + (index % 2) * .3); height: v.height * (.35 + (index % 3) * .1)
                y: v.height * (.25 + index * .17) - height / 2
                tono: v.claro
                fuerza: .11
                NumberAnimation on x {
                    running: v.visible
                    loops: Animation.Infinite
                    from: -v.width * (index % 2 ? .1 : .6); to: -v.width * (index % 2 ? .6 : .1)
                    duration: 45000 + index * 13000
                    easing.type: Easing.InOutSine
                }
            }
        }

        // ── Nubes: velos claros que pasan despacio (sobre wallpapers oscuros una sombra no se vería) ──
        Repeater {
            model: v.tipo === "nubes" ? 3 : 0
            Bruma {
                required property int index
                width: v.width * (.7 + index * .15); height: v.height * (.4 + (index % 2) * .15)
                y: v.height * [.05, .3, -.1][index]
                tono: v.claro
                fuerza: .075
                // cada nube empieza en un punto distinto de su recorrido: al aparecer ya están cruzando
                property real fase: 0
                x: -v.width * 1.1 + v.width * 2.2 * ((fase + [.45, .7, .2][index]) % 1)
                NumberAnimation on fase {
                    running: v.visible
                    loops: Animation.Infinite
                    from: 0; to: 1
                    duration: 80000 + index * 30000
                }
            }
        }

        // ── Tormenta: relámpago suave de vez en cuando ──
        Rectangle {
            id: relampago
            anchors.fill: parent
            color: v.claro
            opacity: 0
        }
        Timer {
            id: proximo
            running: v.visible && v.tipo === "tormenta"
            interval: 6000 + Math.random() * 8000
            repeat: true
            onTriggered: { interval = 6000 + Math.random() * 8000; destello.restart(); }
        }
        SequentialAnimation {
            id: destello
            NumberAnimation { target: relampago; property: "opacity"; to: .25; duration: 60 }
            NumberAnimation { target: relampago; property: "opacity"; to: .04; duration: 90 }
            NumberAnimation { target: relampago; property: "opacity"; to: .16; duration: 50 }
            NumberAnimation { target: relampago; property: "opacity"; to: 0; duration: 700; easing.type: Easing.OutCubic }
        }
    }
}
