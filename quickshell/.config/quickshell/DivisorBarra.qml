// DivisorBarra: raya fina vertical entre grupos de módulos de la barra (BarraDerecha.qml).
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.leftMargin: 5
    Layout.rightMargin: 5
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: 1
    implicitHeight: 14
    color: Qt.alpha(Paleta.texto, .14)
}
