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
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Fondo panorámico entre espacios"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.panorama; onAlternado: { PreferenciasUI.panorama = !PreferenciasUI.panorama; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Luz del sol en el escritorio"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.cieloSolar; onAlternado: { PreferenciasUI.cieloSolar = !PreferenciasUI.cieloSolar; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Esquinas de pantalla redondeadas"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.esquinas; onAlternado: { PreferenciasUI.esquinas = !PreferenciasUI.esquinas; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Esquina activa: arriba a la izquierda abre la vista general"; color: Paleta.texto; wrapMode: Text.WordWrap; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.esquinaActiva; onAlternado: { PreferenciasUI.esquinaActiva = !PreferenciasUI.esquinaActiva; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Reloj de mesa al dejar el equipo quieto"; color: Paleta.texto; wrapMode: Text.WordWrap; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.reposo; onAlternado: { PreferenciasUI.reposo = !PreferenciasUI.reposo; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Borde de la ventana con los colores de la carátula"; color: Paleta.texto; wrapMode: Text.WordWrap; font { family: Paleta.fuente; pixelSize: 12 } }
        Interruptor { activo: PreferenciasUI.bordeMusica; onAlternado: { PreferenciasUI.bordeMusica = !PreferenciasUI.bordeMusica; PreferenciasUI.guardar(); } }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { Layout.fillWidth: true; text: "Tamaño de la interfaz"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 12 } }
        Repeater {
            model: [[1, "100 %"], [1.1, "110 %"], [1.25, "125 %"]]
            BotonCompacto {
                required property var modelData
                text: modelData[1]
                destacado: Math.abs(PreferenciasUI.escalaActiva - modelData[0]) < .01
                onClicked: if (!destacado) PreferenciasUI.fijarEscala(modelData[0])
            }
        }
    }
    Text { Layout.fillWidth: true; text: "Cambiar el tamaño reinicia la barra y los paneles unos segundos."; wrapMode: Text.Wrap; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
    Text { visible: PreferenciasUI.errorTema !== ""; Layout.fillWidth: true; text: PreferenciasUI.errorTema; wrapMode: Text.Wrap; color: Paleta.peligro; font { family: Paleta.fuente; pixelSize: 12 } }
}
