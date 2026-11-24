// Almacenamiento del SSD dentro de Brújula › Salud (scripts/almacenamiento.py).
//   · barra del disco por categorías (lo libre es el fondo) y leyenda con la acción de cada una
//   · limpiar solo lo que se regenera; lo de administrador se abre en una terminal visible
//   · archivos grandes de tus carpetas, con «Abrir carpeta» y «A la papelera» (recuperable)
// Con privacidad activa no se muestran nombres de archivos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

TarjetaPanel {
    id: alm
    property var datos: null
    property var grandes: []
    property bool verGrandes: false
    property string mensaje: ""
    property bool error: false
    property string confirmando: ""            // id de la categoría que pide confirmación
    signal ejecutar(var comando)               // SaludPanel → Brújula lanza la orden (terminal, app o carpeta)
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/almacenamiento.py"
    // Un color fijo por categoría (no por posición): la misma cosa se ve igual aunque cambie el orden
    readonly property var colores: ({ juegos: Paleta.serie[4], paquetes: Paleta.serie[0], apps: Paleta.serie[5], cache: Paleta.serie[1],
        descargas: Paleta.serie[3], firefox: Paleta.serie[2], papelera: Paleta.serie[6], registro: Paleta.serie[7], videos: EstiloPanel.tenue })
    readonly property var cats: datos?.categorias ?? []
    relleno: 16
    espaciado: 12

    function gb(b) {
        if (b >= 1e9) return (b / 1e9).toFixed(b >= 1e10 ? 0 : 1).replace(".", ",") + " GB";
        if (b >= 1e6) return Math.round(b / 1e6) + " MB";
        return Math.max(1, Math.round(b / 1e3)) + " KB";
    }
    function color(i, c) { return alm.colores[c.id] ?? EstiloPanel.velo; }
    function revisar() { if (!lector.running) lector.running = true; if (verGrandes && !lectorGrandes.running) lectorGrandes.running = true; }
    function orden(args) {
        if (accion.running) return;
        alm.error = false; alm.mensaje = "Aplicando…"; alm.confirmando = "";
        accion.command = [alm.script, ...args]; accion.running = true;
    }
    function actuar(c) {
        const a = c.accion;
        if (!a) return;
        if (a.confirmar && alm.confirmando !== c.id) { alm.confirmando = c.id; return; }
        if (a.tipo === "limpiar") alm.orden(["limpiar", a.orden]);
        else if (a.tipo === "terminal") alm.ejecutar(["kitty", "--title", "Almacenamiento", "-e", "sh", "-c", a.orden]);
        else if (a.tipo === "app") alm.ejecutar([a.orden]);
        else if (a.tipo === "abrir") alm.ejecutar(["xdg-open", a.orden]);
        alm.confirmando = "";
    }
    Component.onCompleted: revisar()

    Process {
        id: lector
        command: [alm.script, "estado"]
        stdout: StdioCollector { onStreamFinished: { try { alm.datos = JSON.parse(text); } catch (e) { alm.error = true; alm.mensaje = "No se pudo medir el disco."; } } }
    }
    Process {
        id: lectorGrandes
        command: [alm.script, "grandes", "12"]
        stdout: StdioCollector { onStreamFinished: { try { alm.grandes = JSON.parse(text); } catch (e) { alm.grandes = []; } } }
    }
    Process {
        id: accion
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); alm.error = r.ok === false; alm.mensaje = r.error || r.mensaje || "Hecho."; }
                catch (e) { alm.error = true; alm.mensaje = "No se pudo completar."; }
            }
        }
        onExited: alm.revisar()
    }

    // ── Cabecera ─────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { text: "Almacenamiento"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                text: !alm.datos ? "Midiendo…" : (alm.datos.disco.modelo ? alm.datos.disco.modelo + " · " : "") + (alm.datos.disco.fs || "")
                color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
        ColumnLayout {
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignRight
                text: alm.datos ? alm.gb(alm.datos.disco.libre) + " libres" : ""
                color: (alm.datos?.disco.libre ?? 1) / (alm.datos?.disco.total ?? 1) < .1 ? Paleta.aviso : Paleta.texto
                font { family: Paleta.fuente; pixelSize: 20; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignRight
                text: alm.datos ? alm.gb(alm.datos.disco.usado) + " usados de " + alm.gb(alm.datos.disco.total) : ""
                color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
    }

    // ── Barra del disco: cada categoría, lo libre al final ───────────
    Rectangle {
        id: pista
        Layout.fillWidth: true
        implicitHeight: 16; radius: height / 2
        color: EstiloPanel.relleno
        border { width: 1; color: EstiloPanel.borde }
        clip: true
        Row {
            anchors { fill: parent; margins: 1 }
            Repeater {
                model: alm.cats
                Rectangle {
                    required property var modelData
                    required property int index
                    height: pista.height - 2
                    width: alm.datos ? (pista.width - 2) * modelData.bytes / alm.datos.disco.total : 0
                    color: alm.color(index, modelData)
                    Behavior on width { NumberAnimation { duration: EstiloPanel.lento; easing.type: Easing.OutCubic } }
                }
            }
        }
    }

    // ── Leyenda con acciones ─────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: alm.width >= 640 ? 2 : 1
        columnSpacing: 16; rowSpacing: 4
        Repeater {
            model: alm.cats
            Item {
                id: fila
                required property var modelData
                required property int index
                readonly property var acc: modelData.accion ?? null
                readonly property bool bloqueada: !!acc?.requiere_cerrado && (alm.datos?.firefox_abierto ?? false)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 48
                HoverHandler { id: sobre }
                Rectangle { anchors.fill: parent; radius: EstiloPanel.rControl; color: sobre.hovered ? EstiloPanel.relleno : "transparent" }
                Rectangle {
                    id: punto
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 10; height: 10; radius: height / 2
                    color: alm.color(fila.index, fila.modelData)
                }
                ColumnLayout {
                    anchors { left: punto.right; leftMargin: 12; right: botonFila.visible ? botonFila.left : parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: fila.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                        Text { text: alm.gb(fila.modelData.bytes); color: Paleta.texto; font { family: Paleta.mono; pixelSize: 12 } }
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: fila.bloqueada ? "Cierra Firefox para limpiarla"
                            : (fila.modelData.limpiable !== undefined ? alm.gb(fila.modelData.limpiable) + " se pueden limpiar · " : "") + fila.modelData.detalle
                        color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
                BotonCompacto {
                    id: botonFila
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    visible: !!fila.acc && (sobre.hovered || activeFocus || alm.confirmando === fila.modelData.id)
                    enabled: !accion.running && !fila.bloqueada && !(fila.modelData.limpiable === 0)
                    text: alm.confirmando === fila.modelData.id ? "¿Seguro? Vaciar" : (fila.acc?.etiqueta ?? "")
                    confirmando: alm.confirmando === fila.modelData.id
                    Accessible.name: (fila.acc?.etiqueta ?? "") + " · " + fila.modelData.nombre
                    onClicked: alm.actuar(fila.modelData)
                }
            }
        }
    }

    // ── Pie: snapshots, archivos grandes y resultado ─────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: alm.mensaje !== "" ? alm.mensaje
                : alm.datos?.snapshots?.root != null ? "Snapshots: " + alm.datos.snapshots.root + " del sistema y " + (alm.datos.snapshots.home ?? 0) + " de tu carpeta (snapper los rota solo)" : ""
            color: alm.error ? Paleta.peligro : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
        }
        BotonCompacto { text: "Revisar"; enabled: !lector.running; onClicked: { alm.mensaje = ""; alm.revisar(); } }
        BotonCompacto {
            text: alm.verGrandes ? "Ocultar archivos grandes" : "Archivos grandes"
            destacado: alm.verGrandes
            onClicked: { alm.verGrandes = !alm.verGrandes; if (alm.verGrandes) lectorGrandes.running = true; }
        }
    }
    Text {
        visible: alm.verGrandes && EstadoEscritorio.privacidad
        text: "Con privacidad activa no se muestran nombres de archivos."
        color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
    }
    Text {
        visible: alm.verGrandes && !EstadoEscritorio.privacidad && alm.grandes.length === 0
        text: lectorGrandes.running ? "Buscando…" : "No hay archivos de más de 100 MB en tus carpetas."
        color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 }
    }
    Repeater {
        model: alm.verGrandes && !EstadoEscritorio.privacidad ? alm.grandes : []
        Item {
            id: grande
            required property var modelData
            readonly property string nombre: modelData.ruta.split("/").pop()
            readonly property string carpeta: modelData.ruta.slice(0, modelData.ruta.length - nombre.length - 1)
            Layout.fillWidth: true
            implicitHeight: 40
            HoverHandler { id: sobreGrande }
            Rectangle { anchors.fill: parent; radius: EstiloPanel.rControl; color: sobreGrande.hovered ? EstiloPanel.relleno : "transparent" }
            Text {
                id: tamGrande
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                width: 64; horizontalAlignment: Text.AlignRight
                text: alm.gb(grande.modelData.bytes); color: Paleta.texto; font { family: Paleta.mono; pixelSize: 12 }
            }
            ColumnLayout {
                anchors { left: tamGrande.right; leftMargin: 12; right: accionesGrande.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 0
                Text { Layout.fillWidth: true; elide: Text.ElideMiddle; text: grande.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideMiddle
                    text: grande.carpeta.replace(Quickshell.env("HOME"), "~") + " · " + new Date(grande.modelData.fecha * 1000).toLocaleDateString(Qt.locale("es_ES"), "d MMM yyyy")
                    color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 }
                }
            }
            Row {
                id: accionesGrande
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 4
                opacity: sobreGrande.hovered || carpetaGrande.activeFocus || papeleraGrande.activeFocus ? 1 : 0
                BotonCompacto { id: carpetaGrande; text: "Abrir carpeta"; onClicked: alm.ejecutar(["xdg-open", grande.carpeta]) }
                BotonCompacto {
                    id: papeleraGrande
                    text: "A la papelera"
                    Accessible.name: "Mover a la papelera " + grande.nombre
                    onClicked: { alm.orden(["a-papelera", grande.modelData.ruta]); lectorGrandes.running = true; }
                }
            }
        }
    }
}
