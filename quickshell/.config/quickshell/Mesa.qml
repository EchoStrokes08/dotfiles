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
    readonly property var paginas: ["Ventanas", "Plantillas", "Reunión", "Rutinas"]
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
        ejecutar(args, accion === "enfocar");
    }
    onPaginaChanged: {
        filtro.text = "";
        if (pagina < 2 && abierto) Qt.callLater(() => filtro.forceActiveFocus());
    }
    onAbriendose: {
        const monitor = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name);
        if (monitor) screen = monitor;
        Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces();
        filtro.text = ""; seleccion = "";
        ejecutar(["plantilla", "lista"]);
        Qt.callLater(() => filtro.forceActiveFocus());
    }
    Process {
        id: operacion
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.plantillas) mesa.plantillas = d.plantillas;
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
    component Boton: Button {
        id: b
        property bool acento: false
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 1
        implicitHeight: 36
        enabled: !operacion.running
        background: Rectangle {
            radius: 8
            color: Qt.alpha(Paleta.naranja, b.acento ? 0.24 : b.hovered ? 0.14 : 0.06)
            border.width: 1
            border.color: Qt.alpha(Paleta.naranja, b.activeFocus || b.acento ? 0.7 : 0.18)
        }
        contentItem: Text { text: b.text; color: b.enabled ? Paleta.texto : Paleta.gris; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font { family: Paleta.fuente; pixelSize: 12; bold: b.acento } }
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
        width: parent.width
        spacing: 16
        Item {
            Layout.fillWidth: true
            implicitHeight: 55
            Column {
                width: Math.max(0, parent.width - 110)
                spacing: 4
                Text { width: parent.width; text: "MESA DE TRABAJO"; color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 3 } }
                Text { width: parent.width; text: "Menos pasos. Más fluidez."; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 25; bold: true } }
            }
            Boton { id: cerrar; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 82; text: "Cerrar"; onClicked: mesa.abierto = false }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 408
            spacing: 20
            ColumnLayout {
                Layout.preferredWidth: 155
                Layout.fillHeight: true
                spacing: 8
                Repeater {
                    model: mesa.paginas
                    Boton {
                        required property string modelData
                        required property int index
                        text: modelData
                        acento: mesa.pagina === index
                        onClicked: { mesa.pagina = index; filtro.text = ""; }
                    }
                }
                Boton { text: "Proyectos y acciones →"; onClicked: Quickshell.execDetached(["qs","ipc","call","flujo","abrir","continuidad"]) }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: Reunion.activa ? "EN REUNIÓN\n" + Reunion.cuenta : "TU ESPACIO\n" + EstadoEscritorio.perfil
                    color: Reunion.activa ? Paleta.verde : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 12; bold: true }
                    lineHeight: 1.5
                }
                Text { text: "Ctrl+1…4 · pestañas\nEsc · cerrar"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 } lineHeight: 1.6 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                TextField {
                    id: filtro
                    visible: mesa.pagina < 2
                    Layout.fillWidth: true
                    implicitHeight: 38
                    placeholderText: mesa.pagina === 0 ? "Buscar ventanas por aplicación o título…" : "Buscar en tus plantillas…"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 13 }
                    background: Rectangle { radius: 8; color: Qt.alpha(Paleta.texto, .045); border.width: 1; border.color: filtro.activeFocus ? Paleta.naranja : Qt.alpha(Paleta.gris,.3) }
                    onTextChanged: { listaVentanas.currentIndex = 0; mesa.seleccion = ""; }
                    Keys.onDownPressed: { if (mesa.pagina === 1) { listaPlantillas.currentIndex = Math.min(mesa.textos.length-1, listaPlantillas.currentIndex+1); mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); return; } listaVentanas.currentIndex = Math.min(mesa.ventanas.length-1,listaVentanas.currentIndex+1); mesa.seleccion = mesa.ventanas[listaVentanas.currentIndex]?.address || ""; }
                    Keys.onUpPressed: { if (mesa.pagina === 1) { listaPlantillas.currentIndex = Math.max(0, listaPlantillas.currentIndex-1); mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); return; } listaVentanas.currentIndex = Math.max(0,listaVentanas.currentIndex-1); mesa.seleccion = mesa.ventanas[listaVentanas.currentIndex]?.address || ""; }
                    Keys.onReturnPressed: { if (mesa.pagina === 0) mesa.accionVentana("enfocar"); else mesa.cargar(mesa.textos[listaPlantillas.currentIndex]); }
                }
                ColumnLayout {
                    visible: mesa.pagina === 0
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                        ListView {
                            id: listaVentanas
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 5
                            model: mesa.ventanas
                            delegate: Rectangle {
                                id: fila
                                required property var modelData
                                required property int index
                                width: ListView.view.width; height: 55; radius: 8
                                color: Qt.alpha(Paleta.naranja, mesa.elegida?.address === modelData.address ? .16 : .035)
                                Column {
                                    anchors { fill: parent; margins: 9 } spacing: 3
                                    Text { width: parent.width; text: (fila.modelData.lastIpcObject?.class || "Aplicación") + (fila.modelData.workspace?.name === "special:aparcadas" ? " · aparcada" : " · espacio " + (fila.modelData.workspace?.id || "")); color: Paleta.naranja; elide: Text.ElideRight; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                                    Text { width: parent.width; text: EstadoEscritorio.privacidad ? "Título oculto por privacidad" : fila.modelData.title; color: Paleta.texto; elide: Text.ElideRight; font { family: Paleta.fuente; pixelSize: 11 } }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { mesa.seleccion = fila.modelData.address; listaVentanas.currentIndex = fila.index; } onDoubleClicked: mesa.accionVentana("enfocar") }
                            }
                            Label { anchors.centerIn: parent; visible: mesa.ventanas.length === 0; text: "No hay ventanas que coincidan"; color: Paleta.gris }
                        }
                        Rectangle {
                            Layout.preferredWidth: 195; Layout.fillHeight: true
                            radius: 10; color: Qt.alpha(Paleta.texto,.04); clip: true
                            ScreencopyView { anchors.fill: parent; captureSource: mesa.abierto && mesa.pagina === 0 && !EstadoEscritorio.privacidad ? mesa.elegida?.wayland ?? null : null; live: true }
                            Text { anchors.centerIn: parent; width: parent.width-20; visible: EstadoEscritorio.privacidad || !mesa.elegida?.wayland; text: EstadoEscritorio.privacidad ? "Vista previa oculta\nPrivacidad activa" : "Selecciona una ventana"; color: Paleta.gris; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; font { family: Paleta.fuente; pixelSize: 12 } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Boton { text: "Ir a la ventana"; acento: true; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("enfocar") }
                        Boton { text: mesa.elegida?.workspace?.name === "special:aparcadas" ? "Recuperar" : "Aparcar"; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("aparcar") }
                        Boton { text: "Flotante / mosaico"; enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("flotante") }
                    }
                    Text { text: "MOVER AL ESPACIO"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10; letterSpacing: 1 } }
                    RowLayout {
                        Layout.fillWidth: true
                        Repeater { model: 10; Boton { required property int index; text: String(index+1); enabled: mesa.elegida !== null && !operacion.running; onClicked: mesa.accionVentana("mover", index+1) } }
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
                        TextField { id: titulo; Layout.fillWidth: true; placeholderText: "Nombre de la plantilla"; color: Paleta.texto; font.family: Paleta.fuente; onTextEdited: mesa.cambios = true; background: Rectangle { color: Qt.alpha(Paleta.texto,.05); radius: 7 } }
                        ScrollView {
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            TextArea { id: texto; placeholderText: "Escribe un texto reutilizable…"; color: Paleta.texto; wrapMode: TextEdit.Wrap; font { family: Paleta.fuente; pixelSize: 12 } onTextChanged: if (!mesa.cargando) mesa.cambios = true; background: Rectangle { color: Qt.alpha(Paleta.texto,.035); radius: 7 } }
                        }
                        Text { text: "{{fecha}} · {{hora}} · {{usuario}}"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10 } }
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
                    Text { text: Reunion.activa ? "Estás en reunión" : "Presenta con tranquilidad"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 23; bold: true } }
                    Text { text: Reunion.activa ? Reunion.cuenta : mesa.duracion + ":00"; color: Reunion.activa ? Paleta.verde : Paleta.naranja; font { family: Paleta.fuente; pixelSize: 54; bold: true } }
                    Text { Layout.fillWidth: true; text: "Pausa el replay, oculta títulos y vistas previas, activa No molestar e impide la suspensión por inactividad durante el tiempo elegido."; color: Paleta.gris; wrapMode: Text.Wrap; font { family: Paleta.fuente; pixelSize: 12 } }
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
                    Text { Layout.fillWidth: true; text: "Al terminar se retira solo el motivo reunión. Tus otros modos y el estado del micrófono se conservan."; color: Paleta.gris; wrapMode: Text.Wrap; font { family: Paleta.fuente; pixelSize: 10 } }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    visible: mesa.pagina === 3
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
                    Text { text: "Prepara tu siguiente momento"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 23; bold: true } }
                    Text { Layout.fillWidth: true; text: "Guarda primero la distribución actual y prepara tus aplicaciones, apariencia y concentración en una acción."; color: Paleta.gris; wrapMode: Text.Wrap; font { family: Paleta.fuente; pixelSize: 12 } }
                    Repeater {
                        model: [
                            {id:"estudiar", titulo:"Estudiar · 25 minutos", detalle:"Sesión universidad + Lectura + concentración"},
                            {id:"programar", titulo:"Programar · 50 minutos", detalle:"Sesión programar + Cristal + concentración"},
                            {id:"descansar", titulo:"Descansar", detalle:"Sesión descanso + Cristal + terminar concentración"}
                        ]
                        Rectangle {
                            id: rutina
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 67; radius: 10
                            activeFocusOnTab: true
                            Keys.onReturnPressed: mesa.ejecutar(["rutina",modelData.id],true)
                            Keys.onSpacePressed: mesa.ejecutar(["rutina",modelData.id],true)
                            color: Qt.alpha(Paleta.naranja, zona.containsMouse || activeFocus ? .16 : .06)
                            border { width: 1; color: Qt.alpha(Paleta.naranja,.18) }
                            Column { anchors { fill: parent; margins: 12 } spacing: 5
                                Text { text: rutina.modelData.titulo; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                                Text { text: rutina.modelData.detalle; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11 } }
                            }
                            MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !operacion.running; onClicked: mesa.ejecutar(["rutina",rutina.modelData.id],true) }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "Puedes devolver las ventanas a sus espacios anteriores desde el checkpoint del centro del escritorio. No se cierran aplicaciones."; color: Paleta.gris; wrapMode: Text.Wrap; font { family: Paleta.fuente; pixelSize: 10 } }
                    Item { Layout.fillHeight: true }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 42; radius: 8
            color: Qt.alpha(mesa.error ? Paleta.rojo : Paleta.verde,.07)
            Text { anchors { fill: parent; margins: 10 } text: mesa.error || mesa.mensaje; color: mesa.error ? Paleta.rojo : Paleta.gris; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; font { family: Paleta.fuente; pixelSize: 11 } }
        }
    }
}
