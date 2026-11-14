import QtQuick
import QtQuick.Layouts
import Quickshell
ShellRoot {
  FloatingWindow {
    id: ventana
    visible: true
    implicitWidth: 900; implicitHeight: 600
    color: Paleta.fondo
    Rectangle {
      id: fondo; anchors.fill:parent; color:Paleta.fondo
    ColumnLayout {
      id: contenido
      anchors { fill: parent; margins: 24 }
      spacing: 16
      Text { text: "ORION · Fase 1 · Vista con datos simulados"; color: Paleta.texto; font.pixelSize: 20 }
      RowLayout {
        Layout.fillWidth: true
        ControlRapido { nombre: "Wi-Fi"; simbolo: "󰖩"; cosa: "wifi"; dato: ({disponible:true,activo:true}) }
        ControlRapido { nombre: "Bluetooth"; simbolo: "󰂯"; cosa: "bluetooth"; dato: ({disponible:true,activo:false}) }
        ControlRapido { nombre: "Replay"; simbolo: "󰑋"; cosa: "replay"; dato: ({disponible:false,activo:null,error:"Servicio no disponible"}) }
        ControlRapido { nombre: "Energía"; simbolo: "󰓅"; cosa: "rendimiento"; dato: ({disponible:true,activo:false}); error: "No se confirmó la orden" }
      }
      TarjetaRecarga { Layout.fillWidth: true; error: "Ejemplo.qml:12: error de sintaxis"; detalle: true }
      EstadoAgenda { Layout.fillWidth: true }
      IndicadorTeclado { }
      Text { Layout.fillWidth: true; text: ModoTeclado.ayuda; color: Paleta.texto; font.pixelSize: 13; wrapMode: Text.Wrap }
    }
  }
  }
  Timer { interval: 500; running:true; onTriggered: { ModoTeclado.recibir("redimensionar"); } }
  Timer { interval: 1200; running:true; onTriggered: fondo.grabToImage(r => { r.saveToFile(__CAPTURA__); Qt.quit(); }) }
}
