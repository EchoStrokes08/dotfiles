// Tiempo de pantalla de hoy (lo mide ~/.config/hypr/scripts/tiempo-pantalla.py).
// Muestra el total y las 4 apps más usadas, con una barra proporcional.
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
        onTriggered: archivo.reload()
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
}
