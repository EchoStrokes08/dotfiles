// Resumen del día: una tarjeta que aparece SOLA la primera vez que usas el equipo cada día
// (a partir de las 5:00) con el clima, los eventos de hoy, los recordatorios, la batería y las
// actualizaciones pendientes. Esc, Enter o clic fuera la cierran.
//   qs ipc call resumen mostrar      (también «Resumen del día» en el lanzador)
// La fecha del último resumen se guarda en ~/.local/state/quickshell/resumen-fecha.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Superpuesta {
    id: r
    espacio: "resumen"
    anchoTarjeta: Math.min(540, (screen?.width ?? 1280) - 40)
    panelCuidado: true
    opacidadTarjeta: 1
    acentoPanel: Paleta.azul
    alturaRelativa: 0.15

    SystemClock { id: reloj; precision: SystemClock.Minutes }
    readonly property string hoy: Qt.formatDate(reloj.date, "yyyy-MM-dd")
    readonly property var bateria: UPower.displayDevice
    readonly property real carga: bateria ? (bateria.percentage > 1 ? bateria.percentage / 100 : bateria.percentage) : 0
    function g(cp) { return String.fromCodePoint(cp); }

    // Eventos y recordatorios de HOY
    readonly property var eventosHoy: {
        reloj.date;
        const d0 = new Date(reloj.date.getFullYear(), reloj.date.getMonth(), reloj.date.getDate()), d1 = new Date(d0.getTime() + 86400000);
        return Eventos.lista.filter(e => e.inicio < d1 && e.fin > d0).slice(0, 5);
    }
    readonly property var recordatoriosHoy: {
        reloj.date;
        const d0 = new Date(reloj.date.getFullYear(), reloj.date.getMonth(), reloj.date.getDate()).getTime();
        return Recordatorios.lista.filter(x => x.cuando < d0 + 86400000).slice(0, 4);
    }

    // ── Una vez al día ──
    property string ultimo: "?"            // "?" = aún no se ha leído el archivo
    readonly property string ruta: Quickshell.env("HOME") + "/.local/state/quickshell/resumen-fecha"
    Process {
        id: leer
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null; true', "_", r.ruta]
        stdout: StdioCollector { onStreamFinished: r.ultimo = this.text.trim() }
    }
    function mostrar() {
        ultimo = hoy;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "_", ruta, hoy]);
        abierto = true;
        lista.forceActiveFocus();
    }
    Timer {   // espera a que haya clima y calendario; después comprueba cada minuto si ya es otro día
        interval: 20000; running: true; repeat: true
        onTriggered: {
            interval = 60000;
            if (r.ultimo !== "?" && r.ultimo !== r.hoy && reloj.date.getHours() >= 5 && !r.abierto) r.mostrar();
        }
    }

    component Linea: RowLayout {
        property int icono: 0
        property color tinte: Paleta.naranja
        property string titulo: ""
        property string detalle: ""
        Layout.fillWidth: true
        spacing: 12
        Text { text: r.g(icono); color: tinte; font { family: Paleta.fuente; pixelSize: 18 }
               Layout.preferredWidth: 24; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignTop }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { Layout.fillWidth: true; text: titulo; color: Paleta.texto; elide: Text.ElideRight
                   font { family: EstiloPanel.fuente; pixelSize: 13; bold: true } }
            Text { Layout.fillWidth: true; visible: detalle !== ""; text: detalle; color: EstiloPanel.tenue; wrapMode: Text.WordWrap
                   font { family: EstiloPanel.fuente; pixelSize: 11 } }
        }
    }

    ColumnLayout {
        id: lista
        width: parent.width
        spacing: 12
        focus: true
        Keys.onReturnPressed: r.abierto = false
        Keys.onEnterPressed: r.abierto = false
        Keys.onSpacePressed: r.abierto = false

        ColumnLayout {
            Layout.leftMargin: 8; Layout.topMargin: 4
            spacing: 2
            Text {
                readonly property int h: reloj.date.getHours()
                text: (h < 12 ? "Buenos días" : h < 20 ? "Buenas tardes" : "Buenas noches") + ", " + Quickshell.env("USER")
                color: Paleta.texto
                font { family: EstiloPanel.fuente; pixelSize: 27; weight: Font.DemiBold }
            }
            Text {
                text: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
                color: Paleta.naranja
                font { family: EstiloPanel.fuente; pixelSize: 12; capitalization: Font.Capitalize }
            }
        }
        Rectangle {
            visible: Continuidad.ultimo !== null
            Layout.fillWidth: true; implicitHeight: 66; radius: 10
            color: zonaContinuar.containsMouse || activeFocus ? Qt.alpha(Paleta.azul,.19) : Qt.alpha(Paleta.azul,.09)
            border { width: activeFocus ? 2 : 1; color: Qt.alpha(Paleta.azul,.3) }
            Behavior on color { ColorAnimation { duration: EstiloPanel.breve } }
            activeFocusOnTab: true
            function continuar() { r.abierto=false; Quickshell.execDetached(["qs","ipc","call","flujo","abrir","continuidad"]); }
            Keys.onReturnPressed: continuar()
            Column {
                anchors { fill: parent; margins: 10 } spacing: 5
                Text { width: parent.width; text: EstadoEscritorio.privacidad ? "Proyecto disponible para continuar" : "Continuar · " + (Continuidad.ultimo?.nombre || ""); elide: Text.ElideRight; color: Paleta.naranja; font { family:EstiloPanel.fuente; pixelSize:13; bold:true } }
                Text { width: parent.width; text: EstadoEscritorio.privacidad ? "Detalles ocultos por privacidad" : Continuidad.ultimo?.siguiente || "Revisa tu proyecto y elige Retomar"; elide:Text.ElideRight; color:Paleta.texto; font { family:EstiloPanel.fuente; pixelSize:11 } }
            }
            MouseArea { id: zonaContinuar; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.continuar() }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Paleta.texto, 0.1) }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 6
            spacing: 12

            Linea {
                visible: Clima.listo
                icono: 0xF0599; tinte: Paleta.amarillo
                titulo: `${Math.round(Clima.temp)}° ahora · ${Clima.texto(Clima.codigo)}`
                detalle: `Entre ${Math.round(Clima.min)}° y ${Math.round(Clima.max)}° en ${Clima.lugar}`
                         + (Clima.lluviaHoy >= 50 ? ` · lluvia ${Clima.lluviaHoy} %: lleva sombrilla` : Clima.lluviaHoy >= 20 ? ` · lluvia ${Clima.lluviaHoy} %` : " · sin lluvia a la vista")
            }
            Linea {
                icono: 0xF00ED; tinte: Paleta.azul
                titulo: r.eventosHoy.length === 0 ? "Sin eventos hoy" : r.eventosHoy.length === 1 ? "1 evento hoy" : r.eventosHoy.length + " eventos hoy"
                detalle: r.eventosHoy.map(e => (e.todoDia ? "Todo el día" : Qt.formatTime(e.inicio, "HH:mm")) + "  " + e.titulo).join("\n")
            }
            Linea {
                visible: r.recordatoriosHoy.length > 0
                icono: 0xF009A; tinte: Paleta.naranja
                titulo: r.recordatoriosHoy.length === 1 ? "1 recordatorio" : r.recordatoriosHoy.length + " recordatorios"
                detalle: r.recordatoriosHoy.map(x => Recordatorios.hora(x.cuando) + "  " + x.texto).join("\n")
            }
            Linea {
                icono: r.carga < 0.25 ? 0xF007A : 0xF0079
                tinte: r.carga < 0.25 && UPower.onBattery ? Paleta.rojo : Paleta.verde
                titulo: `Batería al ${Math.round(r.carga * 100)} %`
                detalle: UPower.onBattery ? (r.carga < 0.25 ? "Queda poca: busca el cargador" : "Sin cargador") : "Con el cargador puesto"
            }
            Linea {
                visible: Actualizaciones.listo
                icono: 0xF03D6
                tinte: Actualizaciones.noticias > 0 ? Paleta.rojo : Actualizaciones.total > 0 ? Paleta.naranja : Paleta.verde
                titulo: Actualizaciones.total === 0 ? "Sistema al día" : Actualizaciones.total + " paquetes por actualizar"
                detalle: (Actualizaciones.noticias > 0 ? `${Actualizaciones.noticias} noticia(s) de Arch sin leer: léelas antes de actualizar. ` : "")
                         + (Actualizaciones.vulnerables > 0 ? `${Actualizaciones.vulnerables} con arreglos de seguridad. ` : "")
                         + (Actualizaciones.total > 0 ? "Clic en el paquete de la barra para actualizar." : "")
            }
        }
    }
}
