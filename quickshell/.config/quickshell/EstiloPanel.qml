pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string fuente: "Adwaita Sans"
    readonly property color superficie: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .035))
    readonly property color elevada: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .065))
    readonly property color tenue: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .68))
    readonly property color borde: Qt.alpha(Paleta.texto, .12)
    readonly property bool movimiento: EstadoEscritorio.perfil !== "minimo"
        && EstadoEscritorio.perfil !== "rendimiento"
        && EstadoEscritorio.datos.juego_activo !== "true"
        && EstadoEscritorio.datos.bateria !== "true"
    readonly property int breve: movimiento ? 140 : 0
    readonly property int entrada: movimiento ? 220 : 0
}
