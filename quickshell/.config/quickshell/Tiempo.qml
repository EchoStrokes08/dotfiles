// Tiempo de pantalla de hoy (lo mide ~/.config/hypr/scripts/tiempo-pantalla.py).
// Muestra el total, las 4 apps más usadas con una barra proporcional y, debajo, los últimos 7 días
// (pasa el ratón por una barra: total y app principal de ese día). Límites por app: limites.json.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: tiempo
    spacing: 8

    property var apps: []          // [{ clase, seg }] ordenado de más a menos
    property real total: 0
    property bool compacto: false

    function hoy() {
        const d = new Date();
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function formato(seg) {
        const m = Math.floor(seg / 60), h = Math.floor(m / 60);
        return h > 0 ? `${h} h${m % 60 ? " " + (m % 60) + " min" : ""}` : `${m} min`;
    }
    function fechaDia(dia) {
        return new Date(dia + "T12:00").toLocaleDateString(Qt.locale("es_CO"), "ddd d");
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
    property int apuntado: -1
    property int enfocado: -1
    readonly property int elegido: apuntado >= 0 ? apuntado : enfocado
    readonly property var diaElegido: dias[elegido]
    readonly property real media: dias.length ? dias.reduce((a, d) => a + d.total, 0) / dias.length : 0
    // Dos intervalos en minutos con marcas de 30 min, incluso en semanas con poco uso.
    readonly property int intervalo: Math.max(1800, Math.ceil(dias.reduce((a, d) => Math.max(a, d.total), 0) / 3600) * 1800)
    Process {
        id: semana
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/hypr/scripts/tiempo-pantalla.py", "--semana"]
        stdout: StdioCollector { onStreamFinished: { try { tiempo.dias = JSON.parse(this.text); } catch (e) { } } }
    }

    Text {
        text: "HOY EN PANTALLA"
        color: Paleta.gris
        font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1 }
    }
    Text {
        text: tiempo.total > 0 ? tiempo.formato(tiempo.total) : "Sin actividad registrada"
        color: Paleta.texto
        font { family: Paleta.fuente; pixelSize: tiempo.total > 0 ? 20 : 13; bold: true }
    }

    Repeater {
        model: tiempo.compacto ? [] : tiempo.apps
        ColumnLayout {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 2
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
                    text: tiempo.formato(modelData.seg) + " · " + Math.round(modelData.seg * 100 / Math.max(1, tiempo.total)) + " %"
                    color: Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: height / 2
                color: EstiloPanel.rellenoActivo
                Rectangle {
                    height: parent.height; radius: height / 2
                    width: parent.width * modelData.seg / Math.max(1, tiempo.total)
                    color: Paleta.serie[index % 4]
                }
            }
        }
    }

    // Una escala compartida y fondo de foco para leer las barras con ratón o teclado.
    Rectangle {
        visible: !tiempo.compacto && tiempo.dias.length > 0
        Layout.fillWidth: true
        implicitHeight: semanaVista.implicitHeight + 2 * EstiloPanel.e3
        radius: EstiloPanel.rControl
        color: EstiloPanel.relleno
        border { width: 1; color: EstiloPanel.bordeFuerte }

        ColumnLayout {
            id: semanaVista
            anchors { left: parent.left; top: parent.top; right: parent.right; margins: 12 }
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Últimos 7 días"
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 14; weight: Font.DemiBold }
            }

            Item {
                id: grafica
                Layout.fillWidth: true
                implicitHeight: 98
                readonly property int altoEje: 68
                readonly property int anchoEje: 60

                Repeater {
                    model: [2, 1, 0]
                    Item {
                        required property int modelData
                        width: grafica.width
                        y: (2 - modelData) * grafica.altoEje / 2 + EstiloPanel.e2

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData ? tiempo.formato(modelData * tiempo.intervalo) : "0"
                            color: EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 11 }
                        }
                        Rectangle {
                            x: grafica.anchoEje
                            width: Math.max(0, parent.width - x)
                            height: 1
                            color: modelData ? EstiloPanel.borde : EstiloPanel.bordeFuerte
                        }
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: grafica.anchoEje }
                    spacing: 4
                    Repeater {
                        model: tiempo.dias
                        Item {
                            id: dia
                            required property var modelData
                            required property int index
                            readonly property bool esHoy: modelData.dia === tiempo.hoy()
                            readonly property bool elegido: index === tiempo.elegido
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            activeFocusOnTab: tiempo.visible
                            Accessible.role: Accessible.StaticText
                            Accessible.name: tiempo.fechaDia(modelData.dia) + ", " + tiempo.formato(modelData.total)
                                + (modelData.top ? ", " + modelData.top : "")
                            onActiveFocusChanged: {
                                if (activeFocus) tiempo.enfocado = index;
                                else if (tiempo.enfocado === index) tiempo.enfocado = -1;
                            }
                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered) tiempo.apuntado = dia.index;
                                    else if (tiempo.apuntado === dia.index) tiempo.apuntado = -1;
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: EstiloPanel.rChip
                                color: elegido ? EstiloPanel.rellenoActivo : "transparent"
                                border { width: dia.activeFocus ? 1 : 0; color: EstiloPanel.bordeSeleccion }
                            }
                            Rectangle {
                                y: EstiloPanel.e2 + grafica.altoEje - height
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(parent.width * .58, 36)
                                height: grafica.altoEje * modelData.total / (2 * tiempo.intervalo)
                                radius: EstiloPanel.rPunto
                                color: esHoy ? Paleta.acento : elegido ? Paleta.acento2 : Qt.alpha(Paleta.acento2, .58)
                            }
                            Text {
                                anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter }
                                text: esHoy && dia.width >= 25 ? "Hoy" : ["D", "L", "M", "X", "J", "V", "S"][new Date(modelData.dia + "T12:00").getDay()]
                                color: esHoy ? Paleta.acento : elegido ? Paleta.texto : EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 11; bold: esHoy || elegido }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: tiempo.diaElegido
                    ? tiempo.fechaDia(tiempo.diaElegido.dia) + " · " + tiempo.formato(tiempo.diaElegido.total)
                        + (tiempo.diaElegido.top ? " · " + tiempo.diaElegido.top : "")
                    : "Promedio diario · " + tiempo.formato(tiempo.media)
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: tiempo.diaElegido ? Paleta.texto : EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
    }
}
