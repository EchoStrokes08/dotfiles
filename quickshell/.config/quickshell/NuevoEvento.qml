// Formulario «nuevo evento o tarea» del dashboard: se abre ENCIMA del calendario (no empuja el resto
// del panel) con el ＋ de su cabecera. Crea el evento/tarea en tu Google Calendar / Google Tasks
// (Eventos.qml → scripts/gcal.py) el día elegido en el calendario. Esc o ✕ lo cierran.
//   Item { Calendario { id: c; onNuevo: f.abrir() }  NuevoEvento { id: f; anchors.fill: parent; fecha: c.elegido } }
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: n
    property date fecha: new Date()
    property bool abierto: false
    property bool esTarea: false
    property int minutos: 60
    readonly property var duraciones: [15, 30, 45, 60, 90, 120, 180]
    readonly property string horaNormal: {
        const t = hora.text.trim();
        if (!t) return "";
        const r = Eventos.interpretar(t + " x");
        return r && r.hora ? r.hora : "?";
    }
    readonly property bool valido: titulo.text.trim() !== "" && (esTarea || horaNormal !== "?")
    visible: abierto
    radius: 12
    color: Qt.alpha(Paleta.fondo, .97)
    border { width: 1; color: Qt.alpha(Paleta.acento, .35) }
    MouseArea { anchors.fill: parent }        // que los clics no lleguen al calendario de debajo

    function abrir() {
        if (!Eventos.conectado) { Eventos.conectar(); return; }
        abierto = true; titulo.forceActiveFocus();
    }
    function cerrar() { abierto = false; titulo.text = ""; hora.text = ""; }

    function guardar() {
        if (!valido || Eventos.ocupado) return;
        if (esTarea) Eventos.crearTarea(titulo.text.trim(), fecha);
        else Eventos.crearEvento(titulo.text.trim(), fecha, horaNormal, minutos);
        cerrar();
    }

    ColumnLayout {
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "Nuevo · " + Eventos.diaTexto(n.fecha)
            elide: Text.ElideRight
            color: Paleta.acento
            font { family: Paleta.fuente; pixelSize: 12; bold: true }
        }
        Text {
            text: "\uF00D"; color: Paleta.gris
            font { family: Paleta.mono; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: n.cerrar() }
        }
    }

        ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        // Evento | Tarea
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["Evento", "Tarea"]
                Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool activo: (index === 1) === n.esTarea
                    Layout.fillWidth: true
                    implicitHeight: 24
                    radius: 8
                    color: activo ? Qt.alpha(Paleta.acento, .25) : EstiloPanel.relleno
                    border { width: 1; color: activo ? Paleta.acento : "transparent" }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.activo ? Paleta.texto : Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 11; bold: parent.activo }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: n.esTarea = index === 1 }
                }
            }
        }

        CampoPanel {
            id: titulo
            implicitHeight: 32
            placeholderText: n.esTarea ? "¿Qué tienes que hacer?" : "Título del evento"
            font.pixelSize: 12
            onAccepted: n.guardar()
            Keys.onEscapePressed: n.cerrar()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !n.esTarea
            spacing: 4
            CampoPanel {
                id: hora
                implicitHeight: 32
                placeholderText: "hora (vacío = todo el día)"
                font.pixelSize: 11
                tinte: n.horaNormal === "?" ? Paleta.peligro : Paleta.acento
                onAccepted: n.guardar()
                Keys.onEscapePressed: n.cerrar()
            }
            Rectangle {   // duración: clic = siguiente, derecho = anterior
                visible: n.horaNormal !== "" && n.horaNormal !== "?"
                implicitWidth: 52; implicitHeight: 32; radius: 12
                color: EstiloPanel.relleno
                Text {
                    anchors.centerIn: parent
                    text: n.minutos < 60 ? n.minutos + " min" : (n.minutos / 60) + " h"
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 11 }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (e) => {
                        const i = n.duraciones.indexOf(n.minutos), l = n.duraciones.length;
                        n.minutos = n.duraciones[(i + (e.button === Qt.RightButton ? l - 1 : 1)) % l];
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: Eventos.diaTexto(n.fecha) + (n.esTarea ? "" : n.horaNormal && n.horaNormal !== "?" ? " · " + n.horaNormal : " · todo el día")
                elide: Text.ElideRight
                color: Paleta.gris
                font { family: Paleta.fuente; pixelSize: 11 }
                ToolTip.visible: diaRaton.containsMouse
                ToolTip.text: "Para otro día: ciérralo y elige el día en el calendario"
                MouseArea { id: diaRaton; anchors.fill: parent; hoverEnabled: true }
            }
            Rectangle {
                implicitWidth: 74; implicitHeight: 26; radius: 12
                color: n.valido ? Paleta.acento : EstiloPanel.rellenoActivo
                Text {
                    anchors.centerIn: parent
                    text: "Guardar"
                    color: n.valido ? Paleta.sobreAcento : Paleta.gris
                    font { family: Paleta.fuente; pixelSize: 11; bold: true }
                }
                MouseArea { anchors.fill: parent; cursorShape: n.valido ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: n.guardar() }
            }
        }
    }
    }
}
