// Impresora (SUPER+A y luego I): estado de la Epson, cola de trabajos e imprimir.
//   Los datos y las órdenes van por ~/.config/hypr/scripts/impresora.py (CUPS).
//   P imprimir archivo · T página de prueba · Esc cerrar
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: imp
    espacio: "impresora"
    anchoTarjeta: 520

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/impresora.py"
    property var datos: ({})
    property bool cargado: false
    property string aviso: ""            // última acción («Enviado a imprimir», errores…)
    readonly property var trabajos: datos.trabajos ?? []
    readonly property bool lista: !!datos.instalada && !!datos.responde

    function g(cp) { return String.fromCodePoint(cp); }

    onAbriendose: { aviso = ""; leer.running = true; foco.forceActiveFocus(); }

    Process {
        id: leer
        command: [imp.script, "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { imp.datos = JSON.parse(this.text); imp.cargado = true; } catch (e) {}
            }
        }
    }
    Timer { interval: 3000; repeat: true; running: imp.abierto; onTriggered: if (!leer.running) leer.running = true }

    // Órdenes: una a la vez; al terminar se vuelve a leer el estado
    Process {
        id: orden
        property string exito: ""
        stderr: StdioCollector { id: errores }
        onExited: (codigo) => {
            imp.aviso = codigo === 0 ? exito : (errores.text.trim().split("\n").pop() || "No se pudo completar");
            leer.running = true;
        }
    }
    function ejecutar(args, exito) {
        if (orden.running) return;
        aviso = "";
        orden.exito = exito;
        orden.command = [script].concat(args);
        orden.running = true;
    }
    function elegirArchivo() { ejecutar(["elegir"], "Enviado a imprimir"); }
    function prueba() { ejecutar(["prueba"], "Página de prueba enviada"); }
    function abrir(url) { if (url) cerrarY(() => Quickshell.execDetached(["xdg-open", url])); }

    readonly property string textoEstado: {
        if (!cargado) return "Buscando…";
        if (!datos.instalada) return "No está instalada";
        if (!datos.responde) return "No responde";
        if (!datos.habilitada) return "En pausa por un error";
        if (datos.estado === "printing") return "Imprimiendo";
        return "Lista";
    }
    readonly property color colorEstado: !cargado ? Paleta.gris
        : !lista || !datos.habilitada ? Paleta.peligro
        : datos.estado === "printing" ? Paleta.acento2 : Paleta.exito

    function tamano(b) {
        return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB";
    }

    ColumnLayout {
        width: parent.width
        spacing: 12

        // Atajos de teclado del panel
        Item {
            id: foco
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_P) { imp.elegirArchivo(); e.accepted = true; }
                else if (e.key === Qt.Key_T) { imp.prueba(); e.accepted = true; }
            }
        }

        // Cabecera: icono, modelo y estado
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 48; implicitHeight: 48; radius: EstiloPanel.rTarjeta
                color: Qt.alpha(imp.colorEstado, .14)
                Text {
                    anchors.centerIn: parent
                    text: imp.g(0xF042A)
                    color: imp.colorEstado
                    font { family: Paleta.fuente; pixelSize: 26 }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: imp.datos.modelo ? "Epson " + imp.datos.modelo.replace(/^EPSON\s*/i, "") : "Impresora"
                    color: Paleta.texto
                    elide: Text.ElideRight
                    font { family: Paleta.fuente; pixelSize: 16; bold: true }
                }
                RowLayout {
                    spacing: 8
                    Rectangle { implicitWidth: 8; implicitHeight: 8; radius: height / 2; color: imp.colorEstado }
                    Text {
                        text: imp.textoEstado
                        color: EstiloPanel.secundario
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                    Text {
                        visible: !!imp.datos.ip
                        text: "· " + (imp.datos.red ? imp.datos.red + " · " : "") + imp.datos.ip
                        color: EstiloPanel.tenue
                        font { family: Paleta.fuente; pixelSize: 12 }
                    }
                }
            }
        }

        // Mensaje de CUPS (atasco, sin papel…) si lo hay
        Text {
            Layout.fillWidth: true
            visible: !!imp.datos.mensaje
            text: imp.datos.mensaje ?? ""
            color: Paleta.aviso
            wrapMode: Text.WordWrap
            font { family: Paleta.fuente; pixelSize: 12 }
        }

        // Acciones principales
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            BotonPanel {
                text: "Imprimir archivo"; simbolo: imp.g(0xF0214); destacado: true
                enabled: imp.lista && !orden.running
                onClicked: imp.elegirArchivo()
            }
            BotonPanel {
                text: "Página de prueba"; simbolo: imp.g(0xF0219)
                enabled: imp.lista && !orden.running
                onClicked: imp.prueba()
            }
        }

        // Arreglos cuando algo falla
        RowLayout {
            Layout.fillWidth: true
            visible: imp.cargado && (!imp.lista || !imp.datos.habilitada)
            spacing: 8
            BotonPanel {
                visible: !!imp.datos.instalada && !imp.datos.responde
                text: orden.running ? "Buscando en la red…" : "Buscarla en la red"; simbolo: imp.g(0xF0450)
                enabled: !orden.running
                onClicked: imp.ejecutar(["reparar"], "Impresora encontrada")
            }
            BotonPanel {
                visible: !!imp.datos.responde && !imp.datos.habilitada
                text: "Reanudar"; simbolo: imp.g(0xF040A)
                enabled: !orden.running
                onClicked: imp.ejecutar(["reactivar"], "Cola reanudada")
            }
        }

        Text {
            Layout.fillWidth: true
            visible: imp.aviso !== ""
            text: imp.aviso
            color: EstiloPanel.secundario
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }

        // Cola de impresión
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Text {
                Layout.fillWidth: true
                text: imp.trabajos.length ? "En cola (" + imp.trabajos.length + ")" : "Cola vacía"
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 11; bold: true; capitalization: Font.AllUppercase }
            }
            BotonCompacto {
                visible: imp.trabajos.length > 1
                text: "Cancelar todo"; acento: Paleta.peligro
                onClicked: imp.ejecutar(["cancelar", "todos"], "Cola vaciada")
            }
        }
        Repeater {
            model: imp.trabajos
            Rectangle {
                id: trabajo
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48; radius: EstiloPanel.rControl
                color: EstiloPanel.relleno
                border { width: 1; color: EstiloPanel.borde }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    spacing: 12
                    Text {
                        text: imp.g(trabajo.modelData.rango === "active" ? 0xF042A : 0xF0150)
                        color: trabajo.modelData.rango === "active" ? Paleta.acento2 : Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 16 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: trabajo.modelData.archivo
                            color: Paleta.texto
                            elide: Text.ElideMiddle
                            font { family: Paleta.fuente; pixelSize: 13 }
                        }
                        Text {
                            text: (trabajo.modelData.rango === "active" ? "Imprimiendo" : "Esperando") + " · " + imp.tamano(trabajo.modelData.tamano)
                            color: EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 11 }
                        }
                    }
                    BotonCompacto {
                        text: "Cancelar"; acento: Paleta.peligro
                        onClicked: imp.ejecutar(["cancelar", String(trabajo.modelData.id)], "Trabajo cancelado")
                    }
                }
            }
        }

        // Enlaces a la propia impresora
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: imp.lista
            spacing: 8
            BotonPanel { text: "Ver tinta"; simbolo: imp.g(0xF058C); onClicked: imp.abrir(imp.datos.tinta) }
            BotonPanel { text: "Ajustes de la impresora"; simbolo: imp.g(0xF0493); onClicked: imp.abrir(imp.datos.web) }
        }

        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            atajos: [["P", "imprimir"], ["T", "prueba"], ["Esc", "cerrar"]]
        }
    }
}
