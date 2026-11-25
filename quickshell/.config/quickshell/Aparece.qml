// Aparece: envuelve algo para que entre subiendo y fundiéndose al crearse, tras «retraso» ms.
// Lo usan las tarjetas de «Tu día» (CapaTuDia.qml) para las entradas escalonadas. Sin movimiento, directo.
//   Aparece { retraso: 300; Text { text: "Hola" } }
// El hijo no debe anclarse a su padre: el tamaño de Aparece sale del suyo.
import QtQuick

Item {
    id: a
    property int retraso: 0
    property real desde: 28               // px que sube al entrar
    property real escalaDesde: 1          // < 1 para que además crezca (con un rebote)
    default property alias contenido: caja.data
    implicitWidth: caja.childrenRect.width
    implicitHeight: caja.childrenRect.height

    Item {
        id: caja
        width: a.width; height: a.height
        opacity: 0
        scale: a.escalaDesde
        transform: Translate { id: subir; y: a.desde }
    }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: TuDia.cine ? a.retraso : 0 }
        ParallelAnimation {
            NumberAnimation { target: caja; property: "opacity"; to: 1; duration: TuDia.medio; easing.type: Easing.OutCubic }
            NumberAnimation { target: subir; property: "y"; to: 0; duration: TuDia.largo; easing.type: Easing.OutCubic }
            NumberAnimation { target: caja; property: "scale"; to: 1; duration: TuDia.largo; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }
}
