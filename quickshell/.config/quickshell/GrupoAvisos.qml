// Un grupo de avisos (misma app o conversación). Plegado: una fila con la app, el número, el último
// asunto y la hora; clic o Enter lo despliega con las tarjetas completas (acciones y respuesta).
// Los críticos se ven siempre completos.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

ColumnLayout {
    id: grupo
    required property var datos
    spacing: 8
    readonly property bool expandido: Notificaciones.expandidos[datos.clave] === true
    readonly property var ultimo: datos.items[0]
    readonly property var criticos: datos.items.filter(n => n.urgency === NotificationUrgency.Critical)
    readonly property string nombre: EstadoEscritorio.privacidad ? "Aplicación" : (datos.nombre + (datos.conversacion ? " · " + datos.conversacion : ""))
    readonly property string rutaIcono: EstadoEscritorio.privacidad || !ultimo ? "" : Notificaciones.icono(ultimo)
    // Sin icono: un color propio por app, sacado de su nombre (la misma app, siempre el mismo color)
    readonly property color tono: {
        const tonos = [Paleta.acento, Paleta.acento2, Paleta.exito, Paleta.aviso];
        let h = 0;
        for (const c of datos.nombre || "") h = (h * 31 + c.charCodeAt(0)) >>> 0;
        return tonos[h % tonos.length];
    }

    // ── Plegado: una fila ────────────────────────────────────────────
    // Con varios avisos, una o dos hojas asoman por debajo: se ve de un vistazo que hay más.
    Item {
        id: pila
        visible: !grupo.expandido
        Layout.fillWidth: true
        readonly property int hojas: Math.min(grupo.datos.items.length - 1, 2)
        implicitHeight: 56 + hojas * 5
        Repeater {
            model: pila.hojas
            Rectangle {
                required property int index
                z: -1 - index
                x: 8 * (index + 1); width: pila.width - 16 * (index + 1)
                y: 5 * (index + 1); height: 56
                radius: EstiloPanel.rTarjeta
                // oscuro: cada hoja algo más honda; claro: hojas de papel blanco, la sombra las separa
                color: EstiloPanel.fondoClaro ? Qt.tint(EstiloPanel.superficie, Qt.alpha("white", .7 - .25 * index))
                                              : Qt.tint(EstiloPanel.superficie, Qt.alpha("black", .10 * (index + 1)))
                border { width: 1; color: Qt.alpha(Paleta.texto, .12 - .03 * index) }
                RectangularShadow {
                    anchors.fill: parent; z: -1
                    visible: EstiloPanel.profundidad
                    radius: parent.radius; offset.y: 2; blur: 8; spread: -4
                    color: Qt.alpha("black", EstiloPanel.fondoClaro ? .10 : .25)
                }
            }
        }
        RectangularShadow {
            anchors.fill: fila
            visible: EstiloPanel.profundidad
            radius: fila.radius; offset.y: 3; blur: 14; spread: -6
            color: Qt.alpha("black", EstiloPanel.fondoClaro ? .14 : .30)
        }
        ClippingRectangle {
            id: fila
            width: pila.width
            height: 56
            radius: EstiloPanel.rTarjeta
            color: zona.containsMouse || fila.activeFocus ? EstiloPanel.rellenoActivo : EstiloPanel.superficie
            border { width: fila.activeFocus ? 2 : 1; color: fila.activeFocus ? Paleta.acento : EstiloPanel.borde }
            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            // Halo de la app: su icono, enorme y desenfocado, tiñe la fila desde la izquierda con sus colores
            MultiEffect {
                visible: EstiloPanel.profundidad && iconoGrupo.visible && iconoGrupo.status === Image.Ready
                x: -46; width: 150; height: 150
                anchors.verticalCenter: parent.verticalCenter
                source: iconoGrupo
                blurEnabled: true; blur: 1; blurMax: 64
                saturation: .6; brightness: .1
                opacity: zona.containsMouse ? .42 : .28
                Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
            }
            RectangularShadow {   // sin icono: el halo es del color propio de la app
                visible: EstiloPanel.profundidad && grupo.rutaIcono === ""
                x: -10; width: 60; height: 40
                anchors.verticalCenter: parent.verticalCenter
                radius: EstiloPanel.rTarjeta; blur: 48; spread: 0
                color: Qt.alpha(grupo.tono, zona.containsMouse ? .30 : .20)
                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
            }
            Rectangle {   // filo de luz superior, como en las tarjetas
                visible: EstiloPanel.profundidad
                x: fila.radius * .8; y: 1
                width: fila.width - fila.radius * 1.6; height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0;  color: "transparent" }
                    GradientStop { position: .35; color: Qt.alpha(Paleta.texto, .16) }
                    GradientStop { position: 1;  color: "transparent" }
                }
            }
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: grupo.nombre + ", " + grupo.datos.items.length + " avisos. Desplegar"
            Keys.onReturnPressed: Notificaciones.desplegar(grupo.datos.clave)
            Keys.onSpacePressed: Notificaciones.desplegar(grupo.datos.clave)
            MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notificaciones.desplegar(grupo.datos.clave) }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 12
                Rectangle {   // baldosa del icono
                    implicitWidth: 36; implicitHeight: 36; radius: EstiloPanel.rControl
                    color: grupo.rutaIcono === "" ? Qt.tint(EstiloPanel.elevada, Qt.alpha(grupo.tono, .14)) : Qt.alpha(EstiloPanel.elevada, .7)
                    border { width: 1; color: grupo.rutaIcono === "" ? Qt.alpha(grupo.tono, .35) : EstiloPanel.borde }
                    IconImage {
                        id: iconoGrupo
                        anchors.centerIn: parent
                        implicitSize: 26
                        visible: grupo.rutaIcono !== ""; source: grupo.rutaIcono; asynchronous: true
                        scale: zona.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                    }
                    Text { anchors.centerIn: parent; visible: grupo.rutaIcono === ""; text: grupo.nombre.charAt(0).toUpperCase(); color: Qt.lighter(grupo.tono, 1.1); font { family: Paleta.fuente; pixelSize: 16; bold: true } }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: grupo.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                        Rectangle {
                            visible: grupo.datos.items.length > 1
                            implicitWidth: cuenta.implicitWidth + 12; implicitHeight: 18; radius: height / 2
                            color: EstiloPanel.elevada; border { width: 1; color: EstiloPanel.bordeFuerte }
                            Text { id: cuenta; anchors.centerIn: parent; text: grupo.datos.items.length; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                        }
                        Text { text: { Notificaciones.pulso; return grupo.ultimo ? Notificaciones.haceCuanto(grupo.ultimo) : ""; } color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                    }
                    Text {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: EstadoEscritorio.privacidad ? "Contenido oculto" : (grupo.ultimo?.summary || grupo.ultimo?.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                        color: EstiloPanel.secundario; font { family: Paleta.fuente; pixelSize: 13 }
                    }
                }
                BotonCompacto {
                    text: "×"
                    implicitWidth: 32; leftPadding: 0; rightPadding: 0
                    Accessible.name: "Descartar avisos de " + grupo.nombre
                    onClicked: { for (const n of grupo.datos.items.slice()) n.dismiss(); }
                }
            }
        }
    }
    // Los críticos no se esconden nunca
    Repeater {
        model: grupo.expandido ? [] : grupo.criticos
        NotiTarjeta { required property var modelData; Layout.fillWidth: true; noti: modelData }
    }

    // ── Desplegado: cabecera y tarjetas completas ────────────────────
    RowLayout {
        visible: grupo.expandido
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: grupo.nombre + " · " + grupo.datos.items.length; elide: Text.ElideRight; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
        BotonCompacto { text: "Plegar"; onClicked: Notificaciones.desplegar(grupo.datos.clave) }
        BotonCompacto { text: "×"; Accessible.name: "Descartar avisos de esta aplicación"; onClicked: { for (const n of grupo.datos.items.slice()) n.dismiss(); } }
    }
    Repeater {
        model: grupo.expandido ? grupo.datos.items : []
        NotiTarjeta { required property var modelData; Layout.fillWidth: true; noti: modelData }
    }
}
