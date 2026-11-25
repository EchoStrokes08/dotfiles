// CapaConmutador: el carrusel 3D de ALT+TAB (estado en Conmutador.qml).
// La elegida al frente; las demás se giran hacia los lados con perspectiva y se apagan con la distancia.
// Debajo: icono, título, espacio y «3 de 7». Al soltar ALT la elegida crece hasta donde está la ventana
// real (su espacio aparece debajo) y la capa se desvanece. Miniaturas en vivo (ScreencopyView), sin ellas
// con la privacidad activa. Fondo desenfocado por Hyprland (reglas.lua). Solo en la pantalla con el foco.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    screen: Quickshell.screens.find(s => s.name === Conmutador.pantalla) ?? null
    visible: Conmutador.visible_
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-conmutador"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool privado: EstadoEscritorio.privacidad
    property real p: 0                   // aparición
    property real crece: 0               // 0 = en el carrusel · 1 = la elegida ocupa su sitio real
    property real pos: Conmutador.indice < 0 ? 0 : Conmutador.indice
    Behavior on pos { NumberAnimation { duration: Conmutador.medio; easing.type: Easing.OutCubic } }
    readonly property real altoCarta: height * .42
    readonly property real paso: altoCarta * .95

    onVisibleChanged: if (visible) { crece = 0; p = 0; entrar.restart(); teclas.forceActiveFocus(); }
    NumberAnimation { id: entrar; target: c; property: "p"; to: 1; duration: Conmutador.medio; easing.type: Easing.OutCubic }
    Connections {
        target: Conmutador
        function onSaliendoChanged() {
            if (!Conmutador.saliendo) return;
            entrar.stop();
            if (Conmutador.indice >= 0) irse.restart(); else cancelar.restart();
        }
    }
    // Ir: la elegida crece hasta su ventana (que se enfoca al empezar) y todo se desvanece
    SequentialAnimation {
        id: irse
        ScriptAction { script: Conmutador.confirmar() }
        NumberAnimation { target: c; property: "crece"; to: 1; duration: Conmutador.medio; easing.type: Easing.InOutCubic }
        NumberAnimation { target: c; property: "p"; to: 0; duration: Conmutador.corto; easing.type: Easing.OutCubic }
        ScriptAction { script: Conmutador.terminar() }
    }
    SequentialAnimation {
        id: cancelar
        NumberAnimation { target: c; property: "p"; to: 0; duration: Conmutador.corto; easing.type: Easing.InCubic }
        ScriptAction { script: Conmutador.terminar() }
    }

    // Velo (Hyprland desenfoca lo de detrás)
    Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: (EstiloPanel.conBlur ? .45 : .7) * c.p * (1 - c.crece) }

    Item {
        id: teclas
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) Conmutador.cancelar();
            else if (e.key === Qt.Key_Right || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) Conmutador.siguiente();
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) Conmutador.anterior();
            else if (e.key === Qt.Key_Q) Conmutador.cerrarElegida();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) Conmutador.soltar();
            else return;
            e.accepted = true;
        }
        // Si Hyprland no avisa de que soltaste ALT (por si acaso), lo vemos aquí
        Keys.onReleased: (e) => { if (e.key === Qt.Key_Alt) { Conmutador.soltar(); e.accepted = true; } }

        Repeater {
            model: Conmutador.ventanas
            Item {
                id: carta
                required property var modelData
                required property int index
                readonly property real o: index - c.pos
                readonly property real a: Math.abs(o)
                readonly property real s: o < 0 ? -1 : 1
                readonly property bool elegida: index === Conmutador.indice
                readonly property real aspecto: Math.max(.6, Math.min(2.2, modelData.w / Math.max(1, modelData.h)))
                readonly property bool cerca: a < 4.5
                // Dónde está la ventana de verdad (para crecer hasta ahí)
                readonly property real realX: modelData.x - (c.screen?.x ?? 0)
                readonly property real realY: modelData.y - (c.screen?.y ?? 0)
                readonly property real k: elegida ? c.crece : 0

                visible: cerca && opacity > .01
                z: 100 - a
                // En el carrusel
                readonly property real anchoC: c.altoCarta * aspecto
                readonly property real cx: c.width / 2 + s * (c.paso * .78 * Math.min(a, 1) + c.paso * .42 * Math.max(0, a - 1))
                readonly property real cy: c.height * .44
                readonly property real esc: 1 - .3 * Math.min(a, 1) - .06 * Math.max(0, a - 1)
                // Mezcla carrusel → ventana real
                width: anchoC * (1 - k) + modelData.w * k
                height: c.altoCarta * (1 - k) + modelData.h * k
                x: (cx - anchoC / 2) * (1 - k) + realX * k
                y: (cy - c.altoCarta / 2) * (1 - k) + realY * k
                scale: esc * (1 - k) + k
                opacity: (a > 3.5 ? Math.max(0, 4.5 - a) : 1) * c.p * (elegida ? 1 : 1 - c.crece)
                transform: Rotation {
                    origin.x: carta.width / 2; origin.y: carta.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: -carta.s * 48 * Math.min(carta.a, 1) * (1 - carta.k)
                }

                // Sombra de suelo bajo la elegida
                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: 16 }
                    width: parent.width * .8; height: 24; radius: height / 2
                    color: "black"
                    opacity: carta.elegida ? .35 * (1 - c.crece) : 0
                    visible: opacity > 0
                    scale: 1.2
                }
                ClippingRectangle {
                    id: marco
                    anchors.fill: parent
                    radius: 16 * (1 - carta.k) + 12 * carta.k
                    color: EstiloPanel.elevada
                    border { width: carta.elegida ? 2 : 1; color: carta.elegida ? Qt.alpha(Paleta.acento, (1 - carta.k) * .9) : EstiloPanel.borde }
                    ScreencopyView {
                        anchors.fill: parent
                        captureSource: carta.cerca && !c.privado ? (carta.modelData.toplevel?.wayland ?? null) : null
                        live: carta.cerca
                    }
                    // Sin captura (privacidad o aún cargando): el icono en grande
                    IconoApp {
                        anchors.centerIn: parent
                        visible: c.privado || !carta.modelData.toplevel
                        app: ({ clase: carta.modelData.clase, nombre: carta.modelData.clase })
                        lado: Math.min(parent.width, parent.height) * .35
                    }
                    // Las de los lados se apagan
                    Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: .55 * Math.min(carta.a, 1) * (1 - carta.k) }
                }
                // Icono de la app sobre la esquina
                IconoApp {
                    x: -lado * .25; y: parent.height - lado * .75
                    app: ({ clase: carta.modelData.clase, nombre: carta.modelData.clase })
                    lado: 56
                    opacity: 1 - carta.k
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Conmutador.ir(carta.index); Conmutador.soltar(); }
                }
            }
        }

        // Debajo: qué ventana es
        Column {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: c.height * .44 + c.altoCarta / 2 + 48 }
            spacing: 8
            opacity: c.p * (1 - c.crece)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, c.width * .6)
                elide: Text.ElideRight
                text: c.privado ? nombreDe(Conmutador.actual) : (Conmutador.actual?.titulo || nombreDe(Conmutador.actual))
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 20; bold: true }
                function nombreDe(v) { return DesktopEntries.heuristicLookup(v?.clase ?? "")?.name ?? v?.clase ?? ""; }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Rectangle {
                    width: etiquetaEsp.implicitWidth + 24; height: 28; radius: height / 2
                    color: EstiloPanel.relleno
                    border { width: 1; color: EstiloPanel.borde }
                    Text { id: etiquetaEsp; anchors.centerIn: parent; text: "Espacio " + (Conmutador.actual?.ws ?? ""); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Conmutador.indice + 1) + " de " + Conmutador.ventanas.length + "  ·  Q cierra  ·  Esc cancela"
                    color: EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 12 }
                }
            }
        }
    }
}
