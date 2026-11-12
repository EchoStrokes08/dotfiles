pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: flujo
    espacio: "flujo"
    anchoTarjeta: Math.min(920, (screen?.width ?? 1280) - 48)
    alturaRelativa: .06
    opacidadTarjeta: 1
    panelCuidado: true
    acentoPanel: Paleta.morado
    readonly property bool ocupado: accion.running
    property int pagina: 0
    property var proyectos: []
    property string proyectoId: ""
    property var plan: null
    property var seleccion: ({})
    property string mensaje: "Elige un proyecto o una acción para continuar."
    property string error: ""
    property bool cambios: false
    property bool cargando: false
    property bool confirmar: false
    property bool cerrarDespues: false
    property var tareas: ["comparar", "programar", "investigar", "concentrarse"]
    function abrir(nombre) { pagina=({continuidad:0,organizar:1,seleccion:2})[nombre] ?? 0; abierto=true; recarga.restart(); }
    function ejecutar(args, cerrar) {
        if (accion.running) return;
        error=""; mensaje="Procesando…"; cerrarDespues=cerrar===true;
        accion.command=[Quickshell.env("HOME")+"/.config/hypr/scripts/flujo.py",...args]; accion.running=true;
    }
    function cargarProyecto(p) {
        if (cambios) { error="Guarda o descarta tus cambios antes de cambiar de proyecto."; return; }
        cargando=true; proyectoId=p?.id || ""; nombre.text=p?.nombre || ""; siguiente.text=p?.siguiente || "";
        carpeta.text=p?.carpeta || ""; recursos.text=(p?.recursos || []).join("\n"); cargando=false; cambios=false; confirmar=false;
    }
    function guardar() { ejecutar(["proyecto","guardar","--id="+proyectoId,"--nombre="+nombre.text,"--siguiente="+siguiente.text,"--carpeta="+carpeta.text,"--recursos="+recursos.text]); }
    function actuar(nombre, cerrar) { ejecutar(["seleccion",nombre,"--token="+(seleccion.token || "")],cerrar); }
    onAbriendose: { error=""; recarga.restart(); }
    NumberAnimation { id: entradaPagina; target: cuerpo; property: "opacity"; from: .65; to: 1; duration: EstiloPanel.entrada; easing.type: Easing.OutCubic }
    onPaginaChanged: { if (abierto) entradaPagina.restart(); error=""; if (abierto) recarga.restart(); }
    Connections {
        target: flujo
        function onAbiertoChanged() {
        if (!flujo.abierto && flujo.seleccion.token) {
            Quickshell.execDetached([Quickshell.env("HOME")+"/.config/hypr/scripts/flujo.py","seleccion","limpiar","--token="+flujo.seleccion.token]);
            flujo.seleccion=({});
        }
        }
    }
    Timer {
        id: recarga
        interval: 120
        onTriggered: {
            if (accion.running) { restart(); return; }
            if (flujo.pagina===0) flujo.ejecutar(["proyecto","lista"]);
            if (flujo.pagina===1) { flujo.plan=null; flujo.mensaje="Previsualiza el cambio antes de aplicarlo al espacio actual."; }
            if (flujo.pagina===2) flujo.ejecutar(["seleccion","vista"]);
        }
    }
    Process {
        id: accion
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d=JSON.parse(text);
                    if (d.proyectos) {
                        flujo.proyectos=d.proyectos;
                        if (d.seleccion) { flujo.cambios=false; flujo.cargarProyecto(d.proyectos.find(p=>p.id===d.seleccion)); }
                        else if (!flujo.proyectoId && !flujo.cambios) flujo.cargarProyecto(d.proyectos.find(p=>p.id===d.ultimo));
                    }
                    if ("plan" in d) flujo.plan=d.plan;
                    if (d.seleccion && typeof d.seleccion === "object") flujo.seleccion=d.seleccion;
                    flujo.mensaje=d.mensaje || "Proyectos listos para continuar.";
                } catch(e) { flujo.error="No se pudo leer la respuesta."; }
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) { try { flujo.error=JSON.parse(text).error; } catch(e) { flujo.error="No se pudo completar la acción."; } } } }
        onExited: (codigo, estado) => { if (codigo===0 && flujo.cerrarDespues) flujo.abierto=false; }
    }
    component Boton: BotonPanel {
        tinte: Paleta.morado
        enabled: !accion.running
    }
    component Campo: CampoPanel {
        onTextEdited: flujo.cambios=true
    }
    ColumnLayout {
        id: cuerpo
        width: parent.width; spacing:14
        EncabezadoPanel {
            seccion: "FLUJO DE TRABAJO"
            titulo: ["Tu trabajo tiene memoria", "Un espacio para cada tarea", "De la selección a la acción"][flujo.pagina]
            simbolo: "󰃖"
            tinte: Paleta.morado
            onCerrar: flujo.abierto=false
        }
        NavegacionPanel {
            actual: flujo.pagina
            tinte: Paleta.morado
            opciones: [{texto:"Continuidad",icono:"󰃖"},{texto:"Organizar",icono:"󰕰"},{texto:"Selección",icono:"󰆏"}]
            onElegir: indice => flujo.pagina=indice
        }
        RowLayout {
            visible:flujo.pagina===0 && !EstadoEscritorio.privacidad
            Layout.fillWidth:true; Layout.preferredHeight:Math.min(350, (screen?.height ?? 720) - 290); spacing:16
            ColumnLayout {
                Layout.preferredWidth:220; Layout.fillHeight:true
                ListView {
                    Layout.fillWidth:true; Layout.fillHeight:true; clip:true; spacing:6
                    model:flujo.proyectos
                    Column {
                        anchors.centerIn: parent; width: parent.width-24; spacing: 12
                        visible: flujo.proyectos.length===0
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰃖"; color: Paleta.morado; font { family: Paleta.fuente; pixelSize: 40 } }
                        Text { width: parent.width; text: "Tu próximo comienzo"; color: Paleta.texto; horizontalAlignment: Text.AlignHCenter; font { family: EstiloPanel.fuente; pixelSize: 16; weight: Font.DemiBold } }
                        Text { width: parent.width; text: "Guarda un proyecto y deja una pista para tu próxima sesión."; color: EstiloPanel.tenue; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font { family: EstiloPanel.fuente; pixelSize: 12 } }
                    }
                    delegate:Boton { required property var modelData; width:ListView.view.width; text:modelData.nombre; destacado:flujo.proyectoId===modelData.id; onClicked:flujo.cargarProyecto(modelData) }
                }
                Boton { text:"+ Nuevo proyecto"; onClicked:flujo.cargarProyecto(null) }
                Boton { text:flujo.confirmar ? "Confirmar eliminación" : "Eliminar proyecto"; enabled:!!flujo.proyectoId && !accion.running; onClicked:{ if (!flujo.confirmar) flujo.confirmar=true; else { flujo.ejecutar(["proyecto","eliminar","--id="+flujo.proyectoId]); flujo.cambios=false; flujo.cargarProyecto(null); } } }
            }
            ColumnLayout {
                Layout.fillWidth:true; Layout.fillHeight:true; spacing:8
                Text { text: "PROYECTO"; color: EstiloPanel.tenue; font { family: EstiloPanel.fuente; pixelSize: 10; letterSpacing: 1.5; bold: true } }
                Campo { id:nombre; placeholderText:"Nombre del proyecto" }
                Campo { id:siguiente; placeholderText:"¿Cuál es tu siguiente paso?" }
                Campo { id:carpeta; placeholderText:"Carpeta del proyecto (opcional): ~/proyectos/…" }
                ScrollView {
                    Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                    TextArea { id:recursos; padding:12; placeholderTextColor:EstiloPanel.tenue; selectionColor:Qt.alpha(Paleta.morado,.35); placeholderText:"Recursos que quieres reabrir: una ruta absoluta por línea.\nSolo se guardan los que añadas aquí."; color:Paleta.texto; wrapMode:TextEdit.Wrap; font { family:EstiloPanel.fuente; pixelSize:12 } onTextChanged:if(!flujo.cargando) flujo.cambios=true; background:Rectangle { radius:8; color:Qt.alpha(Paleta.texto,.035) } }
                }
                Text { Layout.fillWidth:true; text:"Guardar recuerda las aplicaciones compatibles y sus espacios actuales. No lee títulos ni documentos."; wrapMode:Text.Wrap; color:EstiloPanel.tenue; font { family:EstiloPanel.fuente; pixelSize:10 } }
                RowLayout {
                    Layout.fillWidth:true
                    Boton { text:flujo.cambios ? "Guardar cambios" : "Guardar proyecto"; destacado:true; onClicked:flujo.guardar() }
                    Boton { text:"Retomar"; enabled:!!flujo.proyectoId && !flujo.cambios && !accion.running; onClicked:flujo.ejecutar(["proyecto","retomar","--id="+flujo.proyectoId],true) }
                    Boton { text:"Descartar"; enabled:flujo.cambios; onClicked:{ flujo.cambios=false; flujo.cargarProyecto(flujo.proyectos.find(p=>p.id===flujo.proyectoId)); } }
                }
            }
        }
        Item {
            visible:flujo.pagina===0 && EstadoEscritorio.privacidad
            Layout.fillWidth:true; Layout.preferredHeight:Math.min(350, (screen?.height ?? 720) - 290)
            Text { anchors.centerIn:parent; text:"Tus proyectos están ocultos mientras la privacidad está activa."; color:EstiloPanel.tenue; font { family:EstiloPanel.fuente; pixelSize:13 } }
        }
        ColumnLayout {
            visible:flujo.pagina===1
            Layout.fillWidth:true; Layout.preferredHeight:Math.min(350, (screen?.height ?? 720) - 290); spacing:14
            RowLayout {
                Layout.fillWidth:true
                ComboBox {
                    id:tarea; Layout.fillWidth:true; Layout.minimumWidth:0; implicitHeight:40
                    model:["Comparar documentos","Programar con un área principal","Investigar en columnas","Concentrarme en una ventana"]
                    onCurrentIndexChanged:flujo.plan=null
                    font { family:EstiloPanel.fuente; pixelSize:13 }
                    palette { text:Paleta.texto; buttonText:Paleta.texto; button:EstiloPanel.elevada; base:EstiloPanel.superficie; window:EstiloPanel.superficie; windowText:Paleta.texto; highlight:Qt.alpha(Paleta.morado,.3); highlightedText:Paleta.texto }
                    background:Rectangle { radius:10; color:EstiloPanel.superficie; border { width:tarea.activeFocus ? 2 : 1; color:tarea.activeFocus ? Paleta.morado : EstiloPanel.borde } }
                }
                Boton { Layout.fillWidth:false; Layout.preferredWidth:150; Layout.minimumWidth:140; text:"Previsualizar"; destacado:true; onClicked:flujo.ejecutar(["organizar","prever","--tarea="+flujo.tareas[tarea.currentIndex]]) }
            }
            Rectangle {
                Layout.fillWidth:true; Layout.fillHeight:true; radius:14; color:EstiloPanel.superficie; border { width:1; color:EstiloPanel.borde }
                Text { anchors { bottom:parent.bottom; bottomMargin:12; horizontalCenter:parent.horizontalCenter } text:flujo.plan ? "✓  Distribución verificada" : "VISTA ORIENTATIVA"; color:flujo.plan ? Paleta.verde : EstiloPanel.tenue; font { family:EstiloPanel.fuente; pixelSize:10; letterSpacing:1.5 } }
                Row {
                    anchors { fill:parent; margins:24; bottomMargin:40 } spacing:12
                    Repeater {
                        model: tarea.currentIndex===3 ? 1 : tarea.currentIndex===2 ? 3 : 2
                        Rectangle {
                            required property int index
                            width: tarea.currentIndex===1 ? (index===0 ? (parent.width-12)*.64 : (parent.width-12)*.36) : (parent.width-(tarea.currentIndex===3 ? 0 : tarea.currentIndex===2 ? 24 : 12))/(tarea.currentIndex===3 ? 1 : tarea.currentIndex===2 ? 3 : 2)
                            height:parent.height; radius:8
                            color:Qt.alpha(index===0 ? Paleta.naranja : Paleta.azul,.13)
                            border { width:1; color:Qt.alpha(index===0 ? Paleta.naranja : Paleta.azul,.45) }
                            Column {
                                anchors.centerIn:parent; spacing:10
                                Text { anchors.horizontalCenter:parent.horizontalCenter; text:tarea.currentIndex===3 ? "󰍉" : index===0 ? "󰅩" : "󰈙"; color:index===0 ? Paleta.naranja : Paleta.azul; font { family:Paleta.fuente; pixelSize:28 } }
                                Text { anchors.horizontalCenter:parent.horizontalCenter; text:tarea.currentIndex===3 ? "Foco" : index===0 ? "Principal" : "Apoyo"; color:Paleta.texto; font { family:EstiloPanel.fuente; pixelSize:14; weight:Font.DemiBold } }
                            }
                            Rectangle { anchors { left:parent.left; right:parent.right; top:parent.top; margins:12 } height:3; radius:2; color:Qt.alpha(index===0 ? Paleta.naranja : Paleta.azul,.4) }
                        }
                    }
                }
            }
            Text { Layout.fillWidth:true; text:flujo.plan ? "Espacio "+flujo.plan.workspace+" · "+flujo.plan.ventanas.length+" ventanas · "+flujo.plan.layout : "Esquema orientativo. Previsualiza para comprobar las ventanas del espacio actual."; color:EstiloPanel.tenue; wrapMode:Text.Wrap; font { family:EstiloPanel.fuente; pixelSize:12 } }
            RowLayout {
                Layout.fillWidth:true
                Boton { text:"Aplicar al espacio actual"; destacado:true; enabled:!!flujo.plan && !accion.running; onClicked:flujo.ejecutar(["organizar","aplicar","--token="+flujo.plan.token]) }
                Boton { text:"Volver al layout anterior"; onClicked:flujo.ejecutar(["organizar","volver"]) }
            }
            Text { Layout.fillWidth:true; text:"No cierra ni traslada ventanas. Volver recupera el layout, no la geometría exacta de su árbol."; color:EstiloPanel.tenue; wrapMode:Text.Wrap; font { family:EstiloPanel.fuente; pixelSize:10 } }
        }
        ColumnLayout {
            visible:flujo.pagina===2
            Layout.fillWidth:true; Layout.preferredHeight:Math.min(350, (screen?.height ?? 720) - 290); spacing:10
            Text { text:(flujo.seleccion.caracteres || 0)+" caracteres · "+(flujo.seleccion.origen || "sin captura"); color:Paleta.naranja; font { family:EstiloPanel.fuente; pixelSize:12; bold:true } }
            ScrollView {
                Layout.fillWidth:true; Layout.fillHeight:true; clip:true
                TextArea { padding:14; selectionColor:Qt.alpha(Paleta.morado,.35); text:EstadoEscritorio.privacidad ? "Vista previa oculta por privacidad" : flujo.seleccion.vista || "Selecciona un texto y pulsa SUPER+ALT+C para capturarlo antes de abrir el panel."; readOnly:true; selectByMouse:true; color:Paleta.texto; wrapMode:TextEdit.Wrap; font { family:EstiloPanel.fuente; pixelSize:12 } background:Rectangle { radius:8; color:Qt.alpha(Paleta.texto,.035) } }
            }
            GridLayout {
                Layout.fillWidth:true; columns:3
                Repeater {
                    model:[{id:"copiar",t:"Copiar"},{id:"nota",t:"Añadir a notas"},{id:"plantilla",t:"Guardar como plantilla"},{id:"mayusculas",t:"MAYÚSCULAS"},{id:"minusculas",t:"minúsculas"},{id:"limpiar-espacios",t:"Limpiar espacios"},{id:"resumir",t:"Resumir · IA local"},{id:"explicar",t:"Explicar · IA local"},{id:"traducir",t:"Traducir · IA local"}]
                    Boton { required property var modelData; text:modelData.t; simbolo: ["resumir","explicar","traducir"].includes(modelData.id) ? "󰚩" : ""; enabled:!!flujo.seleccion.token && !accion.running; onClicked:flujo.actuar(modelData.id,["resumir","explicar","traducir"].includes(modelData.id)) }
                }
            }
            RowLayout {
                Layout.fillWidth:true
                Boton { text:"Capturar de nuevo"; onClicked:flujo.ejecutar(["seleccion","capturar"]) }
                Boton { text:"Abrir URL o recurso"; enabled:!!flujo.seleccion.recurso && !accion.running; onClicked:flujo.actuar("abrir",true) }
            }
            Text { Layout.fillWidth:true; text:"Se usa la captura revisada. Solo la acción Abrir puede contactar una web; la IA configurada funciona en este equipo."; color:EstiloPanel.tenue; wrapMode:Text.Wrap; font { family:EstiloPanel.fuente; pixelSize:10 } }
        }
        EstadoPanel { mensaje:flujo.mensaje; error:flujo.error; ocupado:accion.running }
    }
}
