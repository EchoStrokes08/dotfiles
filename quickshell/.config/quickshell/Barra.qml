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

    anchors { top: true; left: true; right: true }   // 3 bordes → reserva su alto (como waybar)
    implicitHeight: 34
    color: Qt.alpha(Paleta.fondo, 0.88)
    WlrLayershell.namespace: "quickshell-barra"

    readonly property var monitor: Hyprland.monitorFor(screen)

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    function refrescar(que) { derecha.refrescar(que); }

    // ── Derecha: bandeja, Buds, volumen, red… ───────────────────────────
    BarraDerecha {
        id: derecha
        ventana: barra
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
    }

    // ── Izquierda: workspaces y ventana activa ──────────────────────────
    RowLayout {
        id: izquierda
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        spacing: 10

        BarraEspacios { id: espaciosBarra; monitor: barra.monitor }

        Rectangle {
            implicitWidth: etiquetaPerfil.implicitWidth + 16
            implicitHeight: 24
            radius: 7
            color: Qt.alpha(Paleta.naranja, 0.12)
            Text {
                id: etiquetaPerfil
                anchors.centerIn: parent
                text: Reunion.activa ? "Reunión " + Reunion.cuenta : EstadoEscritorio.privacidad ? "privacidad" : EstadoEscritorio.perfil
                color: Paleta.naranja
                font { family: Paleta.fuente; pixelSize: 11; bold: true }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(Reunion.activa ? ["qs", "ipc", "call", "mesa", "abrir", "reunion"] : ["qs", "ipc", "call", "centroEscritorio", "toggle"])
            }
        }

        // Ventana activa: icono + título (se funde al cambiar)
        RowLayout {
            id: ventanaActiva
            readonly property var actual: ToplevelManager.activeToplevel
            readonly property string icono: {
                const e = actual ? DesktopEntries.heuristicLookup(actual.appId) : null;
                return e ? Quickshell.iconPath(e.icon, true) : "";
            }
            spacing: 8
            visible: !EstadoEscritorio.privacidad && actual !== null && actual.title !== "" && hueco > 60
            // El título cede espacio: nunca debe llegar a donde va el reloj (si no, la bandeja lo tapa).
            // Hueco = desde aquí hasta el lado derecho, menos el reloj y márgenes; tope 340 px.
            readonly property real hueco: derecha.x - izquierda.x - espaciosBarra.width - etiquetaPerfil.implicitWidth - 36 - centro.implicitWidth - 24
            Layout.maximumWidth: Math.max(0, Math.min(340, hueco))

            IconImage {
                implicitSize: 16
                source: ventanaActiva.icono
                visible: ventanaActiva.icono !== ""
            }
            Text {
                Layout.maximumWidth: Math.max(0, Math.min(310, ventanaActiva.hueco - 24))
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
        // Centrado en la pantalla si cabe; si no, centrado en el hueco libre entre izquierda y derecha
        readonly property real libreIni: izquierda.x + izquierda.width + 8
        readonly property real libreFin: derecha.x - 8
        x: {
            const ideal = (barra.width - width) / 2;
            if (ideal >= libreIni && ideal + width <= libreFin) return ideal;
            return Math.max(libreIni, (libreIni + libreFin - width) / 2);
        }
        anchors.verticalCenter: parent.verticalCenter
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
