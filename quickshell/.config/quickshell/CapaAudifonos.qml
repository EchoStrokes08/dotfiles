// CapaAudifonos: al conectar los REDMI Buds cae desde la isla una tarjeta como la de los AirPods en el
// móvil: los dos auriculares y el estuche dibujados, cada uno con un anillo que se llena hasta su batería
// (ámbar con rayo si carga, rojo si está baja) y el estado de Buds Manager. Se va sola a los 6 s
// (se queda con el ratón encima); clic = abrir Buds Manager. Los datos salen de `buds waybar --parts`,
// lo mismo que la cápsula de la barra (BarraDerecha.qml). Los dibujos son los de Buds Manager.
//   qs ipc call audifonos tarjeta    (con los Buds conectados: la lectura real, si Buds Manager la tiene;
//                                     si no están conectados, de muestra) · qs ipc call audifonos muestra
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Wayland

PanelWindow {
    id: c

    // ── qué Buds y cuándo ─────────────────────────────────────────────────────────────────────────
    readonly property string macPreferida: (Quickshell.env("REDMI_BUDS_MAC") ?? "").toUpperCase()
    readonly property string mac: (Bluetooth.defaultAdapter?.devices?.values ?? [])
        .find(d => d.connected && (macPreferida ? d.address.toUpperCase() === macPreferida
                                                : /redmi buds|xiaomi buds/i.test(d.deviceName + " " + d.name)))?.address ?? ""
    property bool arrancado: false            // lo que ya estaba conectado al arrancar no se anuncia
    Timer { interval: 4000; running: true; onTriggered: c.arrancado = true }
    onMacChanged: if (mac && arrancado) { intentos = 0; leer(); }

    IpcHandler {
        target: "audifonos"
        function tarjeta(): void { if (c.mac) { c.intentos = 0; c.leer(); } else muestra(); }
        function muestra(): void {
            c.datos = { nombre: "REDMI Buds", estado: "Conectados", piezas: [
                { lado: "izq", pct: 100, carga: false }, { lado: "der", pct: 85, carga: false }, { lado: "estuche", pct: 62, carga: true }] };
            c.mostrar();
        }
    }

    // `buds waybar --parts`: hasta que traiga porcentajes (justo al conectar aún no los sabe), cada 1,5 s
    property int intentos: 0
    function leer() { if (!lector.running) { lector.command = [Quickshell.env("HOME") + "/.local/bin/buds", "--mac", mac, "waybar", "--parts"]; lector.running = true; } }
    Process {
        id: lector
        stdout: StdioCollector {
            onStreamFinished: {
                let p = null;
                try { p = JSON.parse(text); } catch (e) { }
                const piezas = Array.isArray(p) ? p.filter(x => typeof x.percentage === "number").map(x => ({
                    lado: x.class.includes("left") ? "izq" : x.class.includes("right") ? "der" : "estuche",
                    pct: x.percentage, carga: x.class.includes("charging"),
                    baja: x.class.includes("low") || x.class.includes("critical") })) : [];
                if (piezas.length === 0) {
                    if (++c.intentos < 10) reintento.restart();
                    return;
                }
                const lineas = String(p[0].tooltip ?? "").split("\n");
                c.datos = { nombre: (lineas[0] ?? "").split(" — ")[0] || "REDMI Buds", estado: (lineas[0] ?? "").split(" — ")[1] ?? "Conectados",
                            piezas: ["izq", "der", "estuche"].map(l => piezas.find(x => x.lado === l)).filter(Boolean) };
                c.mostrar();
            }
        }
    }
    Timer { id: reintento; interval: 1500; onTriggered: c.leer() }

    // ── mostrar ───────────────────────────────────────────────────────────────────────────────────
    property var datos: ({ nombre: "", estado: "", piezas: [] })
    property bool abierta: false
    property real p: 0                        // 0 → 1 al caer, de vuelta al irse
    property int numero: 0                    // cambia en cada aparición: los anillos vuelven a llenarse
    function mostrar() {
        screen = Quickshell.screens.find(s => s.name === Isla.enfocado) ?? Quickshell.screens[0];
        numero++;
        abierta = true;
        visible = true;
        fin.restart();
    }
    Timer { id: fin; interval: 6000; onTriggered: if (zona.containsMouse) restart(); else c.abierta = false }
    Behavior on p { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.lento : 0; easing.type: c.abierta ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.2 } }
    Binding { target: c; property: "p"; value: c.abierta ? 1 : 0 }
    onPChanged: if (p === 0 && !abierta) visible = false

    visible: false
    color: "transparent"
    anchors.top: true
    implicitWidth: 440
    implicitHeight: 276
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-audifonos"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: tarjeta }

    readonly property string iconos: Quickshell.env("HOME") + "/proyectos/redmi-buds/data/icons/"
    readonly property string respaldo: Quickshell.env("HOME") + "/.local/state/redmi-buds/waybar/"

    Rectangle {
        id: tarjeta
        width: parent.width - 16; height: 216
        anchors.horizontalCenter: parent.horizontalCenter
        // cae desde la isla: empieza estrecha y arriba, crece hacia abajo
        y: 46 + (1 - c.p) * -40
        opacity: Math.min(1, c.p * 1.6)
        scale: .7 + .3 * c.p
        transformOrigin: Item.Top
        radius: EstiloPanel.rPanel
        color: EstiloPanel.superficie
        border { width: 1; color: EstiloPanel.borde }

        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/buds-manager"]); c.abierta = false; }
        }

        Column {
            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: c.datos.nombre
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 16; bold: true }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, tarjeta.width - 48); elide: Text.ElideRight
                text: c.datos.estado
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }

        Row {
            anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
            spacing: 24
            Repeater {
                model: c.datos.piezas
                Item {
                    id: pieza
                    required property var modelData
                    required property int index
                    width: 112; height: 128
                    readonly property color tono: modelData.carga ? Paleta.aviso : modelData.baja ? Paleta.peligro : Paleta.exito
                    readonly property bool estuche: modelData.lado === "estuche"

                    // el anillo se llena con un pequeño retraso entre piezas
                    property real lleno: 0
                    Connections { target: c; function onNumeroChanged() { pieza.lleno = 0; llenar.restart(); } }
                    Component.onCompleted: llenar.restart()
                    SequentialAnimation {
                        id: llenar
                        PauseAnimation { duration: EstiloPanel.movimiento ? 250 + pieza.index * 90 : 0 }
                        NumberAnimation { target: pieza; property: "lleno"; to: pieza.modelData.pct / 100; duration: EstiloPanel.movimiento ? 900 : 0; easing.type: Easing.OutCubic }
                    }

                    Item {
                        id: aro
                        width: 92; height: 92
                        anchors.horizontalCenter: parent.horizontalCenter
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                fillColor: "transparent"; strokeColor: Qt.alpha(Paleta.texto, .08); strokeWidth: 4
                                PathAngleArc { centerX: 46; centerY: 46; radiusX: 43; radiusY: 43; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                fillColor: "transparent"; strokeColor: pieza.tono; strokeWidth: 4; capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: 46; centerY: 46; radiusX: 43; radiusY: 43; startAngle: -90; sweepAngle: 360 * pieza.lleno }
                            }
                        }
                        Image {
                            id: dibujo
                            anchors.centerIn: parent
                            width: 64; height: 64
                            source: "file://" + c.iconos + (pieza.estuche ? "case.svg" : "earbud.svg")
                            sourceSize: Qt.size(128, 128)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mirror: pieza.modelData.lado === "der"
                            visible: status === Image.Ready
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 44; height: 44
                            visible: dibujo.status === Image.Error
                            source: dibujo.status === Image.Error ? "file://" + c.respaldo + ({ izq: "left", der: "right", estuche: "case" })[pieza.modelData.lado] + ".png" : ""
                        }
                    }
                    Row {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pieza.modelData.carga
                            text: String.fromCodePoint(0xF140B)
                            color: Paleta.aviso
                            font { family: Paleta.mono; pixelSize: 12 }
                        }
                        Text {
                            text: Math.round(pieza.lleno * 100) + " %"
                            color: Paleta.texto
                            font { family: Paleta.fuente; pixelSize: 14; weight: Font.DemiBold; features: { "tnum": 1 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ({ izq: "Izq.", der: "Der.", estuche: "Estuche" })[pieza.modelData.lado]
                            color: EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}
