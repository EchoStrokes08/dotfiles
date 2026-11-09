// Tiempo de pantalla de hoy (lo mide ~/.config/hypr/scripts/tiempo-pantalla.py).
// Muestra el total, las 4 apps más usadas con una barra proporcional y, debajo, los últimos 7 días
// (pasa el ratón por una barra: total y app principal de ese día). Límites por app: limites.json.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: tiempo
    spacing: 7

    property var apps: []          // [{ clase, seg }] ordenado de más a menos
    property real total: 0

    function hoy() {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function formato(seg) {
        const m = Math.floor(seg / 60), h = Math.floor(m / 60);
        return h > 0 ? `${h} h ${String(m % 60).padStart(2, "0")}` : `${m} min`;
    }
    function nombre(clase) {
        const e = DesktopEntries.heuristicLookup(clase);
        if (e && e.name) return e.name;
        const s = clase.split(".").pop();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    FileView {
        id: archivo
        path: Quickshell.env("HOME") + "/.local/state/tiempo-pantalla/" + tiempo.hoy() + ".json"
        onLoaded: {
            let datos = {};
            try { datos = JSON.parse(text()); } catch (e) {}
            const lista = Object.keys(datos).map(k => ({ clase: k, seg: datos[k] }))
                                .sort((a, b) => b.seg - a.seg);
            tiempo.total = lista.reduce((a, x) => a + x.seg, 0);
            tiempo.apps = lista.slice(0, 4);
        }
    }
    // El script guarda cada 30 s: releer mientras el panel esté a la vista
    Timer {
        interval: 30000; repeat: true; triggeredOnStart: true
        running: tiempo.visible
        onTriggered: { archivo.reload(); semana.running = true; }
    }

    // Últimos 7 días (tiempo-pantalla.py --semana)
    property var dias: []           // [{ dia: "2026-11-09", total: s, top: "Firefox" }]
    property int elegido: -1        // día bajo el ratón
    Process {
        id: semana
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/hypr/scripts/tiempo-pantalla.py", "--semana"]
        stdout: StdioCollector { onStreamFinished: { try { tiempo.dias = JSON.parse(this.text); } catch (e) { } } }
    }

    Text {
        text: "HOY EN PANTALLA"
        color: Paleta.gris
        font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1 }
    }
    Text {
        text: tiempo.total > 0 ? tiempo.formato(tiempo.total) : "—"
        color: Paleta.texto
        font { family: Paleta.fuente; pixelSize: 22; bold: true }
    }

    Repeater {
        model: tiempo.apps
        ColumnLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: tiempo.nombre(modelData.clase)
                    color: Paleta.texto
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
                Text {
                    text: tiempo.formato(modelData.seg)
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 10 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: 2
                color: Qt.alpha(Paleta.texto, 0.08)
                Rectangle {
                    height: parent.height; radius: 2
                    width: parent.width * modelData.seg / Math.max(1, tiempo.apps[0]?.seg ?? 1)
                    color: [Paleta.naranja, Paleta.azul, Paleta.verde, Paleta.morado][index % 4]
                }
            }
        }
    }

    // ── Semana ──
    Item { Layout.preferredHeight: 4 }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "ÚLTIMOS 7 DÍAS"
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1 }
        }
        Item { Layout.fillWidth: true }
        Text {   // detalle del día bajo el ratón, o la media
            readonly property var d: tiempo.dias[tiempo.elegido]
            readonly property real media: tiempo.dias.length ? tiempo.dias.reduce((a, x) => a + x.total, 0) / tiempo.dias.length : 0
            text: d ? `${tiempo.formato(d.total)}${d.top ? " · " + d.top : ""}` : `media ${tiempo.formato(media)}`
            color: d ? Paleta.texto : Paleta.gris
            font { family: Paleta.fuente; pixelSize: 10 }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        spacing: 6
        readonly property real maximo: Math.max(3600, ...tiempo.dias.map(d => d.total))
        Repeater {
            model: tiempo.dias
            ColumnLayout {
                required property var modelData
                required property int index
                readonly property bool esHoy: index === tiempo.dias.length - 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: Math.min(parent.width, 18); radius: 3
                        height: Math.max(2, parent.height * modelData.total / parent.parent.parent.maximo)
                        color: esHoy ? Paleta.naranja : tiempo.elegido === index ? Paleta.azul : Qt.alpha(Paleta.azul, 0.45)
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: tiempo.elegido = index
                        onExited: if (tiempo.elegido === index) tiempo.elegido = -1
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: ["D", "L", "M", "X", "J", "V", "S"][new Date(modelData.dia + "T12:00").getDay()]
                    color: esHoy ? Paleta.naranja : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 9; bold: esHoy }
                }
            }
        }
    }
}
