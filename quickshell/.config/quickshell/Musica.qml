// Música: lo que suena en cualquier reproductor MPRIS (Spotify, Firefox, mpv…).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

RowLayout {
    id: musica
    spacing: 16

    // El que esté sonando; si ninguno, el primero que haya
    readonly property var jugador: {
        const lista = Mpris.players.values;
        return lista.find(p => p.isPlaying) ?? lista[0] ?? null;
    }

    // La posición no se actualiza sola: se le avisa cada segundo mientras suena
    Timer {
        interval: 1000; repeat: true
        running: musica.visible && musica.jugador !== null && musica.jugador.isPlaying
        onTriggered: musica.jugador.positionChanged()
    }

    function mmss(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // Carátula (o una nota si no hay)
    ClippingRectangle {
        Layout.preferredWidth: 84
        Layout.preferredHeight: 84
        radius: 12
        color: Paleta.seleccion
        Text {
            anchors.centerIn: parent
            visible: caratula.status !== Image.Ready
            text: ""; color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 30 }
        }
        Image {
            id: caratula
            anchors.fill: parent
            source: musica.jugador?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: musica.jugador?.trackTitle || "Nada sonando"
            color: Paleta.texto
            elide: Text.ElideRight
            font { family: Paleta.fuente; pixelSize: 15; bold: true }
        }
        Text {
            Layout.fillWidth: true
            text: musica.jugador ? (musica.jugador.trackArtist || musica.jugador.identity) : "pon algo en Spotify o Firefox"
            color: Paleta.gris
            elide: Text.ElideRight
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }

        // Controles: anterior · reproducir/pausa · siguiente
        RowLayout {
            spacing: 22
            opacity: musica.jugador ? 1 : 0.35
            Repeater {
                model: [
                    { icono: "", accion: () => musica.jugador?.previous() },
                    { icono: musica.jugador?.isPlaying ? "" : "", accion: () => musica.jugador?.togglePlaying() },
                    { icono: "", accion: () => musica.jugador?.next() }
                ]
                Text {
                    text: modelData.icono
                    color: zona.containsMouse ? Paleta.naranja : Paleta.texto
                    font { family: Paleta.fuente; pixelSize: index === 1 ? 20 : 15 }
                    MouseArea {
                        id: zona
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true
                        onClicked: modelData.accion()
                    }
                }
            }
        }

        // Barra de progreso
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: (musica.jugador?.lengthSupported ?? false) && musica.jugador.length > 0
            Text {
                text: musica.mmss(musica.jugador?.position ?? 0)
                color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: 2
                color: Qt.alpha(Paleta.texto, 0.12)
                Rectangle {
                    height: parent.height; radius: 2
                    color: Paleta.naranja
                    width: parent.width * Math.min(1, (musica.jugador?.position ?? 0) / Math.max(1, musica.jugador?.length ?? 1))
                    Behavior on width { NumberAnimation { duration: 900 } }
                }
            }
            Text {
                text: musica.mmss(musica.jugador?.length ?? 0)
                color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 }
            }
        }
    }
}
