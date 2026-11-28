// CapaTuDia: lo que se ve de «Tu día» (estado y datos en TuDia.qml).
// La pantalla real se aleja y se desenfoca, el fondo toma el color de cada tarjeta y las tarjetas pasan
// solas como historias: portada · pantalla · apps · ritmo · racha · música · lo que hiciste · el día en un círculo.
// Teclado: → / Intro siguiente · ← anterior · Espacio pausa · Esc salir. Ratón: clic a la derecha avanza,
// a la izquierda vuelve, mantener pulsado pausa. Solo en la pantalla con el foco.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    screen: Quickshell.screens.find(s => s.name === TuDia.pantalla) ?? null
    visible: TuDia.activa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tudia"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var d: TuDia.datos ?? ({})
    readonly property bool sem: d.semanal === true   // «Tu semana»: los mismos datos sumando 7 días
    property real p: 0                   // 0 = el escritorio tal cual · 1 = dentro de «Tu día»
    property real progreso: 0            // de la tarjeta actual
    property bool pausado: false
    property bool pausaPorPulsar: false
    property string mostrada: ""         // la tarjeta en pantalla (cambia a mitad del fundido)
    readonly property bool ultima: TuDia.pagina >= TuDia.paginas.length - 1

    // ── Utilidades de texto ─────────────────────────────────────────────
    function duracion(s) {
        s = Math.max(0, Math.round(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        if (h > 0) return m > 0 ? `${h} h ${m} min` : `${h} h`;
        return m > 0 ? `${m} min` : `${s} s`;
    }
    function hora(t) { return t ? Qt.formatTime(new Date(t * 1000), "H:mm") : ""; }
    function fecha(dia) {
        if (!dia) return "";
        const f = new Date(dia + "T12:00:00").toLocaleDateString(Qt.locale("es_CO"), "dddd d 'de' MMMM");
        return f.charAt(0).toUpperCase() + f.slice(1);
    }
    function rango(desde, hasta) {    // «Del 22 al 28 de noviembre» (o «Del 28 de nov. al 4 de dic.»)
        if (!desde || !hasta) return "";
        const a = new Date(desde + "T12:00:00"), b = new Date(hasta + "T12:00:00"), l = Qt.locale("es_CO");
        return a.getMonth() === b.getMonth() ? `Del ${a.getDate()} al ${b.toLocaleDateString(l, "d 'de' MMMM")}`
             : `Del ${a.toLocaleDateString(l, "d 'de' MMM")} al ${b.toLocaleDateString(l, "d 'de' MMM")}`;
    }
    function nombreDia(dia) {         // «el viernes»
        return dia ? "el " + new Date(dia + "T12:00:00").toLocaleDateString(Qt.locale("es_CO"), "dddd") : "";
    }
    // Orden de la serie que separa más los tonos (acento y aviso se parecen en muchos temas)
    readonly property var ordenSerie: [0, 1, 4, 2, 6, 5, 3, 7]
    function color(i) { return i < 0 ? Qt.alpha(Paleta.texto, .35) : Paleta.serie[ordenSerie[i % ordenSerie.length]]; }
    function css(k) { return `rgba(${Math.round(k.r * 255)},${Math.round(k.g * 255)},${Math.round(k.b * 255)},${k.a})`; }
    readonly property string nombre: { const u = Quickshell.env("USER") || ""; return u ? u.charAt(0).toUpperCase() + u.slice(1) : ""; }

    // ── Entrar, salir y avanzar ─────────────────────────────────────────
    onVisibleChanged: if (visible) {
        p = 0; pausado = false; mostrada = TuDia.actual; cambio.stop(); tarjetas.opacity = 1;
        entrar.restart(); reiniciar(); teclas.forceActiveFocus();
    }
    NumberAnimation { id: entrar; target: c; property: "p"; to: 1; duration: TuDia.largo; easing.type: Easing.OutCubic }
    Connections {
        target: TuDia
        function onSaliendoChanged() { if (TuDia.saliendo) { avance.stop(); entrar.stop(); salir.restart(); } }
        function onPaginaChanged() { if (c.visible) { cambio.restart(); c.reiniciar(); } }
    }
    SequentialAnimation {
        id: salir
        NumberAnimation { target: c; property: "p"; to: 0; duration: TuDia.largo; easing.type: Easing.InOutCubic }
        ScriptAction { script: TuDia.terminar() }
    }
    SequentialAnimation {   // la tarjeta vieja se funde, entra la nueva (con sus propias entradas)
        id: cambio
        NumberAnimation { target: tarjetas; property: "opacity"; to: 0; duration: TuDia.corto; easing.type: Easing.InCubic }
        ScriptAction { script: c.mostrada = TuDia.actual }
        PropertyAction { target: tarjetas; property: "opacity"; value: 1 }
    }
    function reiniciar() {
        progreso = 0;
        if (ultima) { avance.stop(); progreso = 1; } else avance.restart();
    }
    NumberAnimation {
        id: avance
        target: c; property: "progreso"; from: 0; to: 1
        duration: TuDia.porTarjeta
        paused: running && c.pausado
        onFinished: if (c.progreso >= 1 && !TuDia.saliendo) TuDia.siguiente()
    }

    // ── Fondo: la pantalla que se aleja, teñida del color de la tarjeta ──
    Rectangle { anchors.fill: parent; color: "black"; opacity: TuDia.captura ? 1 : 0 }
    Item {
        anchors.fill: parent
        visible: TuDia.captura !== ""
        scale: 1 + .06 * c.p
        Image {
            id: captura
            anchors.fill: parent
            visible: false
            source: TuDia.captura ? "file://" + TuDia.captura + "?n=" + TuDia.numero : ""
            cache: false
            asynchronous: false
        }
        MultiEffect {
            anchors.fill: parent
            source: captura
            blurEnabled: true; blur: c.p; blurMax: 64
            brightness: -.45 * c.p
            saturation: -.4 * c.p
        }
    }
    Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: c.p * (TuDia.captura ? .55 : .96) }

    // Tres manchas de luz del color de la tarjeta que derivan muy despacio
    Item {
        anchors.fill: parent
        opacity: c.p
        property color tono: TuDia.tono
        Behavior on tono { ColorAnimation { duration: TuDia.largo; easing.type: Easing.InOutSine } }
        id: luces
        Repeater {
            model: [{ x: -.15, y: -.25, w: 1.0, f: .26, dx: .12, dy: .08, t: 17000 },
                    { x: .45, y: .35, w: .9, f: .2, dx: -.1, dy: -.12, t: 23000 },
                    { x: .1, y: .55, w: .7, f: .14, dx: .16, dy: -.06, t: 29000 }]
            Bruma {
                id: mancha
                required property var modelData
                width: c.width * modelData.w; height: width * .62
                x: c.width * modelData.x; y: c.height * modelData.y
                tono: luces.tono
                fuerza: modelData.f
                transform: Translate { id: deriva }
                SequentialAnimation {
                    running: TuDia.cine && c.visible
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: deriva; property: "x"; to: c.width * mancha.modelData.dx; duration: mancha.modelData.t; easing.type: Easing.InOutSine }
                        NumberAnimation { target: deriva; property: "y"; to: c.height * mancha.modelData.dy; duration: mancha.modelData.t; easing.type: Easing.InOutSine }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: deriva; property: "x"; to: 0; duration: mancha.modelData.t; easing.type: Easing.InOutSine }
                        NumberAnimation { target: deriva; property: "y"; to: 0; duration: mancha.modelData.t; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // ── Contenido ───────────────────────────────────────────────────────
    Item {
        id: teclas
        anchors.fill: parent
        focus: true
        opacity: c.p
        scale: .96 + .04 * c.p
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) TuDia.cerrar();
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (c.ultima) TuDia.cerrar(); else TuDia.siguiente(); }
            else if (e.key === Qt.Key_Left) TuDia.anterior();
            else if (e.key === Qt.Key_Space) c.pausado = !c.pausado;
            else return;
            e.accepted = true;
        }

        // Clic a la derecha: siguiente · a la izquierda: anterior · mantener: pausa
        MouseArea {
            anchors.fill: parent
            pressAndHoldInterval: 350
            onPressAndHold: { c.pausaPorPulsar = true; c.pausado = true; }
            onReleased: if (c.pausaPorPulsar) { c.pausaPorPulsar = false; c.pausado = false; }
            onClicked: (m) => {
                if (c.pausaPorPulsar) return;
                if (m.x < width * .3) TuDia.anterior(); else if (!c.ultima) TuDia.siguiente();
            }
        }

        // Las barritas de progreso, como en las historias
        Row {
            id: barritas
            anchors { top: parent.top; topMargin: 40; horizontalCenter: parent.horizontalCenter }
            spacing: 8
            readonly property real ancho: Math.min(720, c.width - 112)
            Repeater {
                model: TuDia.paginas.length
                Rectangle {
                    required property int index
                    width: (barritas.ancho - (TuDia.paginas.length - 1) * 8) / Math.max(1, TuDia.paginas.length)
                    height: 4
                    radius: height / 2
                    color: Qt.alpha(Paleta.texto, .18)
                    Rectangle {
                        height: parent.height; radius: height / 2
                        color: Paleta.texto
                        width: parent.width * (index < TuDia.pagina ? 1 : index === TuDia.pagina ? c.progreso : 0)
                    }
                }
            }
        }
        // Cerrar
        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 24; rightMargin: 40 }
            width: 36; height: 36; radius: height / 2
            color: cerrarRaton.containsMouse ? EstiloPanel.rellenoActivo : "transparent"
            Glifo {
                anchors.centerIn: parent; alto: 36
                text: String.fromCodePoint(0xF0156)
                color: Paleta.texto
                font { family: Paleta.mono; pixelSize: 20 }
            }
            MouseArea { id: cerrarRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: TuDia.cerrar() }
        }

        Loader {
            id: tarjetas
            anchors.centerIn: parent
            width: Math.min(1100, c.width - 112)
            height: Math.min(640, c.height - 200)
            active: c.visible
            sourceComponent: ({ portada: portada, pantalla: pantalla, apps: apps, ritmo: ritmo, racha: racha,
                                musica: musica, hiciste: hiciste, cierre: cierre, vacio: vacio })[c.mostrada] ?? null
        }

        // Ayuda de teclas
        Row {
            anchors { bottom: parent.bottom; bottomMargin: 40; horizontalCenter: parent.horizontalCenter }
            spacing: 24
            Repeater {
                model: c.pausado ? ["En pausa · Espacio para seguir"] : ["← → para moverte", "Espacio para pausar", "Esc para salir"]
                Text {
                    required property string modelData
                    text: modelData
                    color: c.pausado ? Paleta.texto : EstiloPanel.tenue
                    font { family: Paleta.fuente; pixelSize: 12 }
                }
            }
        }
    }

    // ── Las tarjetas ────────────────────────────────────────────────────
    Component {
        id: vacio
        Column {
            spacing: 16
            Item { width: 1; height: 120 }
            Aparece { anchors.horizontalCenter: parent.horizontalCenter
                Glifo { alto: 120; text: String.fromCodePoint(0xF0594); color: TuDia.tono; font { family: Paleta.mono; pixelSize: 104 } } }
            Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 150
                Text { text: c.sem ? "Aún no hay semana que contar" : "Aún no hay día que contar"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } } }
            Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 300
                Text { text: "Brújula va apuntando lo que usas. Vuelve más tarde."; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } } }
        }
    }

    Component {
        id: portada
        Item {
            Column {
                anchors.centerIn: parent
                spacing: 16
                Aparece { anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: c.sem ? "TU SEMANA" : "TU DÍA"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 150; desde: 48
                    Text { text: c.d.titulo ?? ""; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 62; bold: true } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 350
                    Text { text: c.sem ? c.rango(c.d.desde, c.d.dia) : c.fecha(c.d.dia); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 20 } } }
                Item { width: 1; height: 24 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Repeater {
                        model: [
                            c.sem ? { g: 0xF00ED, t: (c.d.diasActivos ?? 0) + " de 7 días activos" } : { g: 0xF0954, t: (c.d.hoy ? "Desde las " : "De ") + c.hora(c.d.inicio) + (c.d.hoy ? "" : " a " + c.hora(c.d.fin)) },
                            { g: 0xF0379, t: c.duracion(c.d.total) + " de pantalla" },
                            { g: 0xF003B, t: (c.d.numeroApps ?? 0) + " apps" }
                        ]
                        Aparece {
                            required property var modelData
                            required property int index
                            retraso: 600 + index * 120
                            escalaDesde: .8
                            Rectangle {
                                width: chip.implicitWidth + 32; height: 40; radius: height / 2
                                color: EstiloPanel.relleno
                                border { width: 1; color: EstiloPanel.borde }
                                Row {
                                    id: chip
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Glifo { alto: 40; text: String.fromCodePoint(modelData.g); color: TuDia.tono; font { family: Paleta.mono; pixelSize: 16 } }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.t; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14 } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pantalla
        Item {
            id: tarjetaPantalla
            readonly property int dif: (c.d.total ?? 0) - (c.d.media ?? 0)
            Column {
                anchors.centerIn: parent
                spacing: 12
                Aparece { anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: c.sem ? "Esta semana estuviste delante de la pantalla" : c.d.hoy ? "Hoy, hasta ahora, estuviste delante de la pantalla" : "Ese día estuviste delante de la pantalla"
                           color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 20 } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 200; escalaDesde: .85
                    Text {
                        property real v: 0
                        SequentialAnimation on v {
                            PauseAnimation { duration: TuDia.cine ? 200 : 0 }
                            NumberAnimation { to: c.d.total ?? 0; duration: TuDia.muyLargo; easing.type: Easing.OutCubic }
                        }
                        text: c.duracion(v)
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 104; bold: true }
                    } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 900
                    visible: (c.d.media ?? 0) > 0
                    Text {
                        text: c.sem ? (Math.abs(tarjetaPantalla.dif) < 3600 ? "Más o menos como la semana anterior"
                                   : c.duracion(Math.abs(tarjetaPantalla.dif)) + (tarjetaPantalla.dif > 0 ? " más" : " menos") + " que la semana anterior")
                            : Math.abs(tarjetaPantalla.dif) < 900 ? "Más o menos como cualquier día de la semana"
                            : c.duracion(Math.abs(tarjetaPantalla.dif)) + (tarjetaPantalla.dif > 0 ? " más" : " menos") + " que tu media de la semana" + (c.d.hoy ? ", por ahora" : "")
                        color: TuDia.tono
                        font { family: Paleta.fuente; pixelSize: 16; bold: true }
                    } }
                Item { width: 1; height: 32 }
                // La semana: 7 días anteriores + hoy
                Row {
                    id: semana
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16
                    readonly property var dias: c.sem ? (c.d.semana ?? []) : (c.d.semana ?? []).concat([{ letra: c.d.hoy ? "Hoy" : "Ese día", segundos: c.d.total ?? 0, hoy: true }])
                    readonly property real maximo: Math.max(1, ...dias.map(x => x.segundos))
                    Repeater {
                        model: semana.dias
                        Column {
                            required property var modelData
                            required property int index
                            spacing: 8
                            Item {
                                width: 48; height: 140
                                Rectangle {
                                    id: barra
                                    property real crece: 0
                                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                    width: 32
                                    height: Math.max(4, 140 * modelData.segundos / semana.maximo * crece)
                                    radius: 8
                                    color: modelData.hoy ? TuDia.tono : Qt.alpha(Paleta.texto, .18)
                                    SequentialAnimation on crece {
                                        PauseAnimation { duration: TuDia.cine ? 1000 + index * 70 : 0 }
                                        NumberAnimation { to: 1; duration: TuDia.largo; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                                    }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.letra
                                color: modelData.hoy ? Paleta.texto : EstiloPanel.tenue
                                font { family: Paleta.fuente; pixelSize: 12; bold: modelData.hoy === true }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: apps
        Item {
            readonly property var lista: c.d.apps ?? []
            readonly property var primera: lista[0] ?? null
            Row {
                anchors.centerIn: parent
                spacing: 56
                Column {
                    width: 380
                    spacing: 12
                    Item {
                        width: 380; height: 240
                        Bruma {
                            anchors.centerIn: parent
                            width: 420; height: 300
                            tono: c.color(0); fuerza: .4
                        }
                        Aparece {
                            anchors.centerIn: parent
                            escalaDesde: .3; desde: 0
                            IconoApp { app: primera; lado: 150 }
                        }
                    }
                    Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 400
                        Text { text: c.sem ? "TU APP DE LA SEMANA" : "TU APP DEL DÍA"; color: c.color(0); font { family: Paleta.fuente; pixelSize: 12; bold: true; letterSpacing: 4 } } }
                    Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 500
                        Text { width: Math.min(implicitWidth, 380); elide: Text.ElideRight; text: primera?.nombre ?? ""
                               color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 44; bold: true } } }
                    Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 650
                        Text { text: c.duracion(primera?.segundos ?? 0) + " · " + (primera?.porcentaje ?? 0) + (c.sem ? " % de tu semana" : " % de tu día")
                               color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 20 } } }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: lista.length > 1
                    width: 460
                    spacing: 16
                    Aparece { retraso: 800
                        Text { text: "Y después"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 14; bold: true } } }
                    Repeater {
                        model: lista.slice(1)
                        Aparece {
                            id: fila
                            required property var modelData
                            required property int index
                            retraso: 950 + index * 150
                            desde: 0
                            Row {
                                spacing: 16
                                IconoApp { app: fila.modelData; lado: 40; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    spacing: 8
                                    Item {
                                        width: 400; height: nombreApp.implicitHeight
                                        Text { id: nombreApp; width: 280; elide: Text.ElideRight; text: fila.modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14; bold: true } }
                                        Text { anchors.right: parent.right; text: c.duracion(fila.modelData.segundos); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                                    }
                                    Rectangle {
                                        width: 400; height: 8; radius: height / 2
                                        color: Qt.alpha(Paleta.texto, .1)
                                        Rectangle {
                                            property real crece: 0
                                            height: parent.height; radius: height / 2
                                            width: Math.max(height, parent.width * fila.modelData.segundos / Math.max(1, primera?.segundos ?? 1) * crece)
                                            color: c.color(fila.index + 1)
                                            SequentialAnimation on crece {
                                                PauseAnimation { duration: TuDia.cine ? 1100 + fila.index * 150 : 0 }
                                                NumberAnimation { to: 1; duration: TuDia.largo; easing.type: Easing.OutCubic }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ritmo
        Item {
            readonly property var horas: c.d.horas ?? []
            readonly property int pico: c.d.horaPico ?? -1
            readonly property real maximo: Math.max(1, ...horas)
            Column {
                anchors.centerIn: parent
                spacing: 12
                Aparece { anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: "TU RITMO"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 150
                    Text { text: pico >= 0 ? `Tu hora fuerte: de ${pico}:00 a ${pico + 1}:00` : ""
                           color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 300
                    Text { text: c.sem ? `Tus días solían empezar hacia las ${c.hora(c.d.inicio)} y acabar hacia las ${c.hora(c.d.fin)}`
                               + ((c.d.madrugada ?? 0) >= 1800 ? ` · ${c.duracion(c.d.madrugada)} de trasnocho en total` : "")
                               : `Empezaste a las ${c.hora(c.d.inicio)}` + (c.d.hoy ? " y sigues aquí" : ` y lo último fue a las ${c.hora(c.d.fin)}`)
                               + ((c.d.madrugada ?? 0) >= 600 ? ` · antes, ${c.duracion(c.d.madrugada)} de trasnocho` : "")
                           color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } } }
                Item { width: 1; height: 40 }
                Item {
                    id: grafica
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(900, c.width - 160); height: 260
                    readonly property real columna: (width - 23 * 8) / 24
                    // Halo detrás de la hora fuerte
                    Bruma {
                        visible: pico >= 0
                        width: 260; height: 260
                        x: pico * (grafica.columna + 8) + grafica.columna / 2 - width / 2
                        y: 220 - 220 * (horas[pico] ?? 0) / maximo - 40
                        tono: TuDia.tono; fuerza: .35
                    }
                    Row {
                        spacing: 8
                        Repeater {
                            model: 24
                            Column {
                                required property int index
                                spacing: 12
                                Item {
                                    width: grafica.columna; height: 220
                                    Rectangle {
                                        property real crece: 0
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(4, 220 * (horas[index] ?? 0) / maximo * crece)
                                        radius: 4
                                        color: index === pico ? TuDia.tono : Qt.alpha(Paleta.texto, (horas[index] ?? 0) > 0 ? .3 : .08)
                                        SequentialAnimation on crece {
                                            PauseAnimation { duration: TuDia.cine ? 500 + index * 45 : 0 }
                                            NumberAnimation { to: 1; duration: TuDia.largo; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                                        }
                                    }
                                }
                                Text {
                                    width: grafica.columna
                                    horizontalAlignment: Text.AlignHCenter
                                    text: index % 6 === 0 || index === pico ? String(index) : ""
                                    color: index === pico ? Paleta.texto : EstiloPanel.tenue
                                    font { family: Paleta.mono; pixelSize: 11; bold: index === pico }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: racha
        Item {
            readonly property var r: c.d.racha ?? ({})
            Row {
                anchors.centerIn: parent
                spacing: 56
                Item {
                    width: 340; height: 340
                    anchors.verticalCenter: parent.verticalCenter
                    Bruma { anchors.centerIn: parent; width: 420; height: 420; tono: TuDia.tono; fuerza: .22 }
                    Canvas {
                        id: anillo
                        anchors.fill: parent
                        property real avance: 0
                        readonly property real fraccion: Math.min(1, (r.segundos ?? 0) / Math.max(1, c.d.total ?? 1))
                        onAvanceChanged: requestPaint()
                        SequentialAnimation on avance {
                            PauseAnimation { duration: TuDia.cine ? 300 : 0 }
                            NumberAnimation { to: 1; duration: TuDia.muyLargo; easing.type: Easing.OutCubic }
                        }
                        onPaint: {
                            const g = getContext("2d"), m = width / 2, rad = m - 16;
                            g.reset();
                            g.lineWidth = 16; g.lineCap = "round";
                            g.strokeStyle = c.css(Qt.alpha(Paleta.texto, .1));
                            g.beginPath(); g.arc(m, m, rad, 0, 2 * Math.PI); g.stroke();
                            g.strokeStyle = c.css(TuDia.tono);
                            g.beginPath(); g.arc(m, m, rad, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * fraccion * avance); g.stroke();
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        IconoApp { anchors.horizontalCenter: parent.horizontalCenter; app: r; lado: 48 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            property real v: 0
                            SequentialAnimation on v {
                                PauseAnimation { duration: TuDia.cine ? 300 : 0 }
                                NumberAnimation { to: r.segundos ?? 0; duration: TuDia.muyLargo; easing.type: Easing.OutCubic }
                            }
                            text: c.duracion(v)
                            color: Paleta.texto
                            font { family: Paleta.fuente; pixelSize: 36; bold: true }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "seguidos"
                            color: EstiloPanel.tenue
                            font { family: Paleta.fuente; pixelSize: 13 }
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 500
                    spacing: 12
                    Aparece { retraso: 200
                        Text { text: "TU RACHA MÁS LARGA"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                    Aparece { retraso: 350
                        Text { width: 500; wrapMode: Text.WordWrap; text: `Sin soltar ${r.nombre ?? ""}`
                               color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 44; bold: true } } }
                    Aparece { retraso: 500
                        Text { text: (c.sem ? c.nombreDia(r.dia).charAt(0).toUpperCase() + c.nombreDia(r.dia).slice(1) + `, de ${c.hora(r.inicio)}` : `De ${c.hora(r.inicio)}`)
                               + ` a ${c.hora((r.inicio ?? 0) + (r.segundos ?? 0))} · ${Math.round(100 * anillo.fraccion)} % de tu ${c.sem ? "semana" : "día"}`
                               color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } } }
                    Item { width: 1; height: 32 }
                    Aparece { retraso: 1100
                        Row {
                            spacing: 12
                            Glifo { alto: 36; text: String.fromCodePoint(0xF04E1); color: Paleta.acento2; font { family: Paleta.mono; pixelSize: 20 } }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: `Cambiaste de app ${c.d.saltos ?? 0} veces`
                                   color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20 } }
                        } }
                    Aparece { retraso: 1300
                        visible: Concentracion.sesionesHoy > 0 && c.d.hoy === true
                        Row {
                            spacing: 12
                            Glifo { alto: 36; text: String.fromCodePoint(0xF08C9); color: Paleta.exito; font { family: Paleta.mono; pixelSize: 20 } }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   text: Concentracion.sesionesHoy === 1 ? "y completaste una sesión de concentración" : `y completaste ${Concentracion.sesionesHoy} sesiones de concentración`
                                   color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 20 } }
                        } }
                }
            }
        }
    }

    Component {
        id: musica
        Item {
            readonly property var m: c.d.musica ?? ({})
            readonly property var cancion: m.cancion ?? ({})
            Row {
                anchors.centerIn: parent
                spacing: 56
                Item {
                    width: 320; height: 320
                    anchors.verticalCenter: parent.verticalCenter
                    // La carátula derrama su luz (una copia enorme y desenfocada detrás)
                    Image {
                        id: luz
                        anchors.centerIn: parent
                        width: 320; height: 320
                        visible: false
                        source: cancion.caratula ?? ""
                        asynchronous: true
                    }
                    MultiEffect {
                        anchors.centerIn: parent
                        width: 320; height: 320
                        scale: 1.35
                        visible: luz.status === Image.Ready
                        source: luz
                        blurEnabled: true; blur: 1; blurMax: 64
                        saturation: .4
                        opacity: .75
                    }
                    Aparece {
                        anchors.centerIn: parent
                        escalaDesde: .6; desde: 0
                        ClippingRectangle {
                            id: disco
                            width: 280; height: 280; radius: 16
                            color: EstiloPanel.elevada
                            Image {
                                anchors.fill: parent
                                source: cancion.caratula ?? ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize { width: 560; height: 560 }
                                asynchronous: true
                            }
                            Glifo {
                                anchors.centerIn: parent; alto: 280
                                visible: !cancion.caratula
                                text: String.fromCodePoint(0xF075A)
                                color: TuDia.tono
                                font { family: Paleta.mono; pixelSize: 104 }
                            }
                            SequentialAnimation on scale {   // respira, como si sonara
                                running: TuDia.cine
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.025; duration: 2200; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 2200; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 520
                    spacing: 12
                    Aparece { retraso: 300
                        Text { text: c.sem ? "LA CANCIÓN DE LA SEMANA" : "LA CANCIÓN DEL DÍA"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                    Aparece { retraso: 450
                        Text { width: 520; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: cancion.titulo ?? ""
                               color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 44; bold: true } } }
                    Aparece { retraso: 600
                        Text { width: 520; elide: Text.ElideRight; text: cancion.artista ?? ""; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 20 } } }
                    Item { width: 1; height: 24 }
                    Aparece { retraso: 900
                        Text { text: `Sonó ${c.duracion(cancion.segundos ?? 0)} · ${m.canciones ?? 0} canciones en total (${c.duracion(m.segundos ?? 0)})`
                               color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16 } } }
                    Aparece { retraso: 1050
                        visible: (m.artista ?? "") !== ""
                        Text { text: `Lo que más sonó: ${m.artista ?? ""}`; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } } }
                    Item { width: 1; height: 12 }
                    Repeater {
                        model: m.otras ?? []
                        Aparece {
                            required property var modelData
                            required property int index
                            retraso: 1250 + index * 120
                            desde: 12
                            Text { width: 520; elide: Text.ElideRight; text: `${index + 2}.  ${modelData.titulo}` + (modelData.artista ? ` — ${modelData.artista}` : "")
                                   color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 14 } }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: hiciste
        Item {
            readonly property var datosCifras: [
                { g: 0xF0100, n: c.d.capturas ?? 0, t: "capturas" },
                { g: 0xF0214, n: c.d.archivos ?? 0, t: "archivos abiertos" },
                { g: 0xF003B, n: c.d.numeroApps ?? 0, t: "apps distintas" },
                { g: 0xF08C9, n: c.d.hoy ? Concentracion.sesionesHoy : 0, t: "sesiones de concentración" }
            ].filter(x => x.n > 0)
            Column {
                anchors.centerIn: parent
                spacing: 16
                Aparece { anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: "LO QUE HICISTE"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                Aparece { anchors.horizontalCenter: parent.horizontalCenter; retraso: 150
                    Text { text: "Y entre tanto…"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } } }
                Item { width: 1; height: 32 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16
                    Repeater {
                        model: datosCifras
                        Aparece {
                            required property var modelData
                            required property int index
                            retraso: 350 + index * 140
                            escalaDesde: .85
                            Rectangle {
                                width: 220; height: 200; radius: 16
                                color: EstiloPanel.relleno
                                border { width: 1; color: EstiloPanel.borde }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Glifo { anchors.horizontalCenter: parent.horizontalCenter; alto: 36; text: String.fromCodePoint(modelData.g); color: c.color(index + 1); font { family: Paleta.mono; pixelSize: 26 } }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        property real v: 0
                                        SequentialAnimation on v {
                                            PauseAnimation { duration: TuDia.cine ? 450 + index * 140 : 0 }
                                            NumberAnimation { to: modelData.n; duration: TuDia.muyLargo; easing.type: Easing.OutCubic }
                                        }
                                        text: Math.round(v)
                                        color: Paleta.texto
                                        font { family: Paleta.fuente; pixelSize: 62; bold: true }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                                }
                            }
                        }
                    }
                }
                Item { width: 1; height: 24 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Repeater {
                        model: c.d.contextos ?? []
                        Aparece {
                            required property var modelData
                            required property int index
                            retraso: 1000 + index * 120
                            desde: 12
                            Rectangle {
                                width: ctx.implicitWidth + 32; height: 36; radius: height / 2
                                color: EstiloPanel.relleno
                                border { width: 1; color: EstiloPanel.borde }
                                Row {
                                    id: ctx
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: height / 2; color: TuDia.tono }
                                    Text { text: `${modelData.nombre} · ${c.duracion(modelData.segundos)}`; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 13 } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: cierre
        Item {
            readonly property int h: new Date().getHours()
            readonly property string saludo: c.sem ? `Así fue tu semana` + (c.d.mejorDia ? ` · lo más fuerte, ${c.nombreDia(c.d.mejorDia)}` : "")
                : !c.d.hoy ? "Así fue ese día"
                : (h >= 20 || h < 5 ? "Buen descanso" : h >= 13 ? "Buena tarde" : "Buen día") + (c.nombre ? ", " + c.nombre : "")
            Row {
                anchors.centerIn: parent
                spacing: 56
                // El día como un reloj de 24 h: cada tramo, del color de su app
                Item {
                    width: 420; height: 420
                    anchors.verticalCenter: parent.verticalCenter
                    Bruma { anchors.centerIn: parent; width: 520; height: 520; tono: TuDia.tono; fuerza: .16 }
                    Canvas {
                        id: reloj
                        anchors.fill: parent
                        property real revelado: 0
                        onReveladoChanged: requestPaint()
                        SequentialAnimation on revelado {
                            PauseAnimation { duration: TuDia.cine ? 250 : 0 }
                            NumberAnimation { to: 1; duration: TuDia.cine ? 2200 : 0; easing.type: Easing.InOutCubic }
                        }
                        function angulo(t) {
                            const f = new Date(t * 1000);
                            return -Math.PI / 2 + 2 * Math.PI * (f.getHours() * 3600 + f.getMinutes() * 60 + f.getSeconds()) / 86400;
                        }
                        onPaint: {
                            const g = getContext("2d"), m = width / 2, rad = m - 40;
                            const limite = -Math.PI / 2 + 2 * Math.PI * revelado;
                            g.reset();
                            g.lineCap = "butt";
                            g.lineWidth = 26;
                            g.strokeStyle = c.css(Qt.alpha(Paleta.texto, .07));
                            g.beginPath(); g.arc(m, m, rad, 0, 2 * Math.PI); g.stroke();
                            // marcas de cada hora
                            g.strokeStyle = c.css(Qt.alpha(Paleta.texto, .22)); g.lineWidth = 2;
                            for (let i = 0; i < 24; i++) {
                                if (i % 6 === 0) continue;                 // ahí va el número
                                const a = -Math.PI / 2 + i * Math.PI / 12, l = 5;
                                g.beginPath();
                                g.moveTo(m + Math.cos(a) * (rad + 18), m + Math.sin(a) * (rad + 18));
                                g.lineTo(m + Math.cos(a) * (rad + 18 + l), m + Math.sin(a) * (rad + 18 + l));
                                g.stroke();
                            }
                            g.lineWidth = 26;
                            for (const t of (c.d.tramos ?? [])) {
                                const a0 = angulo(t.inicio);
                                let a1 = angulo(t.fin);
                                if (a1 < a0) a1 = 3 * Math.PI / 2;          // pasa de medianoche: hasta el final
                                if (a0 >= limite) continue;
                                g.strokeStyle = c.css(c.color(t.app));
                                g.beginPath(); g.arc(m, m, rad, a0, Math.max(a0 + .006, Math.min(a1, limite))); g.stroke();
                            }
                            // ahora
                            if (c.d.hoy && revelado >= 1) {
                                const a = angulo(Date.now() / 1000);
                                g.fillStyle = c.css(Paleta.texto);
                                g.beginPath(); g.arc(m + Math.cos(a) * rad, m + Math.sin(a) * rad, 6, 0, 2 * Math.PI); g.fill();
                            }
                        }
                    }
                    Repeater {   // 0 · 6 · 12 · 18
                        model: [0, 6, 12, 18]
                        Text {
                            required property int modelData
                            readonly property real a: -Math.PI / 2 + modelData * Math.PI / 12
                            x: 210 + Math.cos(a) * 196 - width / 2
                            y: 210 + Math.sin(a) * 196 - height / 2
                            text: String(modelData)
                            color: EstiloPanel.tenue
                            font { family: Paleta.mono; pixelSize: 11 }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: c.duracion(c.d.total ?? 0); color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "de pantalla"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 440
                    spacing: 12
                    Aparece { retraso: 200
                        Text { text: c.sem ? "TU SEMANA EN UN CÍRCULO" : "TU DÍA EN UN CÍRCULO"; color: TuDia.tono; font { family: Paleta.fuente; pixelSize: 14; bold: true; letterSpacing: 6 } } }
                    Aparece { retraso: 350
                        Text { width: 440; wrapMode: Text.WordWrap; text: saludo; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 44; bold: true } } }
                    Item { width: 1; height: 12 }
                    Repeater {
                        model: (c.d.apps ?? []).concat((c.d.otras ?? 0) > 0 ? [{ nombre: "Otras", segundos: c.d.otras, otra: true }] : [])
                        Aparece {
                            required property var modelData
                            required property int index
                            retraso: 600 + index * 110
                            desde: 12
                            Item {
                                width: 440; height: 24
                                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: height / 2; color: c.color(modelData.otra ? -1 : index) }
                                Text { x: 24; anchors.verticalCenter: parent.verticalCenter; width: 300; elide: Text.ElideRight; text: modelData.nombre; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 14 } }
                                Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter } text: c.duracion(modelData.segundos); color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 13 } }
                            }
                        }
                    }
                    Item { width: 1; height: 24 }
                    Aparece { retraso: 1400
                        Row {
                            spacing: 12
                            BotonPanel {
                                visible: c.d.hoy === true && h >= 17
                                width: 180
                                text: "Cerrar el día"
                                simbolo: String.fromCodePoint(0xF0594)
                                destacado: true
                                onClicked: TuDia.cerrarJornada()
                            }
                            BotonPanel {
                                width: 140
                                text: "Listo"
                                onClicked: TuDia.cerrar()
                            }
                        }
                    }
                }
            }
        }
    }
}
