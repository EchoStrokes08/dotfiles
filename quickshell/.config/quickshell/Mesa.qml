pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Superpuesta {
    id: mesa
    espacio: "mesa"
    anchoTarjeta: Math.min(960, (screen?.width ?? 1280) - 48)
    alturaRelativa: 0.06
    opacidadTarjeta: 1
    panelCuidado: true
    acentoPanel: Paleta.azul
    property int pagina: 0
    property var plantillas: []
    property string seleccion: ""
    property string plantillaId: ""
    property string mensaje: "Todo a mano. Elige una herramienta para empezar."
    property string error: ""
    property bool cerrarAlCompletar: false
    property bool cargando: false
    property bool cambios: false
    property bool confirmarBorrado: false
    property int duracion: 30
    // Rutinas: qué apps abre cada modo (mesa.py sesion …; las usa modulos/sesiones.lua)
    readonly property var rutinas: [
        {id:"estudiar", sesion:"universidad", nombre:"Estudiar", titulo:"Estudiar · 25 minutos", icono:"󰑴", color: Paleta.azul},
        {id:"programar", sesion:"programar", nombre:"Programar", titulo:"Programar · 50 minutos", icono:"󰅩", color: Paleta.morado},
        {id:"descansar", sesion:"descanso", nombre:"Descansar", titulo:"Descansar", icono:"󰒲", color: Paleta.verde}
    ]
    property var sesiones: ({})
    property string editando: ""          // id de sesión en edición ("" = ninguna)
    property var borrador: []
    property bool esperandoSesiones: false   // se abrió el editor antes de que llegaran los datos
    readonly property var instaladas: {
        const q = normalizar(buscarApp.text);
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && normalizar(e.name + " " + (e.genericName || "") + " " + e.id).includes(q))
            .sort((a, b) => a.name.localeCompare(b.name))
            .slice(0, 60);
    }
    function nombreDe(app) {
        if (app?.nombre && app.nombre !== app.clase) return app.nombre;
        return DesktopEntries.heuristicLookup(app?.clase || "")?.name || app?.nombre || app?.clase || "App";
    }
    function editar(r) {
        editando = r.sesion;
        esperandoSesiones = !sesiones[r.sesion];
        borrador = (sesiones[r.sesion]?.apps ?? []).map(a => Object.assign({}, a));
        buscarApp.text = "";
        error = "";
        mensaje = "Elige las apps de " + r.nombre + " y en qué espacio se abre cada una";
        Qt.callLater(() => buscarApp.forceActiveFocus());
    }
    function anadirApp(e) {
        if (borrador.length >= 12) { error = "Hasta 12 apps por modo"; return; }
        let cmd = (e.execString || "").replace(/\s*%[fFuUdDnNickvm]/g, "").replace(/\s+@@u?(?=\s|$)/g, "").replace(/%%/g, "%").trim();
        if (!cmd) { error = "Esa app no tiene un comando para abrirla"; return; }
        if (e.runInTerminal) cmd = "kitty -e " + cmd;
        const usados = borrador.map(a => a.ws);
        let ws = 1;
        while (usados.includes(ws) && ws < 10) ws++;
        borrador = [...borrador, { ws: ws, clase: e.startupClass || e.id, nombre: e.name, cmd: cmd }];
        error = "";
    }
    function quitarApp(i) { borrador = borrador.filter((_, k) => k !== i); }
    function cambiarEspacio(i, paso) {
        borrador = borrador.map((a, k) => k === i ? Object.assign({}, a, { ws: ((a.ws - 1 + paso + 10) % 10) + 1 }) : a);
    }
    function guardarApps() { ejecutar(["sesion", "guardar", "--id", editando, "--apps", JSON.stringify(borrador)]); }
    readonly property var paginas: ["Ventanas", "Plantillas", "Reunión", "Rutinas"]
    readonly property int espacioActual: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1
    function icono(t) {
        const e = DesktopEntries.heuristicLookup(t?.lastIpcObject?.class ?? "");
        return e ? Quickshell.iconPath(e.icon, true) : "";
    }
    function nombreApp(t) {
        const clase = t?.lastIpcObject?.class ?? "";
        return DesktopEntries.heuristicLookup(clase)?.name || clase.split(".").pop() || "Aplicación";
    }
    function normalizar(s) { return (s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, ""); }
    readonly property var ventanas: {
        const q = normalizar(filtro.text);
        return Hyprland.toplevels.values.filter(w => {
            const i = w.lastIpcObject;
            return w.address && ((w.workspace?.id ?? -1) > 0 || w.workspace?.name === "special:aparcadas")
                && normalizar((i?.class || "") + " " + (EstadoEscritorio.privacidad ? "" : w.title)).includes(q);
        }).sort((a,b) => Number(b.urgent) - Number(a.urgent) || Number(b.activated) - Number(a.activated) || (a.workspace?.id ?? 0) - (b.workspace?.id ?? 0));
    }
    readonly property var elegida: ventanas.find(w => w.address === seleccion) || ventanas[0] || null
    readonly property var textos: plantillas.filter(x => normalizar(x.titulo + " " + x.texto).includes(normalizar(filtro.text)))
    function abrir(que) {
        pagina = ({ventanas:0, plantillas:1, reunion:2, rutinas:3})[que] ?? 0;
        abierto = true;
    }
    function ejecutar(args, cerrar) {
        if (operacion.running) return;
        error = "";
        mensaje = "Procesando…";
        cerrarAlCompletar = cerrar === true;
        operacion.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/mesa.py", ...args];
        operacion.running = true;
    }
    function cargar(p) {
        if (cambios) { error = "Guarda o descarta los cambios antes de elegir otra plantilla."; return; }
        cargando = true;
        plantillaId = p?.id || ""; titulo.text = p?.titulo || ""; texto.text = p?.texto || "";
        cargando = false; cambios = false; confirmarBorrado = false;
    }
    function accionVentana(accion, ws) {
        if (!elegida) return;
        const args = ["ventana", accion, elegida.address];
        if (ws) args.push("--workspace", String(ws));
        // Enfocar: primero soltar el teclado (cerrar) y luego ir; ver Superpuesta.cerrarY
        if (accion === "enfocar")
            cerrarY(() => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/mesa.py", ...args]));
        else
            ejecutar(args, false);
    }
    NumberAnimation { id: entradaPagina; target: cuerpo; property: "opacity"; from: .65; to: 1; duration: EstiloPanel.entrada; easing.type: Easing.OutCubic }
    onPaginaChanged: {
        if (abierto) entradaPagina.restart();
        filtro.text = "";
        if (pagina < 2 && abierto) Qt.callLater(() => filtro.forceActiveFocus());
        editando = "";
        if (pagina === 3 && abierto) leerSesiones.running = true;
    }
    onAbriendose: {
        const monitor = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        if (monitor) screen = monitor;
        Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces();
        filtro.text = ""; seleccion = "";
        ejecutar(["plantilla", "lista"]);
        editando = "";
        leerSesiones.running = true;
        Qt.callLater(() => filtro.forceActiveFocus());
    }
    Process {
        id: leerSesiones
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/mesa.py", "sesion", "lista"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { mesa.sesiones = JSON.parse(text).sesiones; } catch (e) { return; }
                if (mesa.esperandoSesiones && mesa.editando) {
                    mesa.borrador = (mesa.sesiones[mesa.editando]?.apps ?? []).map(a => Object.assign({}, a));
                    mesa.esperandoSesiones = false;
                }
            }
        }
    }
    Process {
        id: operacion
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.plantillas) mesa.plantillas = d.plantillas;
                    if (d.sesiones) { mesa.sesiones = d.sesiones; if (d.mensaje && mesa.editando) mesa.editando = ""; }
                    mesa.mensaje = d.mensaje || (mesa.pagina === 0 ? mesa.ventanas.length + " ventanas disponibles · Enter para ir a la seleccionada" : "Biblioteca lista");
                    if (d.seleccion) { mesa.plantillaId = d.seleccion; mesa.cambios = false; }
                } catch (e) { mesa.error = "No se pudo leer el resultado de la acción."; }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) { try { mesa.error = JSON.parse(text).error; } catch(e) { mesa.error = "La acción no pudo completarse."; } } }
        }
        onExited: (codigo, estado) => {
            Hyprland.refreshToplevels();
            if (codigo === 0 && mesa.cerrarAlCompletar) mesa.abierto = false;
        }
    }
    component Boton: BotonPanel {
        property bool acento: false
        destacado: acento
        tinte: Paleta.azul
        enabled: !operacion.running
    }
    Repeater {
        model: 4
        Item {
            id: acceso
            required property int index
            Shortcut { sequence: "Ctrl+" + (acceso.index + 1); context: Qt.ApplicationShortcut; enabled: mesa.abierto; onActivated: mesa.pagina = acceso.index }
        }
    }
    ColumnLayout {
        id: cuerpo
        width: parent.width
        spacing: 16
        EncabezadoPanel {
            seccion: "MESA DE TRABAJO"
            titulo: ["Todo en su sitio", "Ideas que puedes reutilizar", "Tu momento de presentar", "Encuentra tu ritmo"][mesa.pagina]
            simbolo: "󰕰"
            tinte: Paleta.azul
            onCerrar: mesa.abierto = false
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(408, (screen?.height ?? 720) - 245)
            spacing: 20
            ColumnLayout {
                Layout.preferredWidth: 190
                Layout.maximumWidth: 190
                Layout.fillHeight: true
                spacing: 8
                NavegacionPanel {
                    vertical: true
                    tinte: Paleta.azul
                    actual: mesa.pagina
                    opciones: [{texto:"Ventanas",icono:"󰕰"},{texto:"Plantillas",icono:"󰈙"},{texto:"Reunión",icono:"󰍫"},{texto:"Rutinas",icono:"󰌌"}]
                    onElegir: indice => { mesa.pagina = indice; filtro.text = ""; }
                }
                Boton { text: "Proyectos →"; simbolo: "󰃖"; onClicked: Quickshell.execDetached(["qs","ipc","call","flujo","abrir","continuidad"]) }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: Reunion.activa ? "EN REUNIÓN\n" + Reunion.cuenta : "TU ESPACIO\n" + EstadoEscritorio.perfil
                    color: Reunion.activa ? Paleta.verde : EstiloPanel.tenue
                    font { family: EstiloPanel.fuente; pixelSize: 12; bold: true }
                    lineHeight: 1.5
                }
                PieAtajos { atajos: [["Ctrl 1…4", "pestañas"]] }
                PieAtajos { atajos: [["Esc", "cerrar"]] }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                CampoPanel {
                    id: filtro
                    tinte: Paleta.azul
                    visible: mesa.pagina < 2
                    placeholderText: mesa.pagina === 0 ? "Buscar aplicación o ventana…" : "Buscar en tus plantillas…"
                    onTextChanged: { listaVentanas.currentIndex = 0; mesa.seleccion = ""; }
                    Keys.onDownPressed: { if (mesa.pagina === 1) { listaPlantillas.currentIndex = Math.min(mesa.textos.length-1, listaPlantillas.currentIndex+1); mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); return; } listaVentanas.currentIndex = Math.min(mesa.ventanas.length-1,listaVentanas.currentIndex+1); mesa.seleccion = mesa.ventanas[listaVentanas.currentIndex]?.address || ""; }
                    Keys.onUpPressed: { if (mesa.pagina === 1) { listaPlantillas.currentIndex = Math.max(0, listaPlantillas.currentIndex-1); mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); return; } listaVentanas.currentIndex = Math.max(0,listaVentanas.currentIndex-1); mesa.seleccion = mesa.ventanas[listaVentanas.currentIndex]?.address || ""; }
                    Keys.onReturnPressed: { if (mesa.pagina === 0) mesa.accionVentana("enfocar"); else mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); }
                }
                ColumnLayout {
                    visible: mesa.pagina === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                        ListView {
                            id: listaVentanas
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            model: mesa.ventanas
                            delegate: Rectangle {
                                id: fila
                                required property var modelData
                                required property int index
                                readonly property bool marcada: mesa.elegida?.address === modelData.address
                                readonly property bool aparcada: modelData.workspace?.name === "special:aparcadas"
                                width: ListView.view.width; height: 58; radius: 12
                                color: marcada ? Qt.alpha(Paleta.azul, .15) : ventanaMouse.containsMouse ? EstiloPanel.elevada : EstiloPanel.tarjeta
                                border { width: 1; color: marcada ? Qt.alpha(Paleta.azul, .5) : EstiloPanel.bordeTarjeta }
                                Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
                                Rectangle {   // marca lateral de la elegida
                                    x: 0; anchors.verticalCenter: parent.verticalCenter
                                    width: 3; height: fila.marcada ? 26 : 0; radius: 2
                                    color: Paleta.azul
                                    Behavior on height { NumberAnimation { duration: EstiloPanel.breve; easing.type: Easing.OutCubic } }
                                }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 12
                                    Rectangle {
                                        implicitWidth: 36; implicitHeight: 36; radius: 10
                                        color: Qt.alpha(Paleta.texto, .06)
                                        border { width: 1; color: Qt.alpha(Paleta.texto, .08) }
                                        Image {
                                            id: iconoFila
                                            anchors { fill: parent; margins: 5 }
                                            source: mesa.icono(fila.modelData)
                                            sourceSize { width: 64; height: 64 }
                                            asynchronous: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: iconoFila.status !== Image.Ready
                                            text: mesa.nombreApp(fila.modelData).charAt(0).toUpperCase()
                                            color: Paleta.azul
                                            font { family: EstiloPanel.fuente; pixelSize: 15; bold: true }
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { Layout.fillWidth: true; text: EstadoEscritorio.privacidad ? "Título oculto por privacidad" : (fila.modelData.title || mesa.nombreApp(fila.modelData)); color: Paleta.texto; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12; weight: Font.Medium } }
                                        Text { Layout.fillWidth: true; text: mesa.nombreApp(fila.modelData) + (fila.modelData.urgent ? " · pide atención" : ""); color: fila.modelData.urgent ? Paleta.naranja : EstiloPanel.tenue; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 11 } }
                                    }
                                    Rectangle {   // espacio donde vive
                                        implicitWidth: Math.max(28, chip.implicitWidth + 14); implicitHeight: 24; radius: 8
                                        color: fila.aparcada ? Qt.alpha(Paleta.morado, .14) : (fila.modelData.workspace?.id === mesa.espacioActual ? Qt.alpha(Paleta.naranja, .16) : Qt.alpha(Paleta.texto, .06))
                                        Text {
                                            id: chip
                                            anchors.centerIn: parent
                                            text: fila.aparcada ? "󰏤 aparcada" : String(fila.modelData.workspace?.id ?? "")
                                            color: fila.aparcada ? Paleta.morado : (fila.modelData.workspace?.id === mesa.espacioActual ? Paleta.naranja : EstiloPanel.tenue)
                                            font { family: Paleta.fuente; pixelSize: 11; bold: true }
                                        }
                                    }
                                }
                                MouseArea { id: ventanaMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { mesa.seleccion = fila.modelData.address; listaVentanas.currentIndex = fila.index; } onDoubleClicked: mesa.accionVentana("enfocar") }
                            }
                            Column {
                                anchors.centerIn: parent
                                visible: mesa.ventanas.length === 0
                                spacing: 6
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰍉"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 28 } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No hay ventanas que coincidan"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                            }
                        }
                        // Vista previa de la elegida
                        Rectangle {
                            Layout.preferredWidth: 280; Layout.fillHeight: true
                            radius: 14; color: EstiloPanel.tarjeta
                            border { width: 1; color: EstiloPanel.bordeTarjeta }
                            ColumnLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 10
                                Item {
                                    id: lienzo
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: captura.width + 2; height: captura.height + 2
                                        radius: 9; color: "transparent"
                                        visible: captura.visible
                                        border { width: 1; color: Qt.alpha(Paleta.texto, .14) }
                                    }
                                    ScreencopyView {
                                        id: captura
                                        anchors.centerIn: parent
                                        visible: !EstadoEscritorio.privacidad && !!mesa.elegida?.wayland
                                        constraintSize: Qt.size(lienzo.width, lienzo.height)
                                        width: implicitWidth; height: implicitHeight
                                        captureSource: mesa.abierto && mesa.pagina === 0 && !EstadoEscritorio.privacidad ? mesa.elegida?.wayland ?? null : null
                                        live: true
                                    }
                                    Text { anchors.centerIn: parent; width: parent.width - 20; visible: !captura.visible; text: EstadoEscritorio.privacidad ? "󰈉\nVista previa oculta" : "Selecciona una ventana"; color: EstiloPanel.tenue; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; lineHeight: 1.4; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: mesa.elegida !== null
                                    spacing: 8
                                    Image { source: mesa.icono(mesa.elegida); sourceSize { width: 40; height: 40 } Layout.preferredWidth: 20; Layout.preferredHeight: 20; asynchronous: true }
                                    Text { Layout.fillWidth: true; text: mesa.nombreApp(mesa.elegida); color: Paleta.texto; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 13; weight: Font.DemiBold } }
                                    Text { text: mesa.elegida?.lastIpcObject?.floating ? "flotante" : "mosaico"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Boton { text: "Ir a la ventana"; simbolo: "󰁔"; acento: true; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("enfocar") }
                        Boton { text: mesa.elegida?.workspace?.name === "special:aparcadas" ? "Recuperar" : "Aparcar"; simbolo: mesa.elegida?.workspace?.name === "special:aparcadas" ? "󰐊" : "󰏤"; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("aparcar") }
                        Boton { text: "Flotante / mosaico"; simbolo: "󰖲"; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("flotante") }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: "MOVER A"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 } Layout.rightMargin: 6 }
                        Repeater {
                            model: 10
                            Rectangle {
                                id: hueco
                                required property int index
                                readonly property int n: index + 1
                                readonly property bool aqui: mesa.elegida?.workspace?.id === n
                                readonly property bool ocupado: Hyprland.toplevels.values.some(t => t.workspace?.id === n)
                                readonly property bool usable: mesa.elegida !== null && !operacion.running && !aqui
                                Layout.fillWidth: true; implicitHeight: 34; radius: 10
                                color: aqui ? Qt.alpha(Paleta.azul, .2) : zonaHueco.containsMouse && usable ? Qt.alpha(Paleta.azul, .12) : EstiloPanel.tarjeta
                                border { width: 1; color: aqui ? Qt.alpha(Paleta.azul, .6) : zonaHueco.containsMouse && usable ? Qt.alpha(Paleta.azul, .4) : EstiloPanel.bordeTarjeta }
                                opacity: mesa.elegida ? 1 : .45
                                Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
                                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: hueco.ocupado ? -3 : 0; text: hueco.n; color: hueco.aqui ? Paleta.azul : Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: hueco.aqui } }
                                Rectangle { visible: hueco.ocupado; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 } width: 4; height: 4; radius: 2; color: hueco.aqui ? Paleta.azul : EstiloPanel.tenue }
                                MouseArea { id: zonaHueco; anchors.fill: parent; hoverEnabled: true; enabled: hueco.usable; cursorShape: Qt.PointingHandCursor; onClicked: mesa.accionVentana("mover", hueco.n) }
                            }
                        }
                    }
                }
                RowLayout {
                    visible: mesa.pagina === 1
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 14
                    ColumnLayout {
                        Layout.preferredWidth: 190; Layout.fillHeight: true
                        ListView {
                            id: listaPlantillas
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
                            model: mesa.textos
                            delegate: Boton { required property var modelData; width: ListView.view.width; text: modelData.titulo; acento: mesa.plantillaId === modelData.id; onClicked: mesa.cargar(modelData) }
                        }
                        Boton { text: "+ Nueva plantilla"; onClicked: mesa.cargar(null) }
                        Boton { text: "Guardar portapapeles"; onClicked: mesa.ejecutar(["plantilla", "capturar", "--titulo=" + (titulo.text || "Texto guardado")]) }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                        CampoPanel { id: titulo; placeholderText: "Nombre de la plantilla"; onTextEdited: mesa.cambios = true }
                        ScrollView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            TextArea { id: texto; padding: 12; placeholderTextColor: EstiloPanel.tenue; selectionColor: Qt.alpha(Paleta.azul,.35); placeholderText: "Escribe un texto reutilizable…"; color: Paleta.texto; wrapMode: TextEdit.Wrap; font { family: EstiloPanel.fuente; pixelSize: 12 } onTextChanged: if (!mesa.cargando) mesa.cambios = true; background: Rectangle { color: Qt.alpha(Paleta.texto,.035); radius: 7 } }
                        }
                        Text { text: "{{fecha}} · {{hora}} · {{usuario}}"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                        RowLayout {
                            Layout.fillWidth: true
                            Boton { text: mesa.cambios ? "Guardar cambios" : "Guardar"; acento: true; onClicked: mesa.ejecutar(["plantilla","guardar","--id=" + mesa.plantillaId,"--titulo=" + titulo.text,"--texto=" + texto.text]) }
                            Boton { text: "Copiar"; enabled: !!mesa.plantillaId && !mesa.cambios && !operacion.running; onClicked: mesa.ejecutar(["plantilla","copiar","--id",mesa.plantillaId]) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Boton { text: mesa.confirmarBorrado ? "Confirmar borrado" : "Eliminar"; enabled: !!mesa.plantillaId && !operacion.running; onClicked: { if (!mesa.confirmarBorrado) mesa.confirmarBorrado = true; else { mesa.ejecutar(["plantilla","eliminar","--id",mesa.plantillaId]); mesa.cambios = false; mesa.cargar(null); } } }
                            Boton { text: "Descartar cambios"; enabled: mesa.cambios; onClicked: { mesa.cambios = false; mesa.cargar(mesa.plantillas.find(p => p.id === mesa.plantillaId)); } }
                        }
                    }
                }
                ColumnLayout {
                    visible: mesa.pagina === 2
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 15
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 119; radius: 14
                        color: Qt.alpha(Reunion.activa ? Paleta.verde : Paleta.azul,.075)
                        border { width: 1; color: Qt.alpha(Reunion.activa ? Paleta.verde : Paleta.azul,.22) }
                        RowLayout {
                            anchors { fill: parent; margins: 16; bottomMargin: 22 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: Reunion.activa ? "ESTÁS EN REUNIÓN" : "PRESENTA CON TRANQUILIDAD"; color: Reunion.activa ? Paleta.verde : Paleta.azul; font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.5 } }
                                Text { text: "Un espacio sin interrupciones"; color: Paleta.texto; font { family: EstiloPanel.fuente; pixelSize: 18; weight: Font.DemiBold } }
                                Text { text: "Privacidad · No molestar · Replay en pausa"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 11 } }
                            }
                            Text { text: Reunion.activa ? Reunion.cuenta : mesa.duracion + ":00"; color: Reunion.activa ? Paleta.verde : Paleta.azul; font { family: Paleta.fuente; pixelSize: 43; weight: Font.Light } }
                        }
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 12 }
                            height: 3; radius: 2; color: Qt.alpha(Paleta.azul,.13)
                            Rectangle {
                                width: parent.width * (Reunion.activa ? Math.min(1, Reunion.restante / Math.max(1, Number(Reunion.datos.minutos || 30) * 60)) : 1)
                                height: 3; radius: 2; color: Reunion.activa ? Paleta.verde : Paleta.azul
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "Pausa el replay, oculta títulos y vistas previas, activa No molestar e impide la suspensión por inactividad durante el tiempo elegido."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater { model: [15,30,60,90]; Boton { required property int modelData; text: modelData + " min"; acento: mesa.duracion === modelData; enabled: !Reunion.activa; onClicked: mesa.duracion = modelData } }
                    }
                    Boton { text: Reunion.activa ? "Terminar reunión ahora" : "Comenzar reunión"; acento: true; onClicked: mesa.ejecutar(Reunion.activa ? ["reunion","terminar"] : ["reunion","iniciar","--minutos",String(mesa.duracion)]) }
                    RowLayout {
                        Layout.fillWidth: true
                        Boton { text: "Silenciar micrófono"; onClicked: mesa.ejecutar(["microfono","silenciar"]) }
                        Boton { text: "Activar micrófono"; onClicked: mesa.ejecutar(["microfono","activar"]) }
                    }
                    Text { Layout.fillWidth: true; text: "Al terminar se retira solo el motivo reunión. Tus otros modos y el estado del micrófono se conservan."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                    Item { Layout.fillHeight: true }
                }
                // ── Rutinas: tarjetas para empezar cada modo ──────────────────
                ColumnLayout {
                    visible: mesa.pagina === 3 && mesa.editando === ""
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    Text { text: "Prepara tu siguiente momento"; color: Paleta.texto; font { family: EstiloPanel.fuente; pixelSize: 21; bold: true } }
                    Text { Layout.fillWidth: true; text: "Guarda la distribución actual y prepara apps, apariencia y concentración en una acción. Con «Apps» eliges qué se abre."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                    Repeater {
                        model: mesa.rutinas
                        Rectangle {
                            id: rutina
                            required property var modelData
                            readonly property var datos: mesa.sesiones[modelData.sesion] ?? { apps: [], personalizada: false }
                            Layout.fillWidth: true; implicitHeight: 84; radius: 14
                            activeFocusOnTab: true
                            Keys.onReturnPressed: mesa.ejecutar(["rutina", modelData.id], true)
                            Keys.onSpacePressed: mesa.ejecutar(["rutina", modelData.id], true)
                            color: Qt.alpha(modelData.color, zona.containsMouse || activeFocus ? .17 : .07)
                            Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
                            border { width: activeFocus ? 2 : 1; color: Qt.alpha(modelData.color, zona.containsMouse ? .45 : .22) }
                            MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !operacion.running; onClicked: mesa.ejecutar(["rutina", rutina.modelData.id], true) }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                                spacing: 14
                                Rectangle {
                                    implicitWidth: 46; implicitHeight: 46; radius: 13
                                    color: Qt.alpha(rutina.modelData.color, .16)
                                    border { width: 1; color: Qt.alpha(rutina.modelData.color, .35) }
                                    Text { anchors.centerIn: parent; text: rutina.modelData.icono; color: rutina.modelData.color; font { family: Paleta.fuente; pixelSize: 23 } }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text { Layout.fillWidth: true; text: rutina.modelData.titulo; color: Paleta.texto; font { family: EstiloPanel.fuente; pixelSize: 14; bold: true } }
                                    // las apps que abrirá, con su espacio
                                    Row {
                                        spacing: 5
                                        Repeater {
                                            model: rutina.datos.apps
                                            Rectangle {
                                                id: chipApp
                                                required property var modelData
                                                width: filaChip.implicitWidth + 12; height: 22; radius: 7
                                                color: Qt.alpha(Paleta.texto, .07)
                                                Row {
                                                    id: filaChip
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    IconoApp { anchors.verticalCenter: parent.verticalCenter; app: chipApp.modelData; lado: 14 }
                                                    Text { anchors.verticalCenter: parent.verticalCenter; text: chipApp.modelData.ws; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 10; bold: true } }
                                                }
                                            }
                                        }
                                        Text {
                                            visible: rutina.datos.apps.length === 0
                                            text: "Sin apps · solo apariencia y concentración"
                                            color: EstiloPanel.tenue
                                            font { family: EstiloPanel.fuente; pixelSize: 11 }
                                        }
                                    }
                                }
                                Boton {
                                    Layout.fillWidth: false; Layout.preferredWidth: 92
                                    text: "Apps"; simbolo: "󰏫"
                                    tinte: rutina.modelData.color
                                    onClicked: mesa.editar(rutina.modelData)
                                }
                            }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "Puedes devolver las ventanas a sus espacios anteriores desde el checkpoint del centro del escritorio. No se cierran aplicaciones."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                    Item { Layout.fillHeight: true }
                }

                // ── Editor: qué apps abre un modo y en qué espacio ────────────
                ColumnLayout {
                    visible: mesa.pagina === 3 && mesa.editando !== ""
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                    readonly property var r: mesa.rutinas.find(x => x.sesion === mesa.editando) ?? mesa.rutinas[0]
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Boton { Layout.fillWidth: false; Layout.preferredWidth: 40; text: ""; simbolo: "󰁍"; onClicked: mesa.editando = "" }
                        Text { text: parent.parent.r.icono; color: parent.parent.r.color; font { family: Paleta.fuente; pixelSize: 20 } }
                        Text { Layout.fillWidth: true; text: "Apps de " + parent.parent.r.nombre; color: Paleta.texto; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 18; bold: true } }
                        Rectangle {
                            visible: mesa.sesiones[mesa.editando]?.personalizada ?? false
                            implicitWidth: etiquetaPropia.implicitWidth + 16; implicitHeight: 22; radius: 7
                            color: Qt.alpha(Paleta.azul, .14)
                            Text { id: etiquetaPropia; anchors.centerIn: parent; text: "a tu medida"; color: Paleta.azul; font { family: EstiloPanel.fuente; pixelSize: 10; bold: true } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 12
                        // izquierda: las elegidas
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            radius: 14; color: EstiloPanel.tarjeta
                            border { width: 1; color: EstiloPanel.bordeTarjeta }
                            ColumnLayout {
                                anchors { fill: parent; margins: 10 }
                                spacing: 6
                                Text { text: "SE ABRIRÁN"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10; weight: Font.Bold; letterSpacing: 1.2 } }
                                ListView {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true; spacing: 5
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: mesa.borrador
                                    delegate: Rectangle {
                                        id: elegidaApp
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width; height: 46; radius: 10
                                        color: EstiloPanel.elevada
                                        border { width: 1; color: EstiloPanel.bordeTarjeta }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                                            spacing: 8
                                            IconoApp { app: elegidaApp.modelData; lado: 24 }
                                            Text { Layout.fillWidth: true; text: mesa.nombreDe(elegidaApp.modelData); color: Paleta.texto; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12; weight: Font.Medium } }
                                            // espacio: ‹ n ›
                                            Text { text: "esp."; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10 } }
                                            Rectangle {
                                                implicitWidth: 74; implicitHeight: 28; radius: 8
                                                color: Qt.alpha(Paleta.texto, .06)
                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: 0
                                                    Text { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter; text: "‹"; color: menos.containsMouse ? Paleta.azul : EstiloPanel.tenue; font.pixelSize: 16
                                                        MouseArea { id: menos; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mesa.cambiarEspacio(elegidaApp.index, -1) } }
                                                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: elegidaApp.modelData.ws; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                                                    Text { Layout.preferredWidth: 22; horizontalAlignment: Text.AlignHCenter; text: "›"; color: mas.containsMouse ? Paleta.azul : EstiloPanel.tenue; font.pixelSize: 16
                                                        MouseArea { id: mas; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mesa.cambiarEspacio(elegidaApp.index, 1) } }
                                                }
                                            }
                                            Rectangle {
                                                implicitWidth: 28; implicitHeight: 28; radius: 8
                                                color: quitar.containsMouse ? Qt.alpha(Paleta.rojo, .18) : "transparent"
                                                Text { anchors.centerIn: parent; text: "󰅖"; color: quitar.containsMouse ? Paleta.rojo : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 14 } }
                                                MouseArea { id: quitar; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mesa.quitarApp(elegidaApp.index) }
                                            }
                                        }
                                    }
                                    Text { anchors.centerIn: parent; visible: mesa.borrador.length === 0; width: parent.width - 30; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: "Ninguna app: este modo solo cambiará la apariencia y la concentración.\nAñade apps desde la derecha."; color: EstiloPanel.tenue; lineHeight: 1.3; font { family: EstiloPanel.fuente; pixelSize: 11 } }
                                }
                            }
                        }
                        // derecha: buscar entre las instaladas
                        Rectangle {
                            Layout.preferredWidth: 250; Layout.fillHeight: true
                            radius: 14; color: EstiloPanel.tarjeta
                            border { width: 1; color: EstiloPanel.bordeTarjeta }
                            ColumnLayout {
                                anchors { fill: parent; margins: 10 }
                                spacing: 6
                                CampoPanel { id: buscarApp; tinte: Paleta.azul; implicitHeight: 36; placeholderText: "󰍉  Añadir app…"; Keys.onReturnPressed: if (mesa.instaladas.length) mesa.anadirApp(mesa.instaladas[0]) }
                                ListView {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true; spacing: 3
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: mesa.instaladas
                                    delegate: Rectangle {
                                        id: instalada
                                        required property var modelData
                                        width: ListView.view.width; height: 38; radius: 9
                                        color: zonaInstalada.containsMouse ? Qt.alpha(Paleta.azul, .13) : "transparent"
                                        Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            spacing: 9
                                            Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: Quickshell.iconPath(instalada.modelData.icon, true); sourceSize { width: 44; height: 44 } asynchronous: true }
                                            Text { Layout.fillWidth: true; text: instalada.modelData.name; color: Paleta.texto; elide: Text.ElideRight; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                                            Text { text: "+"; visible: zonaInstalada.containsMouse; color: Paleta.azul; font { pixelSize: 16; bold: true } }
                                        }
                                        MouseArea { id: zonaInstalada; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mesa.anadirApp(instalada.modelData) }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Boton { text: "Guardar"; simbolo: "󰄬"; acento: true; onClicked: mesa.guardarApps() }
                        Boton { text: "Restaurar de serie"; simbolo: "󰑓"; enabled: (mesa.sesiones[mesa.editando]?.personalizada ?? false) && !operacion.running; onClicked: mesa.ejecutar(["sesion", "restaurar", "--id", mesa.editando]) }
                        Boton { text: "Cancelar"; onClicked: mesa.editando = "" }
                    }
                }
            }
        }
        EstadoPanel { mensaje: mesa.mensaje; error: mesa.error; ocupado: operacion.running }
    }
}
