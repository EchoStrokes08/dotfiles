// PostalMomento: una tarjeta de la máquina del tiempo (CapaMaquina.qml). Tres caras:
//   ahora     tu pantalla de este momento (la captura de Maquina.captura)
//   captura   la captura cifrada de Brújula más cercana a la mitad del momento
//   postal    sin captura: la app en grande, sus títulos, el contexto y los archivos que abriste
// Se dibuja al tamaño de la tarjeta frontal; la pila la escala entera.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: pm
    property var m: ({})
    property real oscuro: 0               // las del fondo se apagan
    property bool discreto: true          // títulos difuminados (Maquina.verTitulos o el ratón encima los muestran)
    readonly property color tono: Maquina.color(m.app ?? -1)
    function hora(t) { return t ? Qt.formatTime(new Date(t * 1000), "H:mm") : ""; }
    function duracion(s) {
        const h = Math.floor(s / 3600), mi = Math.round(s % 3600 / 60);
        return h > 0 ? (mi > 0 ? `${h} h ${mi} min` : `${h} h`) : `${Math.max(1, mi)} min`;
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 24
        color: EstiloPanel.elevada
        border { width: 1; color: Qt.alpha(Paleta.texto, .12) }

        // ── Ahora: tu pantalla ──
        Image {
            anchors.fill: parent
            visible: pm.m.ahora === true
            source: pm.m.ahora && Maquina.captura ? "file://" + Maquina.captura + "?n=" + Maquina.numero : ""
            cache: false
            fillMode: Image.PreserveAspectCrop
        }

        // ── Captura cifrada de Brújula ──
        Image {
            id: foto
            anchors.fill: parent
            visible: !pm.m.ahora && !!pm.m.captura
            source: !pm.m.ahora && pm.m.captura ? "file://" + pm.m.captura : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        // ── Postal ──
        Item {
            anchors.fill: parent
            visible: !pm.m.ahora && !pm.m.captura
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.tint(EstiloPanel.elevada, Qt.alpha(pm.tono, .16)) }
                    GradientStop { position: 1; color: EstiloPanel.superficie }
                }
            }
            Bruma { x: -parent.width * .2; y: -parent.height * .45; width: parent.width * .9; height: parent.height; tono: pm.tono; fuerza: .3 }
            // El icono, enorme y tenue, asomando por la esquina
            IconoApp {
                app: pm.m
                lado: parent.height * .95
                x: parent.width - lado * .62; y: parent.height - lado * .7
                rotation: -10
                opacity: .08
            }
            Column {
                anchors { left: parent.left; top: parent.top; right: parent.right; margins: 40 }
                spacing: 24
                Row {
                    spacing: 24
                    IconoApp { app: pm.m; lado: 88 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Text { text: pm.m.nombre ?? ""; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } }
                        Text { text: `${pm.hora(pm.m.inicio)} – ${pm.hora(pm.m.fin)} · ${pm.duracion(pm.m.activo ?? 0)}`; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } }
                    }
                }
                Column {
                    width: parent.width * .82
                    spacing: 12
                    layer.enabled: pm.discreto && !pm.m.privado
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64 }
                    Repeater {
                        model: pm.m.privado ? ["Ventana privada"] : (pm.m.titulos ?? []).slice().reverse()
                        Row {
                            required property string modelData
                            required property int index
                            spacing: 12
                            Glifo { alto: 26; text: String.fromCodePoint(pm.m.privado ? 0xF033E : 0xF05AF); color: index === 0 ? pm.tono : EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 16 } }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: pm.width * .7
                                elide: Text.ElideRight
                                text: modelData
                                color: index === 0 ? Paleta.texto : EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: index === 0 ? 20 : 16 }
                            }
                        }
                    }
                }
            }
            Flow {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 40 }
                spacing: 8
                Repeater {
                    model: (pm.m.contexto ? [{ c: true, n: pm.m.contexto }] : []).concat((pm.m.archivos ?? []).map(a => ({ n: a.nombre })))
                    Rectangle {
                        required property var modelData
                        width: chip.implicitWidth + 24; height: 32; radius: height / 2
                        color: modelData.c ? Qt.alpha(pm.tono, .18) : Qt.alpha(Paleta.texto, .06)
                        border { width: 1; color: modelData.c ? Qt.alpha(pm.tono, .4) : EstiloPanel.borde }
                        Row {
                            id: chip
                            anchors.centerIn: parent
                            spacing: 8
                            Glifo { alto: 32; text: String.fromCodePoint(modelData.c ? 0xF0493 : 0xF0214); color: modelData.c ? pm.tono : EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 13 } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.n; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13 } }
                        }
                    }
                }
            }
        }

        // Sobre la captura (y sobre «ahora»): de qué momento es
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 120
            visible: !!pm.m.captura && !pm.m.ahora
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.alpha(Paleta.fondo, .85) }
            }
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 24 }
                spacing: 12
                IconoApp { app: pm.m; lado: 40 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: pm.m.nombre ?? ""; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
                    Text { text: `${pm.hora(pm.m.inicio)} – ${pm.hora(pm.m.fin)}`; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                }
            }
        }

        // Las del fondo se pierden en la oscuridad
        Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: pm.oscuro }
    }
}
