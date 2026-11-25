// Barra superior hecha en Quickshell.
// Izquierda: workspaces + ventana activa · centro: reloj · derecha: BarraDerecha.qml
// Una barra por pantalla: shell.qml la crea con Variants { model: Quickshell.screens }.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: barra
    signal relojPulsado()               // shell.qml lo conecta con el dashboard

    // Solo se oculta en el espacio del juego; sigue su ventana al moverla.
    readonly property bool juegoEnEspacio: {
        const datos = EstadoEscritorio.datos;
        if (datos.juego_activo !== "true") return false;
        const ws = monitor?.activeWorkspace;
        if (!ws) return false;
        if (String(ws.id) === datos.juego_espacio_manual) return true;
        const direcciones = String(datos.juego_ventanas || "").split(",")
            .filter(a => a !== "").map(a => a.replace(/^0x/, ""));
        return ws.toplevels.values.some(t =>
            direcciones.includes(String(t.address).replace(/^0x/, "")));
    }
    visible: !juegoEnEspacio
    // La isla del reloj enseña los avisos (volumen, brillo…) solo si esta barra se ve (Isla.qml)
    function registrarIsla() { Isla.registrar(monitor?.name ?? "", visible); }
    onVisibleChanged: registrarIsla()
    onMonitorChanged: registrarIsla()
    Component.onCompleted: registrarIsla()

    // Barra transparente con tres «islas» de cristal (IslaBarra.qml): izquierda, reloj y derecha
    anchors { top: true; left: true; right: true }   // 3 bordes → reserva su alto
    implicitHeight: 42
    color: "transparent"
    WlrLayershell.namespace: "quickshell-barra"

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property real margen: 8      // de las islas al borde de la pantalla

    SystemClock { id: reloj; precision: SystemClock.Minutes }
    // Dónde está el puntero en la barra: lo que se abra desde aquí nace de ese punto (Origen.qml)
    HoverHandler { id: puntero }
    // Modo zen: durante una sesión de concentración se apaga todo menos la isla del reloj (el anillo);
    // vuelve al pasar el ratón por la barra
    readonly property bool zen: Concentracion.activo && !puntero.hovered
    function marcarOrigen() { Origen.marcarPunto(puntero.point.position.x, puntero.point.position.y, screen?.name ?? ""); }
    // Próxima cita en 30 min o menos (o en curso): chip junto a la hora (ORION 5.7). Nunca con privacidad.
    readonly property var citaCercana: {
        const ahora = reloj.date;
        if (EstadoEscritorio.privacidad || EstadoEscritorio.capturaPrivada) return null;
        const e = Eventos.proximos(1)[0];
        if (!e || e.todoDia) return null;
        const min = Math.round((e.inicio - ahora) / 60000);
        if (e.inicio <= ahora && e.fin > ahora) return { titulo: e.titulo, cuando: "ahora" };
        return min >= 0 && min <= 30 ? { titulo: e.titulo, cuando: min <= 1 ? "ya" : min + " min" } : null;
    }

    function refrescar(que) { derecha.refrescar(que); }

    // ── Derecha: bandeja, Buds, volumen, red… ───────────────────────────
    IslaBarra {
        id: islaDerecha
        atenuada: barra.zen
        anchors { right: parent.right; rightMargin: barra.margen; verticalCenter: parent.verticalCenter }
        implicitWidth: derecha.implicitWidth + 16
        BarraDerecha {
            id: derecha
            ventana: barra
            onAntesDeEjecutar: barra.marcarOrigen()
            prioridad: ModoTeclado.activo || EstadoEscritorio.privacidad
            compacto: barra.width < 1400
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
            atenuada: barra.zen
            implicitWidth: filaEspacios.implicitWidth + 12
            RowLayout {
                id: filaEspacios
                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 4

                BarraEspacios { monitor: barra.monitor; ayuda: ayudaBarra }

                IndicadorTeclado { id: modoTeclado }

                // Perfil del escritorio (o reunión / privacidad)
                Rectangle {
                    id: perfil
                    // solo cuando el escritorio no está en su estado habitual (perfil cristal, sin reunión ni privacidad)
                    visible: Reunion.activa || EstadoEscritorio.privacidad || EstadoEscritorio.perfil !== "cristal"
                    implicitWidth: filaPerfil.implicitWidth + 18
                    implicitHeight: 24
                    radius: 12
                    readonly property color tono: Reunion.activa ? Paleta.peligro : EstadoEscritorio.privacidad ? Paleta.acento2 : Paleta.acento
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(perfil.tono, zonaPerfil.containsMouse ? .30 : .20) }
                        GradientStop { position: 1; color: Qt.alpha(perfil.tono, zonaPerfil.containsMouse ? .16 : .08) }
                    }
                    border { width: 1; color: Qt.alpha(tono, .35) }
                    Row {
                        id: filaPerfil
                        anchors.centerIn: parent
                        spacing: 4
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: height / 2
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
                        onClicked: { barra.marcarOrigen(); Quickshell.execDetached(Reunion.activa ? ["qs", "ipc", "call", "mesa", "abrir", "reunion"] : ["qs", "ipc", "call", "centroEscritorio", "toggle"]); }
                    }
                }
            }
        }

        // Ventana activa: icono + título, en su propia isla
        IslaBarra {
            id: islaVentana
            atenuada: barra.zen
            readonly property var actual: ToplevelManager.activeToplevel
            readonly property string icono: {
                const e = actual ? DesktopEntries.heuristicLookup(actual.appId) : null;
                return e ? Quickshell.iconPath(e.icon, true) : "";
            }
            // El título cede espacio: nunca debe llegar a donde va el reloj (si no, la bandeja lo tapa).
            // Hueco = desde aquí hasta la isla derecha, menos el reloj y márgenes; tope 360 px.
            readonly property real hueco: islaDerecha.x - izquierda.x - islaEspacios.width - 8 - centro.implicitWidth - 40
            visible: !ModoTeclado.activo && !EstadoEscritorio.privacidad && !EstadoEscritorio.capturaPrivada && actual !== null && actual.title !== "" && hueco > 80
            tinte: .02
            implicitWidth: Math.max(0, Math.min(360, hueco, filaVentana.implicitWidth + 28))
            Layout.preferredWidth: implicitWidth
            Behavior on implicitWidth { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }

            // Al cambiar de ventana el título entra desde abajo; si además cambia la app, el icono da un saltito
            readonly property string app: actual?.appId ?? ""
            onActualChanged: if (EstiloPanel.movimiento) entradaTitulo.restart()
            onAppChanged: if (EstiloPanel.movimiento) saltoIcono.restart()
            ParallelAnimation {
                id: entradaTitulo
                NumberAnimation { target: deslizTitulo; property: "y"; from: 8; to: 0; duration: EstiloPanel.normal; easing.type: Easing.OutCubic }
                NumberAnimation { target: tituloVentana; property: "opacity"; from: 0; to: 1; duration: EstiloPanel.normal }
            }
            SequentialAnimation {
                id: saltoIcono
                NumberAnimation { target: cajaIcono; property: "scale"; from: .55; to: 1; duration: EstiloPanel.lento; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }

            RowLayout {
                id: filaVentana
                anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8
                // icono de la app activa con un halo de sus propios colores (como en el lanzador)
                Item {
                    id: cajaIcono
                    implicitWidth: 18; implicitHeight: 18
                    visible: islaVentana.icono !== ""
                    MultiEffect {
                        anchors.centerIn: parent
                        width: 30; height: 30
                        visible: EstiloPanel.profundidad && iconoVentana.status === Image.Ready
                        source: iconoVentana
                        blurEnabled: true; blur: 1; blurMax: 24
                        saturation: .4; brightness: .2
                        opacity: .9
                    }
                    IconImage {
                        id: iconoVentana
                        anchors.fill: parent
                        source: islaVentana.icono
                    }
                }
                Text {
                    id: tituloVentana
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    transform: Translate { id: deslizTitulo }
                    text: islaVentana.actual?.title ?? ""
                    textFormat: Text.PlainText
                    color: EstiloPanel.secundario
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 12; weight: Font.DemiBold }
                }
            }
        }
    }

    // La fecha y la cita se adaptan al hueco sin que el reloj cambie de tamaño al pasar el ratón.
    Ayuda { id: ayudaBarra; ventana: barra; textoPlano: true }
    RelojBarra {
        id: centro
        ventana: barra
        avisos: Isla.enfocado === (barra.monitor?.name ?? "")
        fecha: reloj.date
        cita: barra.citaCercana
        ayuda: ayudaBarra
        anchoDisponible: islaDerecha.x - izquierda.x - islaEspacios.width - 24
        readonly property real libreIni: izquierda.x + izquierda.width + 8
        readonly property real libreFin: islaDerecha.x - 8
        x: Math.max(libreIni, Math.min((barra.width - width) / 2, libreFin - width))
        anchors.verticalCenter: parent.verticalCenter
        onPulsado: barra.relojPulsado()
    }
}
