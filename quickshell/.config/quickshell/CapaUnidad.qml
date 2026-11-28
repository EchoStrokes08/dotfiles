// CapaUnidad: al montarse un USB o un disco externo (udiskie lo monta solo en /run/media/<usuario>/…)
// cae desde la isla una tarjeta con su nombre, un anillo con lo ocupado, cuánto queda libre y dos
// botones: Abrir (Thunar en esa carpeta) y Expulsar (udiskie-umount: desmonta y lo apaga). Al expulsar
// la isla dice «Ya puedes retirarlo». Se va sola a los 7 s (se queda con el ratón encima).
// Lo ve `findmnt --poll` (el kernel avisa de cada montaje: nada de mirar cada pocos segundos).
// Sustituye a las notificaciones de montar/desmontar de udiskie (udiskie/config.yml).
//   qs ipc call unidad muestra     (tarjeta de ejemplo)
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: c
    readonly property string raiz: "/run/media/" + (Quickshell.env("USER") || "")

    // ── montajes ──────────────────────────────────────────────────────────────────────────────────
    // -r escapa los espacios como \x20; ACTION es mount / umount / remount / move
    Process {
        running: true
        command: ["findmnt", "--poll=mount,umount", "-rn", "-o", "ACTION,TARGET,SOURCE"]
        stdout: SplitParser {
            onRead: (l) => {
                const [accion, destino, origen] = l.trim().split(/\s+/).map(x => x.replace(/\\x20/g, " "));
                if (!destino || !destino.startsWith(c.raiz + "/")) return;
                if (accion === "mount") c.leer(destino, origen ?? "");
                else if (accion === "umount" && destino === c.datos.ruta) {
                    c.abierta = false;
                    Isla.mostrar(String.fromCodePoint(0xF01EA), -1, `«${c.datos.nombre}» expulsado · ya puedes retirarlo`, false, 2600);
                }
            }
        }
    }
    // tamaño y nombre: df para el espacio; lsblk para la etiqueta y si es USB
    function leer(ruta, origen) {
        info.ruta = ruta;
        info.command = ["sh", "-c", 'df -B1 --output=size,used,avail "$1" | tail -1; lsblk -no LABEL,TRAN,RM "$2" 2>/dev/null | head -1; lsblk -no TRAN "/dev/$(lsblk -no PKNAME "$2" 2>/dev/null | head -1)" 2>/dev/null | head -1',
                        "_", ruta, origen];
        info.running = true;
    }
    Process {
        id: info
        property string ruta: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                const [total, usado, libre] = (l[0] ?? "").trim().split(/\s+/).map(Number);
                const trans = ((l[2] ?? "").trim() || (l[1] ?? "").trim().split(/\s+/).slice(-2)[0] || "").toLowerCase();
                c.datos = { ruta: info.ruta, nombre: info.ruta.split("/").pop(), total: total || 0, usado: usado || 0, libre: libre || 0,
                            usb: trans === "usb" };
                c.mostrar();
            }
        }
    }

    IpcHandler {
        target: "unidad"
        function muestra(): void {
            c.datos = { ruta: "", nombre: "KINGSTON", total: 32e9, usado: 19.4e9, libre: 12.6e9, usb: true };
            c.mostrar();
        }
    }

    function tam(b) {
        return b >= 1e12 ? (b / 1e12).toFixed(1).replace(".", ",") + " TB"
             : b >= 1e9 ? (b / 1e9).toFixed(b >= 1e11 ? 0 : 1).replace(".", ",") + " GB"
             : Math.round(b / 1e6) + " MB";
    }
    function expulsar() {
        if (!datos.ruta) { abierta = false; return; }
        expulsando = true;
        expulsion.command = ["udiskie-umount", "--detach", datos.ruta];
        expulsion.running = true;
    }
    property bool expulsando: false
    Process {
        id: expulsion
        onExited: (codigo) => {
            c.expulsando = false;
            if (codigo !== 0) {
                Isla.mostrar(String.fromCodePoint(0xF0026), -1, `No se pudo expulsar «${c.datos.nombre}»: algo lo está usando`, false, 3200);
                fin.restart();
            }   // si sale bien, findmnt ve el umount y la isla lo dice
        }
    }

    // ── mostrar ───────────────────────────────────────────────────────────────────────────────────
    property var datos: ({ ruta: "", nombre: "", total: 0, usado: 0, libre: 0, usb: true })
    readonly property real ocupado: datos.total > 0 ? datos.usado / datos.total : 0
    property bool abierta: false
    property real p: 0
    property int numero: 0
    function mostrar() {
        screen = Quickshell.screens.find(s => s.name === Isla.enfocado) ?? Quickshell.screens[0];
        numero++;
        abierta = true;
        visible = true;
        fin.restart();
    }
    Timer { id: fin; interval: 7000; onTriggered: if (zona.containsMouse || c.expulsando) restart(); else c.abierta = false }
    Behavior on p { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.lento : 0; easing.type: c.abierta ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.2 } }
    Binding { target: c; property: "p"; value: c.abierta ? 1 : 0 }
    onPChanged: if (p === 0 && !abierta) visible = false

    visible: false
    color: "transparent"
    anchors.top: true
    implicitWidth: 440
    implicitHeight: 196
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-unidad"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: tarjeta }

    Rectangle {
        id: tarjeta
        width: parent.width - 16; height: 136
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46 + (1 - c.p) * -40
        opacity: Math.min(1, c.p * 1.6)
        scale: .7 + .3 * c.p
        transformOrigin: Item.Top
        radius: EstiloPanel.rPanel
        color: EstiloPanel.superficie
        border { width: 1; color: EstiloPanel.borde }

        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true }

        // el anillo: lo ocupado, llenándose
        Item {
            id: aro
            width: 88; height: 88
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            property real lleno: 0
            Connections { target: c; function onNumeroChanged() { aro.lleno = 0; llenar.restart(); } }
            SequentialAnimation {
                id: llenar
                PauseAnimation { duration: EstiloPanel.movimiento ? 250 : 0 }
                NumberAnimation { target: aro; property: "lleno"; to: c.ocupado; duration: EstiloPanel.movimiento ? 900 : 0; easing.type: Easing.OutCubic }
            }
            readonly property color tono: c.ocupado > .9 ? Paleta.peligro : c.ocupado > .75 ? Paleta.aviso : Paleta.acento
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.alpha(Paleta.texto, .08); strokeWidth: 4
                    PathAngleArc { centerX: 44; centerY: 44; radiusX: 41; radiusY: 41; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    fillColor: "transparent"; strokeColor: aro.tono; strokeWidth: 4; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 44; centerY: 44; radiusX: 41; radiusY: 41; startAngle: -90; sweepAngle: 360 * aro.lleno }
                }
            }
            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(c.datos.usb ? 0xF129E : 0xF02CA)
                color: Paleta.texto
                font { family: Paleta.mono; pixelSize: 36 }
            }
        }

        Column {
            anchors { left: aro.right; leftMargin: 24; right: parent.right; rightMargin: 24; top: parent.top; topMargin: 24 }
            spacing: 4
            Text {
                width: parent.width; elide: Text.ElideRight
                text: c.datos.nombre
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 16; bold: true }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: `${c.tam(c.datos.libre)} libres de ${c.tam(c.datos.total)}`
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
        Row {
            anchors { left: aro.right; leftMargin: 24; bottom: parent.bottom; bottomMargin: 24 }
            spacing: 8
            Boton {
                glifo: 0xF0770; texto: "Abrir"; principal: true
                onPulsado: { if (c.datos.ruta) Quickshell.execDetached(["thunar", c.datos.ruta]); c.abierta = false; }
            }
            Boton {
                glifo: 0xF01EA; texto: c.expulsando ? "Expulsando…" : "Expulsar"
                onPulsado: if (!c.expulsando) c.expulsar()
            }
        }
    }

    component Boton: Rectangle {
        id: b
        property int glifo: 0
        property string texto: ""
        property bool principal: false
        signal pulsado()
        width: filaB.implicitWidth + 28; height: 36
        radius: height / 2
        color: principal ? Qt.alpha(Paleta.acento, zonaB.containsMouse ? .3 : .2)
                         : zonaB.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
        border { width: 1; color: principal ? Qt.alpha(Paleta.acento, .45) : EstiloPanel.borde }
        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
        Row {
            id: filaB
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String.fromCodePoint(b.glifo)
                color: b.principal ? Paleta.acento : Paleta.texto
                font { family: Paleta.mono; pixelSize: 14 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: b.texto
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
            }
        }
        MouseArea { id: zonaB; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.pulsado() }
    }
}
