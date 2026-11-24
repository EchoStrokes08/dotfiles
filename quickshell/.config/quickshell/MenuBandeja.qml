// MenuBandeja: el menú del clic derecho de las apps de la bandeja, dibujado con el estilo del sistema
// (antes era el menú nativo de Qt). Los submenús se abren dentro del mismo menú, con «‹» para volver.
//   menuBandeja.abrir(item, origen, ventana)   // item: SystemTrayItem; origen: el Item pulsado
// Se cierra con Esc, al elegir o al hacer clic fuera (HyprlandFocusGrab).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

PopupWindow {
    id: m
    property var ventana: null          // la ventana a la que se ancla (barra o desplegable)
    property var item: null             // SystemTrayItem
    property var pila: []               // menús abiertos: [raíz, submenú, …] (hasta 3 niveles)
    property var titulos: []            // el nombre de cada submenú, guardado al entrar
    property real ax: 0
    property real ay: 0
    // Un abridor por nivel: si se reusara uno solo, al pasar al submenú se cerraría el menú de
    // arriba y con él se destruiría la propia entrada del submenú (quedaba vacío).
    readonly property var abridor: [abridor0, abridor1, abridor2][Math.max(0, pila.length - 1)]
    readonly property var entradas: abridor.children.values   // las del nivel abierto

    function abrir(it, origen, win) {
        if (!it?.menu) return false;
        item = it; ventana = win; pila = [it.menu]; titulos = [];
        const p = origen.mapToItem(null, origen.width / 2, origen.height);
        ax = p.x; ay = p.y + EstiloPanel.e2;
        lista.currentIndex = -1;
        visible = true;
        return true;
    }
    function cerrar() { visible = false; pila = []; titulos = []; }
    function entrar(entrada) {
        if (pila.length >= 3) return;
        titulos = titulos.concat([limpio(entrada.text)]);
        pila = pila.concat([entrada]);
        lista.currentIndex = -1;
    }
    function volver() { if (pila.length > 1) { pila = pila.slice(0, -1); titulos = titulos.slice(0, -1); lista.currentIndex = -1; } }
    function elegir(entrada) {
        if (!entrada || entrada.isSeparator || !entrada.enabled) return;
        if (entrada.hasChildren) { entrar(entrada); return; }
        entrada.triggered();
        cerrar();
    }
    // los menús de GTK/Qt marcan el atajo con «_» o «&»: se quita (y «__» o «&&» quedan como uno)
    function limpio(t) { return (t || "").replace(/__/g, "\u0001").replace(/&&/g, "\u0002").replace(/[_&]/g, "").replace(/\u0001/g, "_").replace(/\u0002/g, "&"); }

    anchor.window: ventana
    anchor.rect.x: Math.max(4, Math.min(ax - implicitWidth / 2, (ventana?.width ?? 1280) - implicitWidth - 4))
    anchor.rect.y: ay
    implicitWidth: 280
    implicitHeight: Math.min(columna.implicitHeight + 2 * EstiloPanel.e2, 560)
    color: "transparent"
    visible: false

    QsMenuOpener { id: abridor0; menu: m.pila[0] ?? null }
    QsMenuOpener { id: abridor1; menu: m.pila[1] ?? null }
    QsMenuOpener { id: abridor2; menu: m.pila[2] ?? null }

    HyprlandFocusGrab {
        active: m.visible
        windows: [m]
        onCleared: m.cerrar()
    }

    Item {
        id: cuerpo
        anchors.fill: parent
        transformOrigin: Item.Top
        opacity: 0; scale: .94
        states: State { when: m.visible; PropertyChanges { cuerpo.opacity: 1; cuerpo.scale: 1 } }
        transitions: Transition {
            to: "*"
            NumberAnimation { property: "opacity"; duration: EstiloPanel.normal }
            NumberAnimation { property: "scale"; duration: EstiloPanel.lento; easing.type: Easing.OutBack }
        }
        FondoPanel { anchors.fill: parent; opacidad: 1; radio: EstiloPanel.rTarjeta }

        FocusScope {
            anchors { fill: parent; margins: EstiloPanel.e2 }
            focus: true
            Keys.onEscapePressed: m.pila.length > 1 ? m.volver() : m.cerrar()
            Keys.onLeftPressed: m.volver()
            Keys.onRightPressed: { const e = lista.currentItem?.entrada; if (e?.hasChildren) m.entrar(e); }
            Keys.onReturnPressed: m.elegir(lista.currentItem?.entrada)
            Keys.onEnterPressed: m.elegir(lista.currentItem?.entrada)
            Keys.onDownPressed: mover(1)
            Keys.onUpPressed: mover(-1)
            function mover(d) {
                const n = lista.count;
                for (let i = 1; i <= n; i++) {
                    const j = ((lista.currentIndex < 0 && d < 0 ? n : lista.currentIndex) + d * i + n) % n;
                    const e = m.entradas[j];
                    if (e && !e.isSeparator && e.enabled) { lista.currentIndex = j; return; }
                }
            }

            ColumnLayout {
                id: columna
                width: parent.width
                spacing: EstiloPanel.e1

                // Cabecera: la app (en la raíz) o el submenú abierto, con «‹» para volver
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: EstiloPanel.e2
                    Layout.bottomMargin: 0
                    spacing: EstiloPanel.e2
                    Rectangle {
                        visible: m.pila.length > 1
                        implicitWidth: 24; implicitHeight: 24; radius: EstiloPanel.rChip
                        color: zonaAtras.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                        border { width: 1; color: EstiloPanel.borde }
                        Text { anchors.centerIn: parent; text: "‹"; color: Paleta.texto; font { family: Paleta.fuente; pixelSize: 16; bold: true } }
                        MouseArea { id: zonaAtras; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: m.volver() }
                        Accessible.role: Accessible.Button
                        Accessible.name: "Volver"
                    }
                    IconImage {
                        visible: m.pila.length === 1 && !!m.item?.icon
                        implicitSize: 16
                        source: m.item?.icon ?? ""
                    }
                    Etiqueta {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: (m.pila.length > 1 ? m.titulos[m.titulos.length - 1] : (m.item?.tooltipTitle || m.item?.title || m.item?.id || "")).toUpperCase()
                    }
                }

                ListView {
                    id: lista
                    Layout.fillWidth: true
                    implicitHeight: contentHeight
                    Layout.maximumHeight: 480
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    model: m.abridor.children
                    currentIndex: -1
                    // al llegar las entradas, ListView marcaría la primera: nada marcado hasta que pase el ratón o se use el teclado
                    onCountChanged: currentIndex = -1
                    highlightMoveDuration: EstiloPanel.rapido
                    highlight: FondoSeleccion { radius: EstiloPanel.rControl; marca: true }
                    delegate: Item {
                        id: fila
                        required property var modelData
                        required property int index
                        readonly property var entrada: modelData
                        readonly property bool actual: lista.currentIndex === index
                        width: lista.width
                        height: modelData.isSeparator ? 9 : 34
                        opacity: modelData.enabled || modelData.isSeparator ? 1 : .45

                        Rectangle {   // separador
                            visible: fila.modelData.isSeparator
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: EstiloPanel.e3; rightMargin: EstiloPanel.e3 }
                            height: 1
                            color: EstiloPanel.borde
                        }
                        MouseArea {
                            anchors.fill: parent
                            visible: !fila.modelData.isSeparator
                            enabled: fila.modelData.enabled
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: lista.currentIndex = fila.index
                            onClicked: m.elegir(fila.modelData)
                        }
                        RowLayout {
                            visible: !fila.modelData.isSeparator
                            anchors { fill: parent; leftMargin: EstiloPanel.e4; rightMargin: EstiloPanel.e3 }
                            spacing: EstiloPanel.e3
                            // casilla (✓) u opción de radio (punto), en el acento cuando está marcada
                            Rectangle {
                                readonly property bool marcada: fila.modelData.checkState === Qt.Checked
                                visible: fila.modelData.buttonType !== QsMenuButtonType.None
                                implicitWidth: 16; implicitHeight: 16
                                radius: fila.modelData.buttonType === QsMenuButtonType.RadioButton ? height / 2 : EstiloPanel.rPunto
                                color: marcada ? Paleta.acento : "transparent"
                                border { width: 1; color: marcada ? Paleta.acento : EstiloPanel.bordeFuerte }
                                Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                                RectangularShadow {
                                    anchors.fill: parent; z: -1
                                    visible: EstiloPanel.profundidad && parent.marcada
                                    radius: parent.radius; blur: 8
                                    color: Qt.alpha(Paleta.acento, .5)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.marcada && fila.modelData.buttonType === QsMenuButtonType.CheckBox
                                    text: "✓"; color: Paleta.sobreAcento
                                    font { family: Paleta.fuente; pixelSize: 11; bold: true }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: parent.marcada && fila.modelData.buttonType === QsMenuButtonType.RadioButton
                                    width: 6; height: 6; radius: height / 2
                                    color: Paleta.sobreAcento
                                }
                            }
                            Item {   // hueco del icono: siempre reservado, así los textos quedan alineados
                                visible: fila.modelData.buttonType === QsMenuButtonType.None
                                implicitWidth: 16; implicitHeight: 16
                                IconImage { anchors.fill: parent; visible: fila.modelData.icon !== ""; source: fila.modelData.icon }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: m.limpio(fila.modelData.text)
                                elide: Text.ElideRight
                                color: fila.actual ? Paleta.texto : EstiloPanel.secundario
                                font { family: Paleta.fuente; pixelSize: 13; bold: fila.actual }
                            }
                            Text {
                                visible: fila.modelData.hasChildren && m.pila.length < 3
                                text: "›"
                                color: fila.actual ? Paleta.acento : Paleta.gris
                                font { family: Paleta.fuente; pixelSize: 16; bold: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
