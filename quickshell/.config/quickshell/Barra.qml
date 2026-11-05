// Barra superior hecha en Quickshell (sustituirá a waybar módulo a módulo).
// Fase 1: izquierda (workspaces + ventana activa) y centro (reloj).
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

    anchors { top: true; left: true; right: true }   // 3 bordes → reserva su alto (como waybar)
    implicitHeight: 34
    color: Qt.alpha(Paleta.fondo, 0.88)
    WlrLayershell.namespace: "quickshell-barra"

    readonly property var monitor: Hyprland.monitorFor(screen)

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    // ── Izquierda: workspaces y ventana activa ──────────────────────────
    RowLayout {
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 10

        BarraEspacios { monitor: barra.monitor }

        // Ventana activa: icono + título (se funde al cambiar)
        RowLayout {
            id: ventanaActiva
            readonly property var actual: ToplevelManager.activeToplevel
            readonly property string icono: {
                const e = actual ? DesktopEntries.heuristicLookup(actual.appId) : null;
                return e ? Quickshell.iconPath(e.icon, true) : "";
            }
            spacing: 8
            visible: actual !== null && actual.title !== ""
            Layout.maximumWidth: 460

            IconImage {
                implicitSize: 16
                source: ventanaActiva.icono
                visible: ventanaActiva.icono !== ""
            }
            Text {
                Layout.maximumWidth: 430
                text: ventanaActiva.actual?.title ?? ""
                color: Paleta.gris
                elide: Text.ElideRight
                font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
            }
        }
    }

    // ── Centro: reloj (hover = fecha, clic = dashboard) ─────────────────
    Item {
        id: centro
        anchors.centerIn: parent
        implicitWidth: textoReloj.implicitWidth + 24
        implicitHeight: parent.height
        width: implicitWidth
        height: implicitHeight
        Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 8
            color: Qt.alpha(Paleta.naranja, zonaReloj.containsMouse ? 0.12 : 0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            id: textoReloj
            anchors.centerIn: parent
            text: zonaReloj.containsMouse
                ? reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd d 'de' MMMM") + "  ·  " + Qt.formatTime(reloj.date, "HH:mm")
                : Qt.formatTime(reloj.date, "HH:mm")
            color: Paleta.naranja
            font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
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
