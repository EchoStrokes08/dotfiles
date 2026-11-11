// Centro de operaciones: argumentos como listas, acciones acotadas, salida visible.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Superpuesta {
    id: centro
    espacio: "centro-escritorio"
    anchoTarjeta: Math.min(620, (screen?.width ?? 1280) - 32)
    opacidadTarjeta: 1.0
    alturaRelativa: 0.08
    property string salida: "Guarda un checkpoint antes de reorganizar tus ventanas. Podrás devolverlas a sus espacios y deshacer la restauración."
    function ejecutar(args) {
        if (accion.running) return;
        salida = "Procesando…";
        accion.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/escritorio.py", ...args];
        accion.running = true;
    }
    onAbriendose: Qt.callLater(() => cerrar.forceActiveFocus())
    Repeater {
        model: ["cristal", "lectura", "minimo", "rendimiento"]
        Item {
            required property string modelData
            required property int index
            Shortcut {
                sequence: "Alt+" + (index + 1)
                context: Qt.ApplicationShortcut
                enabled: centro.abierto
                onActivated: centro.ejecutar(["perfil", modelData])
            }
        }
    }
    Process {
        id: accion
        stdout: StdioCollector { onStreamFinished: if (text.trim()) centro.salida = text.trim(); }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) centro.salida = text.trim(); }
    }
    component Accion: Button {
        id: boton
        Layout.fillWidth: true
        implicitHeight: 38
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        property bool destacado: false
        property string ayuda: ""
        ToolTip.visible: hovered && ayuda !== ""
        ToolTip.text: ayuda
        ToolTip.delay: 450
        enabled: !accion.running
        background: Rectangle {
            radius: 8
            color: Qt.alpha(Paleta.naranja, boton.destacado ? 0.22 : boton.hovered ? 0.13 : 0.05)
            border.width: 1
            border.color: Qt.alpha(Paleta.naranja, boton.destacado || boton.activeFocus ? 0.8 : 0.18)
        }
        contentItem: Text {
            text: boton.text
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: boton.enabled ? Paleta.texto : Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12; bold: boton.destacado }
        }
    }
    ColumnLayout {
        width: parent.width
        spacing: 12
        Item {
            Layout.fillWidth: true
            implicitHeight: 54
            ColumnLayout {
                anchors { left: parent.left; right: cerrar.left; rightMargin: 16 }
                spacing: 3
                Text { Layout.fillWidth: true; text: "CENTRO DEL ESCRITORIO"; color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 12; bold: true; letterSpacing: 2 } }
                Text { Layout.fillWidth: true; text: "Tu sesión, bajo control"; elide: Text.ElideRight; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 23; bold: true } }
            }
            Accion { id: cerrar; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: 70; text: "Cerrar"; onClicked: centro.abierto = false }
        }
        Text {
            Layout.fillWidth: true
            text: EstadoEscritorio.motivos
            color: Paleta.gris
            wrapMode: Text.Wrap
            font { family: Paleta.fuente; pixelSize: 12 }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 8
            Repeater {
                model: ["cristal", "lectura", "minimo", "rendimiento"]
                Accion {
                    required property string modelData
                    text: modelData === "minimo" ? "Mínimo" : modelData[0].toUpperCase() + modelData.slice(1)
                    ayuda: ({cristal: "Tu apariencia habitual con transparencia y efectos. Alt+1", lectura: "Ventanas opacas y sin blur para leer con claridad. Alt+2", minimo: "Sin animaciones ni sombras; replay automático pausado. Alt+3", rendimiento: "Sin efectos y con el máximo espacio para trabajar. Alt+4"})[modelData]
                    destacado: EstadoEscritorio.perfil === modelData
                    onClicked: centro.ejecutar(["perfil", modelData])
                }
            }
        }
        Text { text: "ORGANIZACIÓN Y PRIVACIDAD"; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1 } }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            Accion { text: "Guardar checkpoint"; onClicked: centro.ejecutar(["checkpoint", "guardar"]) }
            Accion { text: "Restaurar espacios"; ayuda: "Devuelve las ventanas existentes a los espacios guardados; crea una opción para deshacer."; onClicked: centro.ejecutar(["checkpoint", "restaurar"]) }
            Accion { text: "Deshacer restauración"; ayuda: "Recupera los espacios anteriores a la última restauración."; onClicked: centro.ejecutar(["checkpoint", "deshacer"]) }
            Accion { text: Reunion.activa ? "Privacidad: reunión" : EstadoEscritorio.privacidad ? "Privacidad: sí" : "Privacidad: no"; enabled: !Reunion.activa && !accion.running; destacado: EstadoEscritorio.privacidad; onClicked: centro.ejecutar(["privacidad"]) }
            Accion { text: "Juego automático"; onClicked: centro.ejecutar(["juego", "automatico"]) }
            Accion { text: "Diagnóstico"; onClicked: centro.ejecutar(["diagnostico"]) }
            Accion { text: "Replay automático"; ayuda: "Graba con cargador; pausa con batería, privacidad o perfil mínimo."; onClicked: centro.ejecutar(["replay", "auto"]) }
            Accion { text: "Pausar replay"; onClicked: centro.ejecutar(["replay", "stop"]) }
            Accion { text: "Guardar últimos 30 s"; onClicked: centro.ejecutar(["replay", "save"]) }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 185
            radius: 9
            color: Qt.alpha(Paleta.fondo, 0.65)
            border { width: 1; color: Qt.alpha(Paleta.gris, 0.25) }
            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                TextArea {
                    text: centro.salida
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Paleta.texto
                    font { family: Paleta.fuente; pixelSize: 12 }
                    background: null
                }
            }
        }
        Accion { text: "Abrir mesa de trabajo → ventanas, plantillas, reuniones y rutinas"; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "mesa", "abrir", "ventanas"]) }
        Text {
            Layout.fillWidth: true
            text: "Privacidad pausa el replay y oculta títulos en la barra. Los checkpoints duran esta sesión; no reabren aplicaciones."
            color: Paleta.gris
            wrapMode: Text.Wrap
            font { family: Paleta.fuente; pixelSize: 11 }
        }
    }
}
