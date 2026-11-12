// Vista general (SUPER+ESPACIO o SUPER + 3 dedos arriba): todos los workspaces con sus ventanas
// en miniatura EN VIVO (ScreencopyView), sobre el fondo de pantalla, como Mission Control.
//   escribir = buscar · flechas/Tab = elegir ventana · Enter = ir · 1-9 = ir a ese espacio
//   Ctrl+1-9 = mandar la ventana elegida a ese espacio · Supr / clic central / × = cerrarla
//   arrastrar una ventana a otro espacio (o a «Espacio nuevo») = moverla · Esc cierra
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Superpuesta {
    id: vista
    espacio: "vista"
    anchoTarjeta: Math.min(1440, (screen?.width ?? 1280) - 56)
    alturaRelativa: 0.05
    panelCuidado: true
    opacidadTarjeta: 1

    property string seleccion: ""            // dirección (sin 0x) de la ventana elegida
    property string fondo: ""
    readonly property string fondoRuta: Quickshell.env("HOME") + "/.local/state/tema/wallpaper"

    onAbriendose: {
        const monitor = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        if (monitor) screen = monitor;
        Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); refresco.restart();
        buscar.text = "";
        seleccion = Hyprland.activeToplevel?.address ?? "";
        fondo = ""; fondo = "file://" + fondoRuta;   // relee el fondo (puede haber cambiado)
        Qt.callLater(() => buscar.forceActiveFocus());
    }
    Timer { id: refresco; interval: 150; onTriggered: Hyprland.refreshToplevels() }   // posiciones al día

    // ── datos ──────────────────────────────────────────────────────────────────
    function normalizar(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
    function coincide(t) {
        const q = normalizar(buscar.text.trim());
        if (!q) return true;
        const titulo = EstadoEscritorio.privacidad ? "" : t.title;
        return normalizar((t.lastIpcObject?.class ?? "") + " " + titulo).includes(q);
    }
    function icono(t) {
        const e = DesktopEntries.heuristicLookup(t?.lastIpcObject?.class ?? "");
        return e ? Quickshell.iconPath(e.icon, true) : "";
    }
    function nombreApp(t) {
        const clase = t?.lastIpcObject?.class ?? "";
        const e = DesktopEntries.heuristicLookup(clase);
        return e?.name || clase.split(".").pop() || "Ventana";
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
        for (let i = 1; i <= 10; i++) if (!espacios.some(w => w.id === i)) return i;
        return 10;
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
    function irVentana(dir) { cerrarY(() => Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${dir}" })`)); }
    function irEspacio(n) { cerrarY(() => Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`)); }
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
    readonly property real anchoUtil: anchoTarjeta - margenPanel * 2
    readonly property real altoDisponible: (screen?.height ?? 720) * 0.9 - 150
    readonly property real proporcion: {
        const m = Hyprland.focusedMonitor;
        return m ? m.height / Math.max(1, m.width) : 9 / 16;
    }
    readonly property int celdas: espacios.length + 1
    readonly property int columnas: {
        for (let c = Math.min(3, celdas); c <= 5; c++) {
            const ancho = (anchoUtil - (c - 1) * 16) / c;
            const filas = Math.ceil(celdas / c);
            if (filas * (ancho * proporcion + 40) + (filas - 1) * 16 <= altoDisponible) return c;
        }
        return 5;
    }
    readonly property real anchoCelda: (anchoUtil - (columnas - 1) * 16) / columnas

    Item {
        id: raiz
        width: parent.width
        height: columna.height

        Column {
            id: columna
            width: parent.width
            spacing: 16

            // ── cabecera: título, recuento y buscador ──────────────────────────
            Row {
                width: parent.width
                height: 44
                spacing: 14
                Column {
                    id: titulo
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "VISTA GENERAL"
                        color: Paleta.naranja
                        font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.6 }
                    }
                    Text {
                        text: buscar.text
                            ? (vista.coincidencias === 1 ? "1 coincidencia" : vista.coincidencias + " coincidencias")
                            : Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > 0).length + " ventanas · " + vista.espacios.length + " espacios"
                        color: Paleta.texto
                        font { family: EstiloPanel.fuente; pixelSize: 17; weight: Font.DemiBold }
                    }
                }
                Item { width: parent.width - titulo.width - buscar.width - parent.spacing * 2; height: 1 }
                CampoPanel {
                    id: buscar
                    width: Math.min(360, parent.width * 0.4)
                    anchors.verticalCenter: parent.verticalCenter
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
            }

            // ── rejilla de espacios ────────────────────────────────────────────
            Flow {
                id: rejilla
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
                        readonly property real escala: pantalla.width / Math.max(1, anchoLog)
                        readonly property bool esActivo: modelData.id === vista.activo
                        readonly property bool resaltada: destino.containsDrag || (vista.elegida?.workspace?.id === modelData.id && !esActivo)
                        readonly property var ventanas: vista.ventanasDe(modelData.id)
                        width: vista.anchoCelda
                        height: pantalla.height + 34

                        // entrada escalonada
                        opacity: vista.abierto ? 1 : 0
                        transform: Translate { y: vista.abierto ? 0 : 10; Behavior on y { NumberAnimation { duration: EstiloPanel.entrada + celda.index * 35; easing.type: Easing.OutCubic } } }
                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada + celda.index * 35 } }

                        // rótulo: número, nombre y nº de ventanas
                        Row {
                            id: rotulo
                            height: 26
                            spacing: 8
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(22, numero.implicitWidth + 12); height: 22; radius: 7
                                color: celda.esActivo ? Paleta.naranja : Qt.alpha(Paleta.texto, .08)
                                Text {
                                    id: numero
                                    anchors.centerIn: parent
                                    text: celda.modelData.id
                                    color: celda.esActivo ? Paleta.fondo : Paleta.texto
                                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (celda.modelData.name !== String(celda.modelData.id) ? celda.modelData.name + " · " : "")
                                    + (celda.ventanas.length === 0 ? "vacío"
                                       : celda.ventanas.length === 1 ? vista.nombreApp(celda.ventanas[0])
                                       : celda.ventanas.length + " ventanas")
                                color: celda.esActivo ? Paleta.texto : EstiloPanel.tenue
                                font { family: EstiloPanel.fuente; pixelSize: 12; weight: celda.esActivo ? Font.DemiBold : Font.Normal }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: celda.esActivo
                                text: "· aquí estás"
                                color: Paleta.naranja
                                font { family: EstiloPanel.fuente; pixelSize: 11 }
                            }
                        }

                        // la pantalla en miniatura
                        Item {
                            id: marco
                            y: 32
                            width: parent.width
                            height: pantalla.height
                            scale: zonaCelda.containsMouse && !celda.esActivo ? 1.012 : 1
                            Behavior on scale { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }

                            RectangularShadow {
                                anchors.fill: parent
                                visible: EstiloPanel.efectos
                                radius: 14
                                offset.y: 8; blur: 26; spread: -8
                                color: celda.esActivo || celda.resaltada ? Qt.alpha(Paleta.naranja, .35) : Qt.alpha("black", .55)
                            }
                            Item {
                                id: pantalla
                                width: parent.width
                                height: width * vista.proporcion
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: mascara
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1
                                }

                                Image {
                                    anchors.fill: parent
                                    source: vista.fondo
                                    sourceSize.width: 640
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    asynchronous: true
                                    opacity: celda.esActivo ? 0.95 : 0.7
                                }
                                Rectangle { anchors.fill: parent; color: Qt.alpha(Paleta.fondo, celda.esActivo ? 0.12 : 0.35) }

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
                                Text {
                                    anchors.centerIn: parent
                                    visible: celda.ventanas.length === 0
                                    text: "Espacio vacío"
                                    color: Qt.alpha(Paleta.texto, .7)
                                    font { family: EstiloPanel.fuente; pixelSize: 12 }
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
                                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.breve } }
                                        Behavior on scale { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }
                                        Drag.active: arrastre.drag.active
                                        Drag.keys: ["ventana"]
                                        Drag.source: ventanita
                                        Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2

                                        Rectangle {
                                            id: tapa
                                            anchors.fill: parent
                                            radius: 7
                                            color: Paleta.seleccion
                                            clip: true
                                            ScreencopyView {
                                                anchors { fill: parent; margins: 1 }
                                                captureSource: vista.abierto && !EstadoEscritorio.privacidad ? ventanita.modelData.wayland : null
                                                live: true
                                            }
                                            // velo + título al pasar el ratón o al elegirla
                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                                height: Math.min(parent.height, 24)
                                                visible: (ventanita.encima || ventanita.elegida) && parent.height > 40
                                                gradient: Gradient {
                                                    GradientStop { position: 0; color: "transparent" }
                                                    GradientStop { position: 1; color: Qt.alpha("black", .75) }
                                                }
                                                Text {
                                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 5; leftMargin: 7 }
                                                    text: EstadoEscritorio.privacidad ? vista.nombreApp(ventanita.modelData) : ventanita.modelData.title
                                                    color: "white"
                                                    elide: Text.ElideRight
                                                    font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Medium }
                                                }
                                            }
                                        }
                                        Rectangle {   // borde (encima de la captura)
                                            anchors.fill: parent
                                            radius: 7
                                            color: "transparent"
                                            border.width: ventanita.elegida ? 2 : 1
                                            border.color: ventanita.elegida ? Paleta.naranja : ventanita.encima ? Qt.alpha(Paleta.texto, .6) : Qt.alpha(Paleta.texto, .14)
                                            Behavior on border.color { ColorAnimation { duration: EstiloPanel.breve } }
                                        }
                                        // icono de la app, en el centro
                                        Rectangle {
                                            anchors.centerIn: parent
                                            readonly property real lado: Math.min(34, Math.max(18, Math.min(parent.width, parent.height) * 0.32))
                                            width: lado; height: lado; radius: lado * 0.28
                                            color: Qt.alpha(Paleta.fondo, .72)
                                            border { width: 1; color: Qt.alpha(Paleta.texto, .12) }
                                            visible: parent.height > 30 && imagenIcono.status === Image.Ready
                                            opacity: ventanita.encima ? 0 : 1
                                            Behavior on opacity { NumberAnimation { duration: EstiloPanel.breve } }
                                            Image {
                                                id: imagenIcono
                                                anchors { fill: parent; margins: parent.lado * 0.14 }
                                                source: vista.icono(ventanita.modelData)
                                                sourceSize { width: 64; height: 64 }
                                                asynchronous: true
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
                                            width: 18; height: 18; radius: 9
                                            visible: ventanita.encima && !arrastre.drag.active && parent.width > 50
                                            color: equis.containsMouse ? Paleta.rojo : Qt.alpha("black", .65)
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
                            Rectangle { id: mascara; anchors.fill: pantalla; radius: 12; visible: false; layer.enabled: true }
                            Rectangle {   // filo
                                anchors.fill: pantalla
                                radius: 12
                                color: "transparent"
                                border.width: celda.esActivo || celda.resaltada ? 2 : 1
                                border.color: celda.esActivo ? Paleta.naranja
                                            : celda.resaltada ? Qt.alpha(Paleta.naranja, .6)
                                            : Qt.alpha(Paleta.texto, zonaCelda.containsMouse ? .3 : .12)
                                Behavior on border.color { ColorAnimation { duration: EstiloPanel.breve } }
                            }
                        }
                    }
                }

                // ── espacio nuevo: clic = ir; soltar = mandar allí la ventana ──
                Item {
                    width: vista.anchoCelda
                    height: vista.anchoCelda * vista.proporcion + 34
                    opacity: vista.abierto ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: EstiloPanel.entrada + vista.espacios.length * 35 } }
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
                        height: parent.height - 32
                        radius: 12
                        color: Qt.alpha(Paleta.texto, nuevoDestino.containsDrag ? .1 : nuevoZona.containsMouse ? .06 : .025)
                        border { width: nuevoDestino.containsDrag ? 2 : 1; color: nuevoDestino.containsDrag ? Paleta.naranja : Qt.alpha(Paleta.texto, nuevoZona.containsMouse ? .3 : .12) }
                        Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "+"
                                color: nuevoDestino.containsDrag || nuevoZona.containsMouse ? Paleta.naranja : EstiloPanel.tenue
                                font { family: EstiloPanel.fuente; pixelSize: 30; weight: Font.Light }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: nuevoDestino.containsDrag ? "Suelta para moverla aquí" : "Espacio nuevo"
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
                spacing: 18
                atajos: [["Enter", "ir"], ["← →", "elegir"], ["↑ ↓", "otro espacio"], ["1-9", "espacio"],
                         ["Ctrl 1-9", "mover"], ["Supr", "cerrar"], ["arrastrar", "mover"], ["Esc", "salir"]]
            }
        }
    }
}
