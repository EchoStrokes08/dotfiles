import QtQuick
import QtQuick.Layouts
import Quickshell
ShellRoot {
  FloatingWindow {
    visible: true
    implicitWidth: 460; implicitHeight: 420
    color: Paleta.fondo
    Rectangle {
      id: fondo; anchors.fill: parent; color: Paleta.fondo
      ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 8
        RowLayout { Layout.fillWidth: true; spacing: 4
          BotonPanel { text: "Inicio"; destacado: true }
          BotonPanel { text: "Redes" }
          BotonPanel { text: "Móvil" }
          BotonPanel { text: "Más" }
        }
        GridLayout { Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
          ControlRapido { compacto: true; conDetalle: true; Layout.preferredWidth: 1; nombre: "Wi-Fi"; simbolo: "󰖩"; cosa: "wifi"; subtitulo: "Red de casa"; dato: ({disponible:true,activo:true}) }
          ControlRapido { compacto: true; conDetalle: true; Layout.preferredWidth: 1; nombre: "Bluetooth"; simbolo: "󰂯"; cosa: "bluetooth"; subtitulo: "Audífonos"; dato: ({disponible:true,activo:true}) }
          ControlRapido { compacto: true; Layout.preferredWidth: 1; nombre: "Energía alta"; simbolo: "󰓅"; cosa: "rendimiento"; dato: ({disponible:true,activo:false}) }
          ControlRapido { compacto: true; Layout.preferredWidth: 1; nombre: "Luz nocturna"; simbolo: "󰖔"; cosa: "luz"; dato: ({disponible:true,activo:true}) }
        }
        Item { Layout.fillWidth: true; implicitHeight: 52
          FondoSeleccion { anchors.fill: parent; radius: 16; marca: true }
          Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "Discord · fila del lanzador"; color: Paleta.texto; font.pixelSize: 14 }
        }
        Item { Layout.fillWidth: true; implicitHeight: 40
          FondoSeleccion { anchors.fill: parent }
          Text { anchors.centerIn: parent; text: "Pestaña activa"; color: Paleta.texto; font.pixelSize: 13; font.bold: true }
        }
        Item { Layout.fillHeight: true }
      }
    }
  }
  Timer { interval: 1200; running: true; onTriggered: fondo.grabToImage(r => { r.saveToFile(__CAPTURA__); Qt.quit(); }) }
}
