// Vista general (SUPER+ESPACIO o SUPER + 3 dedos arriba): todos los workspaces con sus ventanas
// en miniatura EN VIVO (ScreencopyView), sobre el fondo de pantalla, como Mission Control.
//   escribir = buscar · flechas/Tab = elegir ventana · Enter = ir · 1-9 = ir a ese espacio
//   Ctrl+1-9 = mandar la ventana elegida a ese espacio · Supr / clic central / × = cerrarla
//   arrastrar una ventana a otro espacio (o a «Espacio nuevo») = moverla · Esc cierra
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Superpuesta {
    id: vista
    espacio: "vista"
    anchoTarjeta: Math.max(1, Math.min(1360, (screen?.width ?? 1280) - 40))
    alturaRelativa: 0.05
    panelCuidado: true
    opacidadTarjeta: 1

    property string seleccion: ""            // dirección (sin 0x) de la ventana elegida

    // ── Zoom tipo Mission Control (ZoomVista.qml) ──
    // Al abrir: captura de la pantalla (~35 ms, en $XDG_RUNTIME_DIR) que se encoge hasta la miniatura del
    // espacio activo. Al ir a un espacio o ventana: su miniatura crece hasta llenar la pantalla.
    encima: ZoomVista { id: zoom }
    property var miniaturas: ({})            // id del espacio → su miniatura (para apuntar el zoom)
    property string capturaZoom: ""
    readonly property string dirZoom: Quickshell.env("XDG_RUNTIME_DIR") || ""
    function alternar() {
        if (abierto || capturador.running) { abierto = false; return; }
        const m = Hyprland.focusedMonitor?.name ?? "";
        if (!EstiloPanel.movimiento || EstadoEscritorio.privacidad || EstadoEscritorio.capturaPrivada || dirZoom === "" || m === "") { capturaZoom = ""; abierto = true; return; }
        capturaZoom = dirZoom + "/vista-" + m + ".ppm";
        capturador.command = ["sh", "-c", 'umask 077; grim -o "$1" -t ppm "$2"', "sh", m, capturaZoom];
        capturador.running = true;
        limiteZoom.restart();
    }
    Process {
        id: capturador
        onExited: (codigo) => { if (codigo !== 0) vista.capturaZoom = ""; if (limiteZoom.running) { limiteZoom.stop(); vista.abierto = true; } }
    }
    Timer { id: limiteZoom; interval: 300; onTriggered: { vista.capturaZoom = ""; vista.abierto = true; } }
    function zoomAEspacio(n) { const d = miniaturas[n]; if (d && EstiloPanel.movimiento) zoom.cerrar(d); }
    property string fondo: ""
    readonly property string fondoRuta: Quickshell.env("HOME") + "/.local/state/tema/wallpaper"

    onAbriendose: {
        const monitor = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        if (monitor) screen = monitor;
        Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); refresco.restart();
        if (capturaZoom !== "") { const r = capturaZoom; capturaZoom = ""; Qt.callLater(() => zoom.abrir(r, vista.miniaturas[vista.activo] ?? null)); }
        buscar.text = "";
        seleccion = Hyprland.activeToplevel?.address ?? "";
        fondo = ""; fondo = "file://" + fondoRuta;   // relee el fondo (puede haber cambiado)
        Qt.callLater(() => buscar.forceActiveFocus());
    }
    Timer { id: refresco; interval: 150; onTriggered: Hyprland.refreshToplevels() }   // posiciones al día

    // ── datos ──────────────────────────────────────────────────────────────────
    readonly property bool privacidad: EstadoEscritorio.privacidad || EstadoEscritorio.capturaPrivada
    function cantidad(n, singular, plural) { return n + " " + (n === 1 ? singular : plural); }
    function aplicacion(t) {
        return { clase: t?.lastIpcObject?.class ?? "", nombre: nombreApp(t) };
    }
    function aplicacionesDe(ventanas) {
        const apps = new Map();
        for (const t of ventanas) {
            const app = aplicacion(t);
            apps.set(app.clase || app.nombre, app);
        }
        return Array.from(apps.values()).slice(0, 3);
    }
    function normalizar(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
    function coincide(t) {
        const q = normalizar(buscar.text.trim());
        if (!q) return true;
        const titulo = privacidad ? "" : t.title;
        return normalizar((t.lastIpcObject?.class ?? "") + " " + nombreApp(t) + " " + titulo).includes(q);
    }
    function nombreApp(t) {
        const clase = t?.lastIpcObject?.class ?? "";
        const e = DesktopEntries.heuristicLookup(clase);
        return e?.name || clase.split(".").pop() || "Ventana";
    }
    function tituloVentana(t) {
        if (!t) return "";
        return privacidad ? nombreApp(t) : (t.title || nombreApp(t));
    }
    readonly property var cantidadPorClase: {
        const cantidades = new Map();
        for (const t of Hyprland.toplevels.values) {
            const clase = t.lastIpcObject?.class;
            if (clase && t.workspace?.id > 0) cantidades.set(clase, (cantidades.get(clase) || 0) + 1);
        }
        return cantidades;
    }
    readonly property int activo: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    function ventanasDe(id) {
        return Hyprland.toplevels.values
            .filter(t => t.workspace?.id === id)
            .sort((a, b) => (a.lastIpcObject?.at?.[0] ?? 0) - (b.lastIpcObject?.at?.[0] ?? 0)
                         || (a.lastIpcObject?.at?.[1] ?? 0) - (b.lastIpcObject?.at?.[1] ?? 0));
    }
    // Workspaces normales con ventanas + el actual (aunque esté vacío), en orden
    readonly property var espacios: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.id === activo || Hyprland.toplevels.values.some(t => t.workspace?.id === w.id)))
        .sort((a, b) => a.id - b.id)
    // Primer número libre (para «Espacio nuevo»)
    readonly property int libre: {
        const ids = new Set(espacios.map(w => w.id));
        let siguiente = 1;
        while (ids.has(siguiente)) siguiente++;
        return siguiente;
    }
    // Orden de recorrido con el teclado: espacio a espacio, de izquierda a derecha
    readonly property var orden: {
        const r = [];
        for (const w of espacios) for (const t of ventanasDe(w.id)) if (coincide(t)) r.push(t);
        return r;
    }
    readonly property var elegida: orden.find(t => t.address === seleccion) ?? orden[0] ?? null
    readonly property int coincidencias: orden.length

    // ── acciones ───────────────────────────────────────────────────────────────
    function irVentana(dir) {
        const t = Hyprland.toplevels.values.find(x => x.address === dir);
        if (t?.workspace) zoomAEspacio(t.workspace.id);
        cerrarY(() => Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${dir}" })`));
    }
    function irEspacio(n) { zoomAEspacio(n); cerrarY(() => Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`)); }
    function mover(dir, n) {
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:0x${dir}", workspace = ${n}, follow = false })`);
        refresco.restart();
    }
    function cerrarVentana(dir) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${dir}" })`);
        refresco.restart();
    }
    function avanzar(paso) {
        if (orden.length === 0) return;
        const i = Math.max(0, orden.indexOf(elegida));
        seleccion = orden[(i + paso + orden.length) % orden.length].address;
    }
    function saltarEspacio(paso) {   // ↑/↓: misma posición en el espacio anterior/siguiente
        if (!elegida) return;
        const ids = espacios.map(w => w.id).filter(id => orden.some(t => t.workspace?.id === id));
        const k = ids.indexOf(elegida.workspace?.id);
        const destino = ids[k + paso];
        if (destino === undefined) return;
        const aqui = orden.filter(t => t.workspace?.id === elegida.workspace?.id);
        const alli = orden.filter(t => t.workspace?.id === destino);
        seleccion = alli[Math.min(aqui.indexOf(elegida), alli.length - 1)].address;
    }

    // ── geometría: elegir columnas para que todo quepa sin desplazar ───────────
    readonly property real anchoUtil: Math.max(1, anchoTarjeta - margenPanel * 2)
    readonly property bool compacto: anchoUtil < 690
    readonly property real altoDisponible: (screen?.height ?? 720) * .92 - 240
    readonly property real proporcion: {
        const m = Hyprland.focusedMonitor;
        return m ? Math.min(.85, m.height / Math.max(1, m.width)) : 9 / 16;
    }
    readonly property int celdas: espacios.length + 1
    readonly property int columnas: {
        const tope = Math.max(1, Math.min(celdas, 5, Math.floor((anchoUtil + 16) / 170)));
        for (let c = Math.min(3, tope); c < tope; c++) {
            const ancho = (anchoUtil - (c - 1) * 16) / c;
            const filas = Math.ceil(celdas / c);
            if (filas * (ancho * proporcion + 66) + (filas - 1) * 16 <= altoDisponible) return c;
        }
        return tope;
    }
    readonly property real anchoCelda: Math.floor((anchoUtil - (columnas - 1) * 16) / columnas)
    readonly property real altoMiniatura: Math.round(anchoCelda * proporcion)

    Item {
        id: raiz
        width: parent.width
        height: columna.height

        Column {
            id: columna
            width: parent.width
            spacing: 16

            // ── cabecera ─────────────────────────────────────────────────────
            EncabezadoPanel {
                width: parent.width
                simbolo: String.fromCodePoint(0xF056E)
                titulo: "Vista general"
                seccion: vista.cantidad(Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > 0).length,
                                        "ventana", "ventanas") + " · " + vista.cantidad(vista.espacios.length, "espacio", "espacios")
                onCerrar: vista.abierto = false
            }

            GridLayout {
                width: parent.width
                columns: vista.compacto ? 1 : 2
                columnSpacing: 16
                rowSpacing: 8

                CampoPanel {
                    id: buscar
                    Layout.row: 0
                    Layout.column: vista.compacto ? 0 : 1
                    Layout.fillWidth: vista.compacto
                    Layout.preferredWidth: vista.compacto ? -1 : Math.min(360, parent.width * .42)
                    placeholderText: "󰍉  Buscar ventana…"
                    onTextChanged: vista.seleccion = vista.orden[0]?.address ?? ""
                    Keys.onPressed: (e) => {
                        const digito = e.key >= Qt.Key_1 && e.key <= Qt.Key_9;
                        if (digito && (e.modifiers & Qt.ControlModifier)) {
                            if (vista.elegida) vista.mover(vista.elegida.address, e.key - Qt.Key_0);
                            e.accepted = true;
                        } else if (digito && buscar.text === "") {
                            vista.irEspacio(e.key - Qt.Key_0); e.accepted = true;
                        } else if (e.key === Qt.Key_Delete && buscar.text === "") {
                            if (vista.elegida) { const d = vista.elegida.address; vista.avanzar(1); vista.cerrarVentana(d); }
                            e.accepted = true;
                        } else if (e.key === Qt.Key_Right && (buscar.text === "" || buscar.cursorPosition === buscar.text.length)) {
                            vista.avanzar(1); e.accepted = true;
                        } else if (e.key === Qt.Key_Left && (buscar.text === "" || buscar.cursorPosition === 0)) {
                            vista.avanzar(-1); e.accepted = true;
                        } else if (e.key === Qt.Key_Tab) { vista.avanzar(1); e.accepted = true; }
                        else if (e.key === Qt.Key_Backtab) { vista.avanzar(-1); e.accepted = true; }
                        else if (e.key === Qt.Key_Down) { vista.saltarEspacio(1); e.accepted = true; }
                        else if (e.key === Qt.Key_Up) { vista.saltarEspacio(-1); e.accepted = true; }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (vista.elegida) vista.irVentana(vista.elegida.address);
                            else if (buscar.text === "") vista.irEspacio(vista.activo);
                            e.accepted = true;
                        }
                    }
                }
                Rectangle {
                    Layout.row: vista.compacto ? 1 : 0
                    Layout.column: 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: EstiloPanel.rControl
                    color: EstiloPanel.relleno
                    border { width: 1; color: EstiloPanel.borde }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 8
                        IconoApp {
                            visible: !!vista.elegida
                            lado: 18
                            app: vista.elegida ? vista.aplicacion(vista.elegida) : null
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: vista.elegida ? vista.tituloVentana(vista.elegida)
                                : buscar.text.trim() ? "No hay ventanas que coincidan" : "Sin ventanas abiertas"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: vista.elegida ? Paleta.texto : EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
                        }
                        Text {
                            visible: buscar.text.trim() !== "" && !vista.compacto && vista.coincidencias > 0
                            text: vista.cantidad(vista.coincidencias, "coincidencia", "coincidencias")
                            color: EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 12 }
                        }
                        BotonCompacto {
                            visible: buscar.text !== ""
                            text: "Limpiar"
                            onClicked: { buscar.clear(); buscar.forceActiveFocus(); }
                        }
                    }
                }

            }

            // ── rejilla de espacios ────────────────────────────────────────────
            Flow {
                width: parent.width
                spacing: 16

                Repeater {
                    model: vista.espacios
                    Item {
                        id: celda
                        required property var modelData
                        required property int index
                        readonly property var mon: modelData.monitor
                        // tamaño LÓGICO del monitor (las ventanas vienen en lógicas: con escala 1,5, 1920 px = 1280)
                        readonly property real anchoLog: (mon?.width ?? 1920) / (mon?.scale ?? 1)
                        readonly property real altoLog: (mon?.height ?? 1080) / (mon?.scale ?? 1)
                        readonly property real aspecto: altoLog / Math.max(1, anchoLog)
                        readonly property real escala: pantalla.width / Math.max(1, anchoLog)
                        readonly property bool esActivo: modelData.id === vista.activo
                        readonly property bool resaltada: destino.containsDrag || (vista.elegida?.workspace?.id === modelData.id && !esActivo)
                        readonly property var ventanas: vista.ventanasDe(modelData.id)
                        width: vista.anchoCelda
                        height: vista.altoMiniatura + 66
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name + ", " + vista.cantidad(ventanas.length, "ventana", "ventanas")
                        Accessible.onPressAction: vista.irEspacio(modelData.id)

                        readonly property int duracion: EstiloPanel.movimiento ? EstiloPanel.normal + Math.min(5, index) * 25 : 0
                        Component.onCompleted: vista.miniaturas[modelData.id] = pantalla
                        Component.onDestruction: if (vista.miniaturas[modelData.id] === pantalla) delete vista.miniaturas[modelData.id]
                        opacity: vista.abierto ? 1 : 0
                        transform: Translate {
                            y: vista.abierto ? 0 : 8
                            Behavior on y { NumberAnimation { duration: celda.duracion; easing.type: Easing.OutCubic } }
                        }
                        Behavior on opacity { NumberAnimation { duration: celda.duracion } }

                        RowLayout {
                            width: parent.width
                            height: 24
                            spacing: 8

                            Rectangle {
                                implicitWidth: Math.max(24, numero.implicitWidth + 12)
                                implicitHeight: 24
                                radius: EstiloPanel.rChip
                                color: celda.esActivo ? EstiloPanel.seleccionado : EstiloPanel.elevada
                                border { width: 1; color: celda.esActivo ? EstiloPanel.bordeSeleccion : EstiloPanel.bordeFuerte }
                                Text {
                                    id: numero
                                    anchors.centerIn: parent
                                    text: celda.modelData.id
                                    color: celda.esActivo ? Paleta.acento : Paleta.texto
                                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: celda.modelData.name !== String(celda.modelData.id) ? celda.modelData.name : "Espacio " + celda.modelData.id
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: celda.esActivo ? Paleta.texto : EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 13; weight: Font.DemiBold }
                            }
                            Text {
                                visible: celda.width >= 128 && (celda.esActivo || destino.containsDrag)
                                text: destino.containsDrag ? "Soltar aquí" : "Activo"
                                color: Paleta.acento
                                font { family: Paleta.fuente; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }

                        // la pantalla en miniatura
                        Item {
                            id: marco
                            y: 32
                            width: parent.width
                            height: vista.altoMiniatura
                            scale: zonaCelda.containsMouse && !celda.esActivo ? 1.012 : 1
                            Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }

                            RectangularShadow {
                                anchors.fill: parent
                                visible: EstiloPanel.profundidad
                                radius: 16
                                offset.y: 8; blur: 26; spread: -8
                                color: celda.esActivo || celda.resaltada ? Qt.alpha(Paleta.acento, .35) : Qt.alpha("black", .55)
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: EstiloPanel.rControl
                                color: EstiloPanel.superficie
                            }
                            MarcoFondo {
                                id: pantalla
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height / Math.max(.1, celda.aspecto))
                                height: Math.min(parent.height, width * celda.aspecto)

                                Image {
                                    anchors.fill: parent
                                    source: vista.fondo
                                    sourceSize.width: 640
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    asynchronous: true
                                    opacity: celda.esActivo ? .96 : .82
                                }
                                Rectangle { anchors.fill: parent; color: Qt.alpha(Paleta.fondo, celda.esActivo ? .10 : .24) }

                                // hueco = ir a ese espacio
                                MouseArea {
                                    id: zonaCelda
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: vista.irEspacio(celda.modelData.id)
                                }
                                // soltar aquí una ventana = moverla a este espacio
                                DropArea {
                                    id: destino
                                    anchors.fill: parent
                                    keys: ["ventana"]
                                    onDropped: (d) => vista.mover(d.source.dir, celda.modelData.id)
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: celda.ventanas.length === 0
                                    width: rotuloVacio.implicitWidth + 16
                                    height: 28
                                    radius: height / 2
                                    color: Paleta.fondo
                                    border { width: 1; color: EstiloPanel.bordeFuerte }
                                    Text {
                                        id: rotuloVacio
                                        anchors.centerIn: parent
                                        text: "Espacio vacío"
                                        color: EstiloPanel.tenue
                                        font { family: Paleta.fuente; pixelSize: 12 }
                                    }
                                }

                                Repeater {
                                    model: celda.ventanas
                                    Item {
                                        id: ventanita
                                        required property var modelData
                                        readonly property var ipc: modelData.lastIpcObject
                                        readonly property string dir: modelData.address
                                        readonly property bool elegida: vista.elegida?.address === dir
                                        readonly property bool encaja: vista.coincide(modelData)
                                        readonly property bool encima: arrastre.containsMouse || arrastre.drag.active
                                        readonly property real x0: ((ipc?.at?.[0] ?? 0) - (celda.mon?.x ?? 0)) * celda.escala
                                        readonly property real y0: ((ipc?.at?.[1] ?? 0) - (celda.mon?.y ?? 0)) * celda.escala
                                        x: x0; y: y0
                                        width: Math.max(28, (ipc?.size?.[0] ?? 200) * celda.escala)
                                        height: Math.max(20, (ipc?.size?.[1] ?? 150) * celda.escala)
                                        z: arrastre.drag.active ? 10 : elegida ? 3 : (ipc?.floating ? 2 : 1)
                                        opacity: encaja ? 1 : 0.22
                                        scale: arrastre.drag.active ? 0.9 : encima ? 1.03 : 1
                                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
                                        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido; easing.type: Easing.OutCubic } }
                                        Drag.active: arrastre.drag.active
                                        Drag.keys: ["ventana"]
                                        Drag.source: ventanita
                                        Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                        Rectangle {
                                            id: tapa
                                            anchors.fill: parent
                                            radius: 8
                                            color: Paleta.seleccion
                                            clip: true
                                            ScreencopyView {
                                                anchors { fill: parent; margins: 1 }
                                                captureSource: vista.abierto && !vista.privacidad ? ventanita.modelData.wayland ?? null : null
                                                live: true
                                            }
                                            // velo + título al pasar el ratón o al elegirla
                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                                height: Math.min(parent.height, 24)
                                                visible: parent.height > 40 && (ventanita.encima || ventanita.elegida ||
                                                    (parent.width >= 90 && vista.cantidadPorClase.get(ventanita.ipc?.class) > 1))
                                                gradient: Gradient {
                                                    GradientStop { position: 0; color: "transparent" }
                                                    GradientStop { position: 1; color: Qt.alpha("black", .75) }
                                                }
                                                Text {
                                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4; leftMargin: 8 }
                                                    text: vista.tituloVentana(ventanita.modelData)
                                                    textFormat: Text.PlainText
                                                    color: "white"
                                                    elide: Text.ElideRight
                                                    font { family: EstiloPanel.fuente; pixelSize: 11; weight: Font.Medium }
                                                }
                                            }
                                        }
                                        Rectangle {   // borde (encima de la captura)
                                            anchors.fill: parent
                                            radius: 8
                                            color: "transparent"
                                            border.width: ventanita.elegida ? 2 : 1
                                            border.color: ventanita.elegida ? Paleta.acento : ventanita.encima ? EstiloPanel.tenue : EstiloPanel.bordeFuerte
                                            Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
                                        }
                                        // El icono deja libre el centro de las capturas en vivo.
                                        Rectangle {
                                            id: insigniaApp
                                            readonly property bool centrada: vista.privacidad || !ventanita.modelData.wayland
                                            readonly property real lado: Math.min(centrada ? 36 : 24, Math.max(16, Math.min(parent.width, parent.height) * .34))
                                            x: centrada ? (parent.width - width) / 2 : 6
                                            y: centrada ? (parent.height - height) / 2 : 6
                                            width: lado; height: lado; radius: EstiloPanel.rChip
                                            color: Qt.alpha(Paleta.fondo, .92)
                                            border { width: 1; color: EstiloPanel.bordeFuerte }
                                            visible: parent.height >= 34 && parent.width >= 34
                                            IconoApp {
                                                anchors.centerIn: parent
                                                lado: Math.max(12, insigniaApp.lado - 8)
                                                app: vista.aplicacion(ventanita.modelData)
                                            }
                                        }
                                        MouseArea {
                                            id: arrastre
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            drag.target: ventanita
                                            onEntered: vista.seleccion = ventanita.dir
                                            onReleased: {
                                                if (ventanita.Drag.target) ventanita.Drag.drop();
                                                ventanita.x = Qt.binding(() => ventanita.x0);
                                                ventanita.y = Qt.binding(() => ventanita.y0);
                                            }
                                            onClicked: (m) => {
                                                if (m.button === Qt.MiddleButton) vista.cerrarVentana(ventanita.dir);
                                                else vista.irVentana(ventanita.dir);
                                            }
                                        }
                                        // ×: cerrar la ventana
                                        Rectangle {
                                            anchors { top: parent.top; right: parent.right; margins: 4 }
                                            width: 18; height: 18; radius: height / 2
                                            visible: ventanita.encima && !arrastre.drag.active && parent.width > 50
                                            color: equis.containsMouse ? Paleta.peligro : Qt.alpha("black", .65)
                                            Text { anchors.centerIn: parent; text: "×"; color: "white"; font { pixelSize: 13; bold: true } }
                                            MouseArea {
                                                id: equis
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: vista.cerrarVentana(ventanita.dir)
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {   // filo
                                anchors.fill: parent
                                radius: EstiloPanel.rControl
                                color: "transparent"
                                border.width: celda.esActivo || celda.resaltada ? 2 : 1
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.alpha(Paleta.acento, destino.containsDrag ? .18 : 0) }
                                }
                                border.color: celda.esActivo ? Paleta.acento
                                            : celda.resaltada ? Qt.alpha(Paleta.acento, .6)
                                            : Qt.alpha(Paleta.texto, zonaCelda.containsMouse ? .3 : .12)
                                Behavior on border.color { ColorAnimation { duration: EstiloPanel.rapido } }
                            }
                        }
                        RowLayout {
                            y: marco.y + marco.height + 4
                            width: parent.width
                            height: 26
                            spacing: 4
                            Repeater {
                                model: vista.aplicacionesDe(celda.ventanas)
                                IconoApp {
                                    required property var modelData
                                    lado: 16
                                    app: modelData
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.minimumWidth: 0
                                text: vista.cantidad(celda.ventanas.length, "ventana", "ventanas")
                                elide: Text.ElideRight
                                color: EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 11 }
                            }
                        }
                    }
                }

                // ── espacio nuevo: clic = ir; soltar = mandar allí la ventana ──
                Item {
                    id: nuevo
                    readonly property int posicion: vista.espacios.length % vista.columnas
                    readonly property bool filaPropia: vista.espacios.length > 0 && posicion === 0 && vista.columnas > 1
                    width: vista.anchoUtil - posicion * (vista.anchoCelda + 16)
                    height: filaPropia ? 96 : vista.altoMiniatura + 66
                    Accessible.role: Accessible.Button
                    Accessible.name: "Crear espacio " + vista.libre
                    Accessible.onPressAction: vista.irEspacio(vista.libre)
                    opacity: vista.abierto ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: EstiloPanel.movimiento ? EstiloPanel.lento : 0 } }
                    Text {
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        text: "Espacio " + vista.libre
                        color: EstiloPanel.tenue
                        font { family: EstiloPanel.fuente; pixelSize: 12 }
                    }
                    Rectangle {
                        y: 32
                        width: parent.width
                        height: nuevo.filaPropia ? 60 : vista.altoMiniatura
                        radius: 12
                        id: cajaNuevo
                        color: nuevoDestino.containsDrag ? EstiloPanel.seleccionado : nuevoZona.containsMouse ? EstiloPanel.elevada : EstiloPanel.superficie
                        Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                        Shape {   // borde discontinuo: «suelta aquí»
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: nuevoDestino.containsDrag ? 2 : 1.5
                                strokeColor: nuevoDestino.containsDrag || nuevoZona.containsMouse ? Paleta.acento : Qt.alpha(Paleta.texto, .22)
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [4, 3]
                                fillColor: "transparent"
                                PathRectangle { x: 1; y: 1; width: cajaNuevo.width - 2; height: cajaNuevo.height - 2; radius: cajaNuevo.radius }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "+"
                                color: nuevoDestino.containsDrag || nuevoZona.containsMouse ? Paleta.acento : EstiloPanel.tenue
                                font { family: EstiloPanel.fuente; pixelSize: 26; weight: Font.Light }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: nuevoDestino.containsDrag ? "Soltar para mover" : "Crear espacio"
                                color: EstiloPanel.tenue
                                font { family: EstiloPanel.fuente; pixelSize: 11 }
                            }
                        }
                        MouseArea {
                            id: nuevoZona
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: vista.irEspacio(vista.libre)
                        }
                        DropArea {
                            id: nuevoDestino
                            anchors.fill: parent
                            keys: ["ventana"]
                            onDropped: (d) => vista.mover(d.source.dir, vista.libre)
                        }
                    }
                }
            }

            // ── pie: atajos ────────────────────────────────────────────────────
            PieAtajos {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: vista.compacto ? EstiloPanel.e2 : EstiloPanel.e4
                visible: implicitWidth <= columna.width
                atajos: vista.compacto ? [["↵", "abrir"], ["← →", "elegir"], ["Esc", "salir"]]
                    : [["↵", "abrir"], ["← →", "elegir"], ["↑ ↓", "otro espacio"], ["Ctrl 1–9", "mover"], ["Esc", "salir"]]
            }
        }
    }
}
