// IslaCapa: una de las capas de la isla viva (reposo, música, aviso). La activa se ve; las demás se encogen y se desvanecen.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets

RowLayout {
    id: capaBase
    property bool activa: false
    anchors.centerIn: parent
    spacing: 8
    opacity: activa ? 1 : 0
    visible: opacity > 0
    scale: activa ? 1 : .86
    Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
}
