// Vista general (SUPER+ESPACIO o SUPER + 3 dedos arriba): todos los workspaces con sus ventanas
// en miniatura EN VIVO (ScreencopyView), como Mission Control.
//   clic en una ventana = ir a ella · clic en un hueco = ir a ese workspace
//   arrastrar una ventana a otro workspace = moverla allí · 1-9 = ir a ese workspace · Esc cierra
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Superpuesta {
    id: vista
    espacio: "vista"
    anchoTarjeta: (screen?.width ?? 1280) * 0.92
    alturaRelativa: 0.05

    onAbriendose: { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); refresco.restart(); foco.forceActiveFocus(); }
    Timer { id: refresco; interval: 150; onTriggered: Hyprland.refreshToplevels() }   // posiciones al día

    function ir(cmd) { Hyprland.dispatch(cmd); abierto = false; }

    // Workspaces normales con ventanas + el actual (aunque esté vacío), en orden
    readonly property var espacios: {
        const activo = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
        return Hyprland.workspaces.values
            .filter(w => w.id > 0 && (w.id === activo || Hyprland.toplevels.values.some(t => t.workspace?.id === w.id)))
            .sort((a, b) => a.id - b.id);
    }
    readonly property int columnas: espacios.length <= 2 ? 2 : espacios.length <= 6 ? 3 : 4

    FocusScope {
        id: foco
        width: parent.width
        height: columna.implicitHeight
        focus: true
        Keys.onPressed: (e) => {
            if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { vista.ir(`hl.dsp.focus({ workspace = ${e.key - Qt.Key_0} })`); e.accepted = true; }
        }
        Keys.onEscapePressed: vista.abierto = false

        ColumnLayout {
            id: columna
            width: parent.width
            spacing: 12

            GridLayout {
                id: rejilla
                Layout.fillWidth: true
                columns: vista.columnas
                columnSpacing: 14; rowSpacing: 14
                readonly property real anchoCelda: (width - (columns - 1) * columnSpacing) / columns

                Repeater {
                    model: vista.espacios
                    Rectangle {
                        id: celda
                        required property var modelData
                        readonly property var mon: modelData.monitor
                        // tamaño LÓGICO del monitor (las ventanas vienen en lógicas: con escala 1,5, 1920 px = 1280)
                        readonly property real anchoLog: (mon?.width ?? 1920) / (mon?.scale ?? 1)
                        readonly property real altoLog: (mon?.height ?? 1080) / (mon?.scale ?? 1)
                        readonly property real escala: rejilla.anchoCelda / Math.max(1, anchoLog)
                        readonly property bool activo: modelData.id === (Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1)
                        Layout.preferredWidth: rejilla.anchoCelda
                        Layout.preferredHeight: altoLog * escala + 22
                        radius: 10
                        color: Qt.alpha(Paleta.texto, destino.containsDrag ? 0.14 : 0.05)
                        border { width: activo || destino.containsDrag ? 2 : 1; color: activo || destino.containsDrag ? Paleta.naranja : Qt.alpha(Paleta.texto, 0.1) }

                        Text {
                            x: 10; y: 3
                            text: celda.modelData.id + (celda.modelData.name !== String(celda.modelData.id) ? "  " + celda.modelData.name : "")
                            color: celda.activo ? Paleta.naranja : Paleta.gris
                            font { family: Paleta.fuente; pixelSize: 12; bold: true }
                        }
                        // hueco = ir al workspace
                        MouseArea {
                            anchors.fill: parent
                            onClicked: vista.ir(`hl.dsp.focus({ workspace = ${celda.modelData.id} })`)
                        }
                        // soltar aquí una ventana = moverla a este workspace
                        DropArea {
                            id: destino
                            anchors.fill: parent
                            keys: ["ventana"]
                            onDropped: (d) => {
                                Hyprland.dispatch(`hl.dsp.window.move({ window = "address:0x${d.source.dir}", workspace = ${celda.modelData.id}, follow = false })`);
                                refresco.restart();
                            }
                        }

                        // pantalla en miniatura con sus ventanas
                        Item {
                            id: pantalla
                            x: 0; y: 22
                            width: parent.width; height: parent.height - 22
                            clip: true
                            Repeater {
                                model: Hyprland.toplevels.values.filter(t => t.workspace?.id === celda.modelData.id)
                                Item {
                                    id: ventanita
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject
                                    readonly property string dir: modelData.address
                                    readonly property real x0: ((ipc?.at?.[0] ?? 0) - (celda.mon?.x ?? 0)) * celda.escala
                                    readonly property real y0: ((ipc?.at?.[1] ?? 0) - (celda.mon?.y ?? 0)) * celda.escala
                                    x: x0; y: y0
                                    width: Math.max(20, (ipc?.size?.[0] ?? 200) * celda.escala)
                                    height: Math.max(14, (ipc?.size?.[1] ?? 150) * celda.escala)
                                    z: arrastre.drag.active ? 10 : (ipc?.floating ? 2 : 1)
                                    Drag.active: arrastre.drag.active
                                    Drag.keys: ["ventana"]
                                    Drag.source: ventanita
                                    Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: Paleta.seleccion
                                        border { width: arrastre.containsMouse ? 2 : 1; color: arrastre.containsMouse ? Paleta.naranja : Qt.alpha(Paleta.texto, 0.15) }
                                        clip: true
                                        ScreencopyView {
                                            anchors { fill: parent; margins: 1 }
                                            captureSource: vista.abierto ? ventanita.modelData.wayland : null
                                            live: true
                                        }
                                        Text {   // si aún no hay imagen: el título
                                            anchors.centerIn: parent
                                            width: parent.width - 8
                                            visible: !ventanita.modelData.wayland
                                            text: ventanita.ipc?.class ?? ""
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            color: Paleta.gris
                                            font { family: Paleta.fuente; pixelSize: 9 }
                                        }
                                    }
                                    MouseArea {
                                        id: arrastre
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        drag.target: ventanita
                                        onReleased: {
                                            if (ventanita.Drag.target) ventanita.Drag.drop();
                                            ventanita.x = Qt.binding(() => ventanita.x0);
                                            ventanita.y = Qt.binding(() => ventanita.y0);
                                        }
                                        onClicked: vista.ir(`hl.dsp.focus({ window = "address:0x${ventanita.dir}" })`)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "clic: ir   ·   arrastrar una ventana a otro workspace: moverla   ·   1-9: workspace   ·   esc"
                color: Qt.alpha(Paleta.gris, 0.8)
                font { family: Paleta.fuente; pixelSize: 10 }
            }
        }
    }
}
