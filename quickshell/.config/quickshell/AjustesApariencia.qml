import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 8
    Text { text: "Color actual: " + (Paleta.fijado ? "acento fijado" : Paleta.modo === "wallpaper" ? "del fondo" : "Ayu"); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13; bold: true } }
    RowLayout {
        spacing: 8
        enabled: !PreferenciasUI.cambiandoTema
        BotonCompacto { text: "Usar Ayu"; destacado: Paleta.modo === "ayu" && !Paleta.fijado; onClicked: PreferenciasUI.cambiarTema(["ayu"]) }
        BotonCompacto { text: "Seguir fondo"; destacado: Paleta.modo === "wallpaper" && !Paleta.fijado; onClicked: PreferenciasUI.cambiarTema(["seguir"]) }
        BotonCompacto { text: "Fijar acento"; destacado: Paleta.fijado; onClicked: PreferenciasUI.cambiarTema(["fijar"]) }
    }
    RowLayout {
        spacing: 8
        enabled: !PreferenciasUI.cambiandoTema
        BotonCompacto { text: "Claro"; destacado: Paleta.variante === "claro"; onClicked: PreferenciasUI.cambiarTema(["claro"]) }
        BotonCompacto { text: "Oscuro"; destacado: Paleta.variante === "oscuro"; onClicked: PreferenciasUI.cambiarTema(["oscuro"]) }
        Text { text: PreferenciasUI.cambiandoTema ? "Aplicando…" : ""; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Reducir movimiento de la interfaz"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: Paleta.reducirMovimiento; onAlternado: PreferenciasUI.cambiarTema(["movimiento", activo ? "normal" : "reducir"]) }
    }
    Text { visible: PreferenciasUI.errorTema !== ""; Layout.fillWidth: true; text: PreferenciasUI.errorTema; wrapMode: Text.Wrap; color: Paleta.peligro; font { family: Paleta.fuente; pixelSize: 12 } }
}
