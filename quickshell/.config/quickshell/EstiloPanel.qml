// EstiloPanel: las escalas del sistema de diseño. Todo panel nuevo usa estos valores y nada más.
// tests/test_estilo.py falla si aparece un tamaño de letra, radio o duración fuera de estas escalas.
// Referencia con ejemplos: docs/diseno.md
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string fuente: "Adwaita Sans"

    // ── Letra (px) ─────────────────────────────────────────────────────
    // 11 etiquetas y metadatos · 12 controles · 13 texto de interfaz · 14 cuerpo y filas
    // 16 subtítulos e iconos de fila · 20 títulos e iconos de tarjeta · 26 título de panel
    // Cifras grandes (relojes, indicadores): 36 · 44 · 62 · 104 · 150
    readonly property int t11: 11
    readonly property int t12: 12
    readonly property int t13: 13
    readonly property int t14: 14
    readonly property int t16: 16
    readonly property int t20: 20
    readonly property int t26: 26
    readonly property var escalaLetra: [11, 12, 13, 14, 16, 20, 26, 36, 44, 62, 104, 150]

    // ── Radio (px) ─────────────────────────────────────────────────────
    // 4 puntos y barras finas · 8 teclas y chips · 12 botones y campos · 16 tarjetas · 24 paneles
    // Círculos y píldoras: height / 2 (nunca un número)
    readonly property int rPunto: 4
    readonly property int rChip: 8
    readonly property int rControl: 12
    readonly property int rTarjeta: 16
    readonly property int rPanel: 24
    readonly property var escalaRadio: [0, 4, 8, 12, 16, 24]

    // ── Espacio (px) ───────────────────────────────────────────────────
    readonly property int e1: 4
    readonly property int e2: 8
    readonly property int e3: 12
    readonly property int e4: 16
    readonly property int e5: 24
    readonly property int e6: 32
    // Valores permitidos en spacing, margins y padding: 1–1,5 son biseles; 40–56, márgenes contra el borde de la pantalla
    readonly property var escalaEspacio: [0, 1, 1.5, 2, 4, 8, 12, 16, 24, 32, 40, 48, 56]

    // ── Capas: el texto a distintas opacidades sobre el fondo del panel ──
    readonly property color relleno:       Qt.alpha(Paleta.texto, .04)   // fondo de tarjeta o control en reposo
    readonly property color rellenoActivo: Qt.alpha(Paleta.texto, .08)   // encima, elegido
    readonly property color borde:         Qt.alpha(Paleta.texto, .08)   // contorno de tarjeta
    readonly property color bordeFuerte:   Qt.alpha(Paleta.texto, .14)   // contorno de campo o control
    readonly property color velo:          Qt.alpha(Paleta.texto, .25)   // separadores marcados, pistas de deslizador
    readonly property color apagado:       Qt.alpha(Paleta.texto, .45)   // desactivado, marcadores de posición
    readonly property color secundario:    Qt.alpha(Paleta.texto, .85)   // texto de apoyo sobre resaltado
    // Opacos (mezclados con el fondo): para texto tenue y superficies elevadas
    // Sobre fondo claro hace falta más texto para el mismo contraste (≥ 4,5:1, tests/test_estilo.py)
    readonly property bool fondoClaro: Paleta.fondo.hslLightness > .5
    readonly property color tenue: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, fondoClaro ? .82 : .68))
    readonly property color superficie: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .035))
    readonly property color elevada: Qt.tint(Paleta.fondo, Qt.alpha(Paleta.texto, .065))

    // ── Efectos según el perfil ────────────────────────────────────────
    readonly property bool movimiento: EstadoEscritorio.perfil !== "minimo"
        && EstadoEscritorio.perfil !== "rendimiento"
        && EstadoEscritorio.datos.juego_activo !== "true"
        && EstadoEscritorio.datos.bateria !== "true"
    // Sombras, resplandores y luces del cristal: fuera en mínimo/rendimiento, juego y batería
    readonly property bool efectos: movimiento
    // ¿Hay blur de Hyprland detrás de los paneles? Lo apagan los mismos casos y además el perfil lectura (politicas.lua)
    readonly property bool conBlur: efectos && EstadoEscritorio.perfil === "cristal"
    // Opacidad del cristal de los paneles: con blur basta 0.93 para que no se lea lo de detrás; sin blur, opaco
    readonly property real opacidadPanel: conBlur ? 0.93 : 1.0

    // ── Movimiento (ms). 0 cuando el perfil apaga las animaciones ──────
    // rápido: hover, pulsar, colores · normal: abrir y cerrar paneles, cambiar de página · lento: elementos grandes
    // Curva: Easing.OutCubic para todo; Easing.OutBack solo en la entrada de un panel o una tarjeta;
    // Easing.InOutSine solo en bucles (pulsos que respiran).
    readonly property int rapido: movimiento ? 120 : 0
    readonly property int normal: movimiento ? 200 : 0
    readonly property int lento:  movimiento ? 320 : 0
}
