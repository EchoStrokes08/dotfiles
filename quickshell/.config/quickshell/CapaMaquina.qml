// CapaMaquina: lo que se ve de la máquina del tiempo (estado en Maquina.qml).
// Tu pantalla se encoge hasta ser la primera tarjeta de una pila que se pierde hacia el fondo; detrás,
// los momentos del día, cada uno más atrás en el tiempo. Viajar: rueda o ↑ ↓ (las tarjetas pasan junto a ti),
// clic en una del fondo o en la regla de la derecha. ← → cambia de día, Intro abre la app del momento,
// Inicio vuelve al presente, Esc sale (si estabas en el pasado, primero vuelves volando al presente).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: c
    screen: Quickshell.screens.find(s => s.name === Maquina.pantalla) ?? null
    visible: Maquina.activa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-maquina"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property real p: 0                   // 0 = tu pantalla tal cual · 1 = la pila
    property real pos: Maquina.indice    // posición continua en la pila (anima entre tarjetas)
    Behavior on pos { NumberAnimation { duration: Maquina.medio; easing.type: Easing.OutCubic } }
    readonly property bool conAhora: Maquina.tarjetas[0]?.ahora === true

    // Geometría de la pila: la tarjeta frontal ocupa el 56 % del ancho; las de atrás suben hacia el
    // punto de fuga y se encogen; las que ya pasaste crecen y se desvanecen junto a la cámara.
    readonly property real anchoT: width * .56
    readonly property real altoT: anchoT * height / Math.max(1, width)
    readonly property real baseY: height * .55
    function escala(d) { return d >= 0 ? Math.pow(.84, d) : 1 - d * .5; }
    function centroY(d) { return d >= 0 ? baseY - (1 - Math.pow(.84, d)) * height * .46 : baseY + (-d) * height * .25; }
    function hora(t) { return t ? Qt.formatTime(new Date(t * 1000), "H:mm") : ""; }
    function etiquetaDia(dia) {
        if (!dia) return "";
        const f = new Date(dia + "T12:00:00"), hoy = new Date();
        const ayer = new Date(); ayer.setDate(hoy.getDate() - 1);
        if (f.toDateString() === hoy.toDateString()) return "Hoy";
        if (f.toDateString() === ayer.toDateString()) return "Ayer";
        const t = f.toLocaleDateString(Qt.locale("es_CO"), "dddd d 'de' MMMM");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }
    SystemClock { id: reloj; precision: SystemClock.Minutes }

    // ── Entrar y salir ─────────────────────────────────────────────────
    onVisibleChanged: if (visible) { p = 0; entrar.restart(); teclas.forceActiveFocus(); }   // pos sigue a Maquina.indice (no asignarla: rompe el enlace)
    NumberAnimation { id: entrar; target: c; property: "p"; to: 1; duration: Maquina.largo; easing.type: Easing.OutCubic }
    Connections {
        target: Maquina
        function onSaliendoChanged() {
            if (!Maquina.saliendo) return;
            entrar.stop();
            if (Maquina.indice > 0 && c.conAhora) { Maquina.ir(0); volverYSalir.restart(); }   // de vuelta al presente
            else salir.restart();
        }
    }
    SequentialAnimation {
        id: salir
        NumberAnimation { target: c; property: "p"; to: 0; duration: Maquina.largo; easing.type: Easing.InOutCubic }
        ScriptAction { script: Maquina.terminar() }
    }
    SequentialAnimation {
        id: volverYSalir
        PauseAnimation { duration: Maquina.medio }
        NumberAnimation { target: c; property: "p"; to: 0; duration: Maquina.largo; easing.type: Easing.InOutCubic }
        ScriptAction { script: Maquina.terminar() }
    }

    // ── Fondo: tu pantalla, muy desenfocada, y una luz en el punto de fuga ──
    Rectangle { anchors.fill: parent; color: "black"; opacity: Maquina.captura ? 1 : c.p }
    Item {
        anchors.fill: parent
        visible: Maquina.captura !== ""
        opacity: c.conAhora ? 1 : c.p
        scale: 1 + .1 * c.p
        Image {
            id: fondo
            anchors.fill: parent
            visible: false
            source: Maquina.captura ? "file://" + Maquina.captura + "?n=" + Maquina.numero : ""
            cache: false
        }
        MultiEffect {
            anchors.fill: parent
            source: fondo
            blurEnabled: true; blur: c.p; blurMax: 64
            brightness: -.6 * c.p
            saturation: -.5 * c.p
        }
    }
    Bruma {
        id: fuga
        property color tinte: Maquina.color(Maquina.actual?.app ?? -1)
        Behavior on tinte { ColorAnimation { duration: Maquina.largo } }
        width: c.width * 1.1; height: c.height * .8
        x: (c.width - width) / 2; y: c.baseY - c.height * .46 - height / 2
        tono: tinte
        fuerza: .22 * c.p
    }

    Item {
        id: teclas
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) Maquina.cerrar();
            else if (e.key === Qt.Key_Up) Maquina.atras();
            else if (e.key === Qt.Key_Down) Maquina.adelante();
            else if (e.key === Qt.Key_Home) Maquina.ir(0);
            else if (e.key === Qt.Key_T) Maquina.verTitulos = !Maquina.verTitulos;
            else if (e.key === Qt.Key_End) Maquina.ir(Maquina.tarjetas.length - 1);
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_PageUp) Maquina.cambiarDia(1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_PageDown) Maquina.cambiarDia(-1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (Maquina.actual?.ahora) Maquina.cerrar(); else if (Maquina.actual) Maquina.abrirApp(Maquina.actual);
            } else return;
            e.accepted = true;
        }

        // Rueda: alejar = atrás en el tiempo
        MouseArea {
            anchors.fill: parent
            property real acumulado: 0
            onWheel: (w) => {
                acumulado += w.angleDelta.y;
                while (acumulado >= 120) { Maquina.atras(); acumulado -= 120; }
                while (acumulado <= -120) { Maquina.adelante(); acumulado += 120; }
            }
            onClicked: Maquina.cerrar()       // clic en el vacío: salir
        }

        // ── La pila ──
        Repeater {
            model: Maquina.tarjetas
            Item {
                id: tarjeta
                required property var modelData
                required property int index
                readonly property real d: index - c.pos + (index === 0 && c.conAhora ? 0 : (1 - c.p) * 3)
                readonly property bool cerca: d > -1.2 && d < 9
                // La primera («ahora») empieza ocupando toda la pantalla y se encoge a su sitio
                readonly property real llena: index === 0 && c.conAhora ? 1 - c.p : 0
                visible: cerca && opacity > .01
                width: c.anchoT; height: c.altoT
                x: (c.width - width) / 2
                y: (c.centroY(d) * (1 - llena) + c.height / 2 * llena) - height / 2
                scale: c.escala(d) * (1 - llena) + (c.width / c.anchoT) * llena
                z: 100 - d
                opacity: (d >= 0 ? Math.max(0, Math.min(1, 8 - d)) : Math.max(0, 1 + d * 1.6)) * (index === 0 && c.conAhora ? 1 : c.p)
                Loader {
                    anchors.fill: parent
                    active: tarjeta.cerca
                    sourceComponent: Component {
                        PostalMomento {
                            m: tarjeta.modelData
                            oscuro: Math.max(0, Math.min(.8, tarjeta.d * .14))
                            // solo con el ratón sobre la franja de los títulos de la tarjeta del frente
                            discreto: !Maquina.verTitulos && !(Math.abs(tarjeta.d) < .5 && raton.containsMouse
                                                               && raton.mouseY > tarjeta.height * .33 && raton.mouseY < tarjeta.height * .75)
                        }
                    }
                }
                MouseArea {
                    id: raton
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: tarjeta.d > -.5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Math.abs(tarjeta.d) < .5) { if (tarjeta.modelData.ahora) Maquina.cerrar(); }
                        else Maquina.ir(tarjeta.index);
                    }
                    onWheel: (w) => { w.accepted = false; }
                }
            }
        }

        // ── Cabecera: la hora del momento al frente ──
        Column {
            z: 200
            anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 40 }
            spacing: 4
            opacity: c.p
            Text {
                text: Maquina.actual?.ahora ? Qt.formatTime(reloj.date, "H:mm") : c.hora(Maquina.actual?.inicio)
                color: Paleta.texto
                font { family: Paleta.fuente; pixelSize: 62; bold: true }
            }
            Text {
                text: (Maquina.actual?.ahora ? "Ahora" : Maquina.actual?.nombre ?? "") + " · " + c.etiquetaDia(Maquina.datos?.dia)
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 16 }
            }
        }

        // ── Días y cerrar ──
        Row {
            z: 200
            anchors { right: parent.right; top: parent.top; rightMargin: 40; topMargin: 40 }
            spacing: 8
            opacity: c.p
            Repeater {
                model: [{ g: 0xF0141, d: 1 }, { g: 0, d: 0 }, { g: 0xF0142, d: -1 }, { g: 0xF0156, d: 99 }]
                Rectangle {
                    required property var modelData
                    readonly property bool puede: modelData.d === 99 || (modelData.d !== 0 && Maquina.posDia + modelData.d >= 0 && Maquina.posDia + modelData.d < Maquina.numDias)
                    width: modelData.d === 0 ? etiqueta.implicitWidth + 32 : 40; height: 40; radius: height / 2
                    color: modelData.d === 0 ? EstiloPanel.relleno : raton.containsMouse && puede ? EstiloPanel.rellenoActivo : "transparent"
                    border { width: modelData.d === 0 ? 1 : 0; color: EstiloPanel.borde }
                    opacity: modelData.d === 0 || puede ? 1 : .35
                    Text {
                        id: etiqueta
                        anchors.centerIn: parent
                        visible: modelData.d === 0
                        text: Maquina.cargando ? "Cargando…" : c.etiquetaDia(Maquina.datos?.dia)
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 13; bold: true }
                    }
                    Glifo {
                        anchors.centerIn: parent; alto: 40
                        visible: modelData.d !== 0
                        text: modelData.g ? String.fromCodePoint(modelData.g) : ""
                        color: Paleta.texto
                        font { family: Paleta.mono; pixelSize: 20 }
                    }
                    MouseArea {
                        id: raton
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: modelData.d !== 0 && parent.puede
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.d === 99 ? Maquina.cerrar() : Maquina.cambiarDia(modelData.d)
                    }
                }
            }
        }

        // ── La regla del día (arriba lo más antiguo, abajo el presente) ──
        Item {
            id: regla
            z: 200
            anchors { right: parent.right; rightMargin: 56; top: parent.top; topMargin: c.height * .18; bottom: parent.bottom; bottomMargin: c.height * .18 }
            width: 8
            opacity: c.p
            visible: (Maquina.datos?.momentos ?? []).length > 0
            readonly property var ms: Maquina.datos?.momentos ?? []
            readonly property real t0: ms.length ? Math.min(...ms.map(m => m.inicio)) : 0
            readonly property real fin: ms.length ? Math.max(...ms.map(m => m.fin)) : 1
            readonly property real t1: Maquina.hoy ? Math.max(fin, reloj.date.getTime() / 1000) : fin
            function yDe(t) { return (t - t0) / Math.max(1, t1 - t0) * height; }
            function tiempoDe(m) { return m?.ahora ? t1 : (m?.inicio ?? t0); }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 2; height: parent.height; radius: width / 2; color: Qt.alpha(Paleta.texto, .12) }
            Repeater {
                model: regla.ms
                Rectangle {
                    required property var modelData
                    readonly property bool enfoque: Maquina.actual === modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: regla.yDe(modelData.inicio)
                    width: enfoque ? 8 : 6
                    height: Math.max(3, regla.yDe(modelData.fin) - y)
                    radius: 4
                    color: Maquina.color(modelData.app)
                    opacity: enfoque ? 1 : .5
                }
            }
            // Las horas
            Repeater {
                model: {
                    // Ojo: t0 y t1 pueden llegar desfasados un instante (0 → 1970): nunca más de 26 marcas
                    const res = [], span = regla.t1 - regla.t0, paso = span > 8 * 3600 ? 7200 : 3600;
                    if (!(regla.t0 > 0) || span <= 0 || span > 26 * 3600) return res;
                    const f = new Date(regla.t0 * 1000); f.setMinutes(0, 0, 0);
                    for (let t = f.getTime() / 1000 + 3600; t < regla.t1 && res.length < 26; t += paso) res.push(t);
                    return res;
                }
                Text {
                    required property real modelData
                    anchors.right: parent.left; anchors.rightMargin: 12
                    y: regla.yDe(modelData) - height / 2
                    text: c.hora(modelData)
                    color: EstiloPanel.tenue
                    font { family: Paleta.mono; pixelSize: 11 }
                }
            }
            // El marcador del momento al frente
            Rectangle {
                id: marcador
                anchors.horizontalCenter: parent.horizontalCenter
                width: 16; height: 16; radius: height / 2
                y: regla.yDe(regla.tiempoDe(Maquina.actual)) - height / 2
                Behavior on y { NumberAnimation { duration: Maquina.medio; easing.type: Easing.OutCubic } }
                color: Paleta.texto
                border { width: 4; color: Maquina.color(Maquina.actual?.app ?? -1) }
            }
            MouseArea {
                anchors { fill: parent; leftMargin: -24; rightMargin: -24 }
                cursorShape: Qt.PointingHandCursor
                function elegir(py) {
                    const t = regla.t0 + py / Math.max(1, regla.height) * (regla.t1 - regla.t0);
                    let mejor = 0, dist = Infinity;
                    Maquina.tarjetas.forEach((m, i) => {
                        const a = m.ahora ? regla.t1 : m.inicio, b = m.ahora ? regla.t1 : m.fin;
                        const dd = t < a ? a - t : t > b ? t - b : 0;
                        if (dd < dist) { dist = dd; mejor = i; }
                    });
                    Maquina.ir(mejor);
                }
                onPressed: (m) => elegir(m.y)
                onPositionChanged: (m) => { if (pressed) elegir(m.y); }
            }
        }

        // ── Vacío o privado ──
        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: c.height * .18 }
            visible: !!Maquina.datos && (Maquina.datos.momentos ?? []).length === 0
            opacity: c.p
            text: Maquina.datos?.privado ? "Con la privacidad activa, la línea de tiempo no se muestra"
                                         : "Brújula aún no tiene momentos de este día"
            color: EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 16 }
        }

        // ── Acciones del momento al frente ──
        Column {
            z: 200
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 24 }
            spacing: 12
            opacity: c.p
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                visible: !!Maquina.actual && !Maquina.actual.ahora
                BotonPanel {
                    width: Math.max(180, implicitContentWidth + 40)
                    text: "Abrir " + (Maquina.actual?.nombre ?? "")
                    destacado: true
                    tinte: Maquina.color(Maquina.actual?.app ?? -1)
                    onClicked: Maquina.abrirApp(Maquina.actual)
                }
                Repeater {
                    model: Maquina.actual?.archivos ?? []
                    BotonPanel {
                        required property var modelData
                        width: Math.min(220, implicitContentWidth + 40)
                        text: modelData.nombre
                        simbolo: String.fromCodePoint(0xF0214)
                        onClicked: Maquina.abrirArchivo(modelData.ruta)
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Maquina.actual?.ahora ? "Rueda o ↑ para viajar hacia atrás por tu día · ← → otro día · Esc salir"
                                            : "↑ ↓ viajar · Intro abrir · T " + (Maquina.verTitulos ? "ocultar" : "mostrar") + " títulos · Inicio volver al presente · Esc salir"
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 12 }
            }
        }
    }
}
