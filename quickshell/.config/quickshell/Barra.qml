// Barra superior hecha en Quickshell (sustituirá a waybar módulo a módulo).
// Izquierda: workspaces + ventana activa · centro: reloj · derecha: BarraDerecha.qml
// Una barra por pantalla: shell.qml la crea con Variants { model: Quickshell.screens }.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: barra
    signal relojPulsado()               // shell.qml lo conecta con el dashboard

    // Barra transparente con tres «islas» de cristal (IslaBarra.qml): izquierda, reloj y derecha
    anchors { top: true; left: true; right: true }   // 3 bordes → reserva su alto (como waybar)
    implicitHeight: 42
    color: "transparent"
    WlrLayershell.namespace: "quickshell-barra"

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real margen: 8      // de las islas al borde de la pantalla

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    function refrescar(que) { derecha.refrescar(que); }

    // ── Derecha: bandeja, Buds, volumen, red… ───────────────────────────
    IslaBarra {
        id: islaDerecha
        anchors { right: parent.right; rightMargin: barra.margen; verticalCenter: parent.verticalCenter }
        implicitWidth: derecha.implicitWidth + 16
        BarraDerecha {
            id: derecha
            ventana: barra
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        }
    }

    // ── Izquierda: workspaces y ventana activa ──────────────────────────
    RowLayout {
        id: izquierda
        anchors { left: parent.left; leftMargin: barra.margen; verticalCenter: parent.verticalCenter }
        spacing: 8

        IslaBarra {
            id: islaEspacios
            implicitWidth: filaEspacios.implicitWidth + 12
            RowLayout {
                id: filaEspacios
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 6

                BarraEspacios { id: espaciosBarra; monitor: barra.monitor }

                // Perfil del escritorio (o reunión / privacidad)
                Rectangle {
                    id: perfil
                    implicitWidth: filaPerfil.implicitWidth + 18
                    implicitHeight: 24
                    radius: 12
                    readonly property color tono: Reunion.activa ? Paleta.rojo : EstadoEscritorio.privacidad ? Paleta.morado : Paleta.naranja
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(perfil.tono, zonaPerfil.containsMouse ? .30 : .20) }
                        GradientStop { position: 1; color: Qt.alpha(perfil.tono, zonaPerfil.containsMouse ? .16 : .08) }
                    }
                    border { width: 1; color: Qt.alpha(tono, .35) }
                    Row {
                        id: filaPerfil
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: perfil.tono
                        }
                        Text {
                            id: etiquetaPerfil
                            text: Reunion.activa ? "Reunión " + Reunion.cuenta : EstadoEscritorio.privacidad ? "privacidad" : EstadoEscritorio.perfil
                            color: Qt.lighter(perfil.tono, 1.15)
                            font { family: Paleta.fuente; pixelSize: 11; bold: true }
                        }
                    }
                    MouseArea {
                        id: zonaPerfil
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(Reunion.activa ? ["qs", "ipc", "call", "mesa", "abrir", "reunion"] : ["qs", "ipc", "call", "centroEscritorio", "toggle"])
                    }
                }
            }
        }

        // Ventana activa: icono + título, en su propia isla
        IslaBarra {
            id: islaVentana
            readonly property var actual: ToplevelManager.activeToplevel
            readonly property string icono: {
                const e = actual ? DesktopEntries.heuristicLookup(actual.appId) : null;
                return e ? Quickshell.iconPath(e.icon, true) : "";
            }
            // El título cede espacio: nunca debe llegar a donde va el reloj (si no, la bandeja lo tapa).
            // Hueco = desde aquí hasta la isla derecha, menos el reloj y márgenes; tope 360 px.
            readonly property real hueco: islaDerecha.x - izquierda.x - islaEspacios.width - 8 - centro.implicitWidth - 40
            visible: !EstadoEscritorio.privacidad && actual !== null && actual.title !== "" && hueco > 80
            tinte: .02
            implicitWidth: Math.max(0, Math.min(360, hueco, filaVentana.implicitWidth + 28))
            Layout.preferredWidth: implicitWidth
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            RowLayout {
                id: filaVentana
                anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 8
                IconImage {
                    implicitSize: 18
                    source: islaVentana.icono
                    visible: islaVentana.icono !== ""
                }
                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: islaVentana.actual?.title ?? ""
                    color: Qt.alpha(Paleta.texto, .78)
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
    }

    // ── Centro: reloj (hover = fecha, clic = dashboard) ─────────────────
    IslaBarra {
        id: centro
        // Centrado en la pantalla si cabe; si no, centrado en el hueco libre entre izquierda y derecha
        readonly property real libreIni: izquierda.x + izquierda.width + 8
        readonly property real libreFin: islaDerecha.x - 8
        x: {
            const ideal = (barra.width - width) / 2;
            if (ideal >= libreIni && ideal + width <= libreFin) return ideal;
            return Math.max(libreIni, (libreIni + libreFin - width) / 2);
        }
        anchors.verticalCenter: parent.verticalCenter
        acento: Paleta.naranja
        tinte: zonaReloj.containsMouse ? .16 : .09
        implicitWidth: filaReloj.implicitWidth + 30
        width: implicitWidth
        Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Row {
            id: filaReloj
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰥔"
                color: Qt.alpha(Paleta.naranja, .85)
                font { family: Paleta.fuente; pixelSize: 13 }
            }
            Text {
                id: textoReloj
                anchors.verticalCenter: parent.verticalCenter
                text: zonaReloj.containsMouse
                    ? reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM") + "  ·  " + Qt.formatTime(reloj.date, "HH:mm")
                    : Qt.formatTime(reloj.date, "HH:mm")
                color: Qt.lighter(Paleta.naranja, 1.08)
                font { family: Paleta.fuente; pixelSize: 13; weight: Font.Bold; letterSpacing: .4 }
            }
        }
        MouseArea {
            id: zonaReloj
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: barra.relojPulsado()
        }
    }
}
