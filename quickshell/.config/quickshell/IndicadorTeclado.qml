import QtQuick
import QtQuick.Controls

BotonCompacto {
    visible: ModoTeclado.activo
    text: ModoTeclado.nombre + " · Esc para salir"
    destacado: true
    Accessible.name: "Modo " + ModoTeclado.nombre
    Accessible.description: ModoTeclado.ayuda
    ToolTip.visible: hovered
    ToolTip.text: ModoTeclado.ayuda
    ToolTip.delay: 300
    onClicked: ModoTeclado.salir()
}
