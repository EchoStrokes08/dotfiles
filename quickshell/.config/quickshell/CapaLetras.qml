// CapaLetras: la letra en modo cine (estado en Letras.qml).
// El fondo es la carátula, enorme, desenfocada y girando despacio en dos capas; late con los graves (cava).
// A la izquierda, la carátula, la canción, el progreso y los controles; a la derecha la letra: la línea que
// suena se enciende de izquierda a derecha mientras se canta y las demás se apagan con la distancia.
// Teclado: Espacio pausa · ← → 5 s · ↑ ↓ canción anterior / siguiente · Esc salir. Clic en una línea: ir ahí.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: c
    screen: Quickshell.screens.find(s => s.name === Letras.pantalla) ?? null
    visible: Letras.activa
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-letras"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property real p: 0
    readonly property real bajo: Math.min(1, ((Isla.ondas[0] ?? 0) + (Isla.ondas[1] ?? 0)) / 200)
    function mmss(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    function escapar(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
    function hex(k) {   // #aarrggbb para el texto enriquecido
        const h = x => Math.round(x * 255).toString(16).padStart(2, "0");
        return "#" + h(k.a) + h(k.r) + h(k.g) + h(k.b);
    }

    onVisibleChanged: if (visible) { p = 0; entrar.restart(); teclas.forceActiveFocus(); }
    NumberAnimation { id: entrar; target: c; property: "p"; to: 1; duration: Letras.largo; easing.type: Easing.OutCubic }
    Connections {
        target: Letras
        function onSaliendoChanged() { if (Letras.saliendo) { entrar.stop(); salir.restart(); } }
    }
    SequentialAnimation {
        id: salir
        NumberAnimation { target: c; property: "p"; to: 0; duration: Letras.medio; easing.type: Easing.InCubic }
        ScriptAction { script: Letras.terminar() }
    }

    // ── Fondo: la carátula hecha luz ───────────────────────────────────
    Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: c.p }
    Item {
        anchors.fill: parent
        opacity: c.p
        clip: true
        Image {
            id: fuente
            width: 512; height: 512
            visible: false
            source: Letras.caratula
            sourceSize { width: 512; height: 512 }
            asynchronous: true
        }
        Repeater {
            model: [{ e: 1.9, v: 1, t: 90000, o: 1 }, { e: 1.4, v: -1, t: 70000, o: .6 }]
            MultiEffect {
                required property var modelData
                anchors.centerIn: parent
                width: Math.max(c.width, c.height) * modelData.e; height: width
                source: fuente
                visible: fuente.status === Image.Ready
                blurEnabled: true; blur: 1; blurMax: 64
                saturation: .35
                brightness: -.25
                opacity: modelData.o
                RotationAnimation on rotation {
                    running: Letras.cine && c.visible
                    loops: Animation.Infinite
                    from: 0; to: 360 * modelData.v
                    duration: modelData.t
                }
            }
        }
        // Velo para que se lea la letra; respira con los graves
        Rectangle { anchors.fill: parent; color: Paleta.fondo; opacity: .5 - .12 * c.bajo }
    }

    Item {
        id: teclas
        anchors.fill: parent
        focus: true
        opacity: c.p
        Keys.onPressed: (e) => {
            const j = Letras.jugador;
            if (e.key === Qt.Key_Escape) Letras.cerrar();
            else if (e.key === Qt.Key_Space) { if (j?.canTogglePlaying) j.togglePlaying(); }
            else if (e.key === Qt.Key_Left) Letras.buscar(Letras.posicion - 5);
            else if (e.key === Qt.Key_Right) Letras.buscar(Letras.posicion + 5);
            else if (e.key === Qt.Key_Up) j?.previous();
            else if (e.key === Qt.Key_Down) j?.next();
            else return;
            e.accepted = true;
        }

        // Cerrar
        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 24; rightMargin: 40 }
            width: 36; height: 36; radius: height / 2
            color: cerrarRaton.containsMouse ? EstiloPanel.rellenoActivo : "transparent"
            Glifo { anchors.centerIn: parent; alto: 36; text: String.fromCodePoint(0xF0156); color: Paleta.texto; font { family: Paleta.mono; pixelSize: 20 } }
            MouseArea { id: cerrarRaton; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Letras.cerrar() }
        }

        // Nada suena
        Column {
            anchors.centerIn: parent
            visible: !Letras.jugador
            spacing: 12
            Glifo { anchors.horizontalCenter: parent.horizontalCenter; alto: 120; text: String.fromCodePoint(0xF075A); color: EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 104 } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No suena nada"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 36; bold: true } }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Pon música en Spotify, el navegador o cualquier reproductor"; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } }
        }

        // ── La canción ──
        Column {
            id: cancion
            visible: !!Letras.jugador
            anchors { left: parent.left; leftMargin: c.width * .07; verticalCenter: parent.verticalCenter }
            width: Math.min(360, c.width * .3)
            spacing: 12
            transform: Translate { y: (1 - c.p) * 40 }
            Item {
                width: parent.width; height: width
                MultiEffect {   // sombra
                    anchors.fill: disco
                    source: disco
                    shadowEnabled: true; shadowBlur: 1; shadowOpacity: .6; shadowVerticalOffset: 16
                    shadowColor: "black"
                    scale: disco.scale
                }
                ClippingRectangle {
                    id: disco
                    anchors.fill: parent
                    radius: 16
                    color: EstiloPanel.elevada
                    scale: 1 + .02 * c.bajo
                    Image {
                        anchors.fill: parent
                        source: Letras.caratula
                        fillMode: Image.PreserveAspectCrop
                        sourceSize { width: 720; height: 720 }
                        asynchronous: true
                    }
                    Glifo {
                        anchors.centerIn: parent; alto: parent.height
                        visible: !Letras.caratula
                        text: String.fromCodePoint(0xF075A); color: Paleta.acento
                        font { family: Paleta.mono; pixelSize: 104 }
                    }
                }
            }
            Item { width: 1; height: 12 }
            Text { width: parent.width; elide: Text.ElideRight; text: Letras.titulo || Letras.jugador?.identity || ""; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 26; bold: true } }
            Text { width: parent.width; elide: Text.ElideRight; text: Letras.artista; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 16 } }
            Item { width: 1; height: 4 }
            // Progreso (clic para ir)
            Rectangle {
                width: parent.width; height: 4; radius: height / 2
                color: Qt.alpha(Paleta.texto, .18)
                visible: Letras.duracion > 0
                Rectangle {
                    height: parent.height; radius: height / 2
                    width: parent.width * Math.min(1, Letras.posicion / Math.max(1, Letras.duracion))
                    color: Paleta.texto
                }
                MouseArea {
                    anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => Letras.buscar(m.x / width * Letras.duracion)
                }
            }
            Item {
                width: parent.width; height: 16
                visible: Letras.duracion > 0
                Text { text: c.mmss(Letras.posicion); color: EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 11 } }
                Text { anchors.right: parent.right; text: "-" + c.mmss(Letras.duracion - Letras.posicion); color: EstiloPanel.tenue; font { family: Paleta.mono; pixelSize: 11 } }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24
                Repeater {
                    model: [{ g: 0xF04AE, a: 0 }, { g: Letras.suena ? 0xF03E4 : 0xF040A, a: 1 }, { g: 0xF04AD, a: 2 }]
                    Rectangle {
                        required property var modelData
                        readonly property bool grande: modelData.a === 1
                        width: grande ? 56 : 44; height: width; radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: grande ? Paleta.texto : (boton.containsMouse ? EstiloPanel.rellenoActivo : "transparent")
                        scale: boton.pressed ? .92 : 1
                        Behavior on scale { NumberAnimation { duration: EstiloPanel.rapido } }
                        Glifo {
                            anchors.centerIn: parent; alto: parent.height
                            text: String.fromCodePoint(modelData.g)
                            color: grande ? Paleta.fondo : Paleta.texto
                            font { family: Paleta.mono; pixelSize: grande ? 26 : 20 }
                        }
                        MouseArea {
                            id: boton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const j = Letras.jugador;
                                if (modelData.a === 0) j?.previous(); else if (modelData.a === 2) j?.next(); else if (j?.canTogglePlaying) j.togglePlaying();
                            }
                        }
                    }
                }
            }
        }

        // ── La letra ──
        Item {
            id: zona
            visible: !!Letras.jugador
            anchors { left: cancion.right; leftMargin: c.width * .07; right: parent.right; rightMargin: c.width * .06; top: parent.top; bottom: parent.bottom }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Letras.estadoLetra !== "lista"
                width: parent.width
                wrapMode: Text.WordWrap
                text: Letras.estadoLetra === "buscando" ? "Buscando la letra…" : Letras.estadoLetra === "ninguna" ? "Esta canción no tiene letra en lrclib" : ""
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 26; bold: true }
            }

            // Arriba y abajo la letra se desvanece (máscara de degradado)
            Item {
                id: mascara
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .2; color: "black" }
                        GradientStop { position: .72; color: "black" }
                        GradientStop { position: .9; color: "transparent" }
                    }
                }
            }
            // Sincronizada: la línea actual a un tercio de la altura
            ListView {
                id: lista
                anchors.fill: parent
                visible: Letras.lineas.length > 0
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: mascara; maskThresholdMin: .5; maskSpreadAtMin: 1 }
                model: Letras.lineas
                interactive: false
                spacing: 24
                currentIndex: Math.max(0, Letras.actual)
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height * .36
                preferredHighlightEnd: height * .36 + 48
                highlightMoveDuration: Letras.largo
                highlightMoveVelocity: -1
                highlightFollowsCurrentItem: true
                // Al cambiar la letra el modelo se reinicia en la línea 0: recolocar en la que suena
                onCountChanged: Qt.callLater(() => { currentIndex = Qt.binding(() => Math.max(0, Letras.actual)); })
                header: Item { width: 1; height: lista.height * .36 }
                footer: Item { width: 1; height: lista.height * .6 }
                delegate: Item {
                    id: fila
                    required property var modelData
                    required property int index
                    readonly property int distancia: index - Letras.actual
                    readonly property bool ahora: distancia === 0
                    width: lista.width
                    height: modelData.txt === "" ? 48 : linea.implicitHeight
                    opacity: ahora ? 1 : distancia < 0 ? .24 : Math.max(.12, .4 - (distancia - 1) * .07)
                    Behavior on opacity { NumberAnimation { duration: Letras.medio } }

                    Text {
                        id: linea
                        visible: fila.modelData.txt !== ""
                        width: parent.width
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                        // La que suena se enciende letra a letra; las demás, enteras
                        text: {
                            const s = fila.modelData.txt;
                            if (!fila.ahora) return c.escapar(s);
                            const k = Math.round(s.length * Letras.avance);
                            return `<font color="${c.hex(Paleta.texto)}">${c.escapar(s.slice(0, k))}</font>` +
                                   `<font color="${c.hex(Qt.alpha(Paleta.texto, .42))}">${c.escapar(s.slice(k))}</font>`;
                        }
                        color: Paleta.texto
                        font { family: Paleta.fuente; pixelSize: 36; bold: true }
                        scale: fila.ahora ? 1 : .88
                        transformOrigin: Item.Left
                        Behavior on scale { NumberAnimation { duration: Letras.medio; easing.type: Easing.OutCubic } }
                    }
                    // Hueco instrumental: tres puntos que se llenan y respiran
                    Row {
                        visible: fila.modelData.txt === ""
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: 14; height: 14; radius: height / 2
                                color: Paleta.texto
                                opacity: fila.ahora ? .25 + .75 * Math.max(0, Math.min(1, Letras.avance * 3 - index)) : .3
                                scale: fila.ahora ? 1 + .25 * c.bajo : .8
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Letras.buscar(fila.modelData.t)
                    }
                }
            }

            // Sin tiempos: la letra entera avanza con la canción
            Flickable {
                id: llano
                anchors.fill: parent
                visible: Letras.lineas.length === 0 && Letras.texto.length > 0
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: mascara; maskThresholdMin: .5; maskSpreadAtMin: 1 }
                clip: true
                contentHeight: columnaLlana.height + height
                interactive: false
                contentY: Math.max(0, Math.min(contentHeight - height,
                    (Letras.posicion / Math.max(1, Letras.duracion)) * columnaLlana.height - height * .3))
                Behavior on contentY { NumberAnimation { duration: Letras.largo; easing.type: Easing.OutCubic } }
                Column {
                    id: columnaLlana
                    y: llano.height * .3
                    width: llano.width
                    spacing: 12
                    Repeater {
                        model: Letras.texto
                        Text {
                            required property string modelData
                            width: columnaLlana.width
                            wrapMode: Text.WordWrap
                            text: modelData || " "
                            color: Paleta.texto
                            opacity: .75
                            font { family: Paleta.fuente; pixelSize: 26; bold: true }
                        }
                    }
                }
            }
        }

        Text {
            anchors { bottom: parent.bottom; bottomMargin: 24; horizontalCenter: parent.horizontalCenter }
            text: "Espacio pausa · ← → 5 s · ↑ ↓ otra canción · clic en una línea para ir ahí · Esc salir"
            color: EstiloPanel.tenue
            font { family: Paleta.fuente; pixelSize: 12 }
        }
    }
}
