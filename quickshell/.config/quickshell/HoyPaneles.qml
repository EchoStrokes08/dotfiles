// Agenda y calendario comparten fecha. Todo el contenido usa el desplazamiento de Hoy.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: paneles
    readonly property int columns: width >= 760 ? 2 : 1
    implicitHeight: columnas.implicitHeight
    property date fecha: new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate())
    property bool todos: false
    signal retomar()
    signal soltarFoco()
    SystemClock { id: reloj; precision: SystemClock.Minutes }
    readonly property date ahora: reloj.date
    readonly property date hoy: new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate())
    readonly property bool esHoy: fecha.getTime() === hoy.getTime()
    readonly property var siguiente: Eventos.proximos(1)[0]
    function estadoEvento(e) {
        if (!e.todoDia && e.inicio <= ahora && e.fin > ahora) return "Ahora · termina " + Qt.formatTime(e.fin,"HH:mm") + " · ";
        return e === siguiente ? "Próximo · " : "";
    }
    // Tareas vencidas: se ven hoy, con su fecha, en lugar de desaparecer
    readonly property var vencidas: esHoy ? Eventos.tareas.filter(t => t.fecha && t.fecha < hoy) : []
    // Con el día casi vacío, la columna enseña lo que viene en los tres días siguientes
    readonly property var proximosDias: {
        if (!esHoy || items.length >= 3) return [];
        const d1 = new Date(hoy.getTime() + 86400000), d4 = new Date(hoy.getTime() + 4 * 86400000);
        const vistos = new Set();
        return Eventos.lista.filter(e => e.inicio >= d1 && e.inicio < d4).filter(e => {
            if (e.repeticion === "diario" && !e.excepcion) {     // la rutina diaria ya se ve hoy
                if (vistos.has(e.serie || e.titulo)) return false;
                vistos.add(e.serie || e.titulo);
                return !diaEventos.some(h => (h.serie && h.serie === e.serie));
            }
            return true;
        }).slice(0, 5);
    }
    readonly property var diaEventos: Eventos.lista.filter(e => e.inicio < new Date(fecha.getFullYear(),fecha.getMonth(),fecha.getDate()+1) && e.fin > fecha)
    readonly property var diaTareas: Eventos.tareas.filter(t => !t.fecha || t.fecha.toDateString() === fecha.toDateString())
    readonly property var diaRecordatorios: Recordatorios.lista.filter(r => new Date(r.cuando).toDateString() === fecha.toDateString())
    readonly property var items: [
        ...diaEventos.map(e => ({titulo:e.titulo, detalle:paneles.estadoEvento(e) + (e.todoDia ? "Todo el día" : Qt.formatTime(e.inicio,"HH:mm") + " – " + Qt.formatTime(e.fin,"HH:mm")) + (e.excepcion ? " · excepción" : e.repeticion ? " · " + e.repeticion : ""), orden:e.inicio.getTime(), tipo:"evento", referencia:{tipo:"evento",id:e.uid || "",inicio:e.inicio.getTime(),calendario:e.calendario || ""}})),
        ...vencidas.map(t => ({titulo:t.titulo, detalle:"Tarea vencida · " + t.fecha.toLocaleDateString(Qt.locale("es_ES"), "d MMM yyyy"), orden:-1, tipo:"tarea", id:t.id, referencia:{tipo:"tarea",id:t.id}})),
        ...diaTareas.map(t => ({titulo:t.titulo, detalle:"Tarea", orden:0, tipo:"tarea", id:t.id, referencia:{tipo:"tarea",id:t.id}})),
        ...diaRecordatorios.map(r => ({titulo:r.texto, detalle:"Recordatorio · " + Recordatorios.hora(r.cuando), orden:r.cuando, tipo:"recordatorio", id:r.id, referencia:{tipo:"recordatorio",id:r.id}}))
    ].sort((a,b) => a.orden-b.orden)
    onFechaChanged: { todos = false; Qt.callLater(() => calendario.elegido = fecha); }
    function volverHoy() {
        const d = new Date(); fecha = new Date(d.getFullYear(),d.getMonth(),d.getDate());
        calendario.desfase = 0;
    }
    function crear(tarea) { formulario.esTarea = tarea; formulario.abrir(); }

    GridLayout {
        id: columnas
        width: parent.width
        columns: paneles.columns
        columnSpacing: 16
        rowSpacing: 12
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.alignment: Qt.AlignTop
        spacing: 12
        TarjetaPanel {
            Layout.fillWidth: true
            relleno: 16
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: "Agenda · " + Eventos.diaTexto(paneles.fecha)
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 16; bold: true }
                    elide: Text.ElideRight
                }
                BotonCompacto { visible: !paneles.esHoy; text: "Volver a hoy"; onClicked: paneles.volverHoy() }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                BotonCompacto { text: "+ Evento"; onClicked: paneles.crear(false) }
                BotonCompacto { text: "+ Tarea"; onClicked: paneles.crear(true) }
                Text { text: "Google Calendar / Tasks"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
            }
            Text {
                visible: paneles.items.length === 0
                Layout.fillWidth: true
                text: "Sin compromisos para este día."
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 13 }
            }
            Repeater {
                model: paneles.todos ? paneles.items : paneles.items.slice(0,4)
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle { implicitWidth: 4; implicitHeight: 32; radius: 4; color: modelData.detalle.startsWith("Tarea vencida") ? Paleta.aviso : modelData.tipo === "evento" ? Paleta.acento : Paleta.acento2 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text { Layout.fillWidth: true; text: EstadoEscritorio.privacidad ? "Compromiso privado" : modelData.titulo; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: detalleAgenda.abrir(modelData.referencia) }
                        }
                        Text { text: modelData.detalle; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    }
                    BotonCompacto {
                        visible: modelData.tipo === "tarea"
                        text: "Completar"
                        onClicked: Eventos.completar(modelData.id)
                    }
                }
            }
            BotonCompacto {
                visible: paneles.items.length > 4
                text: paneles.todos ? "Mostrar menos" : "Ver los " + paneles.items.length + " elementos"
                onClicked: paneles.todos = !paneles.todos
            }
        }
        TarjetaPanel {
            Layout.fillWidth: true
            visible: paneles.esHoy && paneles.items.length < 3
            relleno: 16
            Text { text: "Próximos días"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            Repeater {
                model: paneles.proximosDias
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 72
                        text: modelData.inicio.toDateString() === new Date(paneles.hoy.getTime() + 86400000).toDateString() ? "Mañana"
                            : modelData.inicio.toLocaleDateString(Qt.locale("es_ES"), "ddd d")
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12; bold: true; capitalization: Font.Capitalize }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0
                        Text { Layout.fillWidth: true; text: EstadoEscritorio.privacidad ? "Compromiso privado" : modelData.titulo; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                        Text { text: (modelData.todoDia ? "Todo el día" : Qt.formatTime(modelData.inicio,"HH:mm") + " – " + Qt.formatTime(modelData.fin,"HH:mm")) + (modelData.repeticion ? " · " + modelData.repeticion : ""); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                    }
                }
            }
            Text {
                visible: paneles.proximosDias.length === 0
                Layout.fillWidth: true
                text: "Nada fuera de tu rutina en los próximos tres días."
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 13 }
            }
            BotonCompacto { text: "Ver mañana"; onClicked: { const d = new Date(paneles.hoy.getTime() + 86400000); paneles.fecha = d; } }
        }
        TarjetaPanel {
            Layout.fillWidth: true
            visible: Continuidad.ultimo !== null
            relleno: 12
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Text { Layout.fillWidth: true; text: EstadoEscritorio.privacidad ? "Proyecto disponible" : "Continuar · " + (Continuidad.ultimo?.nombre ?? ""); elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                    Text { Layout.fillWidth: true; text: EstadoEscritorio.privacidad ? "Detalles ocultos" : Continuidad.ultimo?.siguiente || "Tu siguiente paso"; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                }
                BotonCompacto { text: "Retomar"; destacado: true; onClicked: paneles.retomar() }
            }
        }
    }
    ColumnLayout {
        Layout.preferredWidth: paneles.columns === 2 ? 300 : -1
        Layout.fillWidth: paneles.columns === 1
        Layout.minimumWidth: 252
        Layout.alignment: Qt.AlignTop
        spacing: 12
        TarjetaPanel {
            Layout.fillWidth: true
            relleno: 12
            Calendario {
                id: calendario
                Layout.alignment: Qt.AlignHCenter
                elegido: paneles.fecha
                onElegidoChanged: if (elegido.getTime() !== paneles.fecha.getTime()) paneles.fecha = elegido
            }
        }
        TarjetaPanel {
            Layout.fillWidth: true
            relleno: 12
            RowLayout {
                Layout.fillWidth: true
                Text { text: Clima.icono(Clima.codigo,Clima.deDia); color: Paleta.acento; font { family: Paleta.fuente; pixelSize: 26 } }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: Clima.listo ? Math.round(Clima.temp) + "° · " + Clima.texto(Clima.codigo) : "Cargando clima…"; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                    Text { text: Clima.lugar + " · lluvia " + Clima.lluviaHoy + "%"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
                }
            }
        }
        TarjetaPanel { Layout.fillWidth: true; relleno: 12; Tiempo { Layout.fillWidth: true; compacto: true } }
    }
    } // columnas
    Rectangle {
        visible: detalleAgenda.referencia !== null
        x: Math.max(0,(paneles.width-width)/2); y: 0
        width: Math.min(560,paneles.width); height: detalleAgenda.implicitHeight+32
        z: 20
        radius: EstiloPanel.rTarjeta; color: Paleta.fondo; border { width: 1; color: EstiloPanel.bordeFuerte }
        MouseArea { anchors.fill: parent }
        AccionesResultado {
            id: detalleAgenda
            anchors { fill: parent; margins: 16 }
            onCerrar: referencia=null
            onSoltarFoco: paneles.soltarFoco()
            onActualizado: Eventos.actualizar()
        }
    }
    // El formulario es modal dentro del área de Hoy y no altera las columnas.
    NuevoEvento {
        id: formulario
        parent: paneles
        x: Math.max(0,(paneles.width-width)/2); y: 0
        width: Math.min(420,paneles.width); height: 290
        z: 10
        fecha: paneles.fecha
    }
}
