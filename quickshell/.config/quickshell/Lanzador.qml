// Lanzador de apps (SUPER+R): sustituye a fuzzel.
//   Escribe para buscar · ↑↓ / Tab para moverte · Enter abre · Esc o clic fuera cierra
// Aprende: las apps que más abres suben (contador en ~/.local/state/quickshell/lanzador.json).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: ventana

    property bool abierto: false
    property bool mostrar: false
    property var usos: ({})              // { "firefox.desktop": 12, … }

    onAbiertoChanged: {
        if (abierto) {
            cierre.stop(); mostrar = true;
            buscador.text = "";
            lista.currentIndex = 0;
            buscador.forceActiveFocus();
        } else cierre.restart();
    }
    Timer { id: cierre; interval: 220; onTriggered: ventana.mostrar = false }

    // Abrir con un texto ya escrito (qs ipc call lanzador buscar fire)
    function abrirCon(t) {
        abierto = true;
        buscador.text = t;
    }
    // Abrir el primer resultado de una búsqueda sin enseñar nada (para scripts y pruebas)
    function lanzarPrimero(t) {
        buscador.text = t;
        lanzar(resultados[0]);
    }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-lanzador"
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Contador de usos (persistente) ──────────────────────────────────
    readonly property string rutaUsos: Quickshell.env("HOME") + "/.local/state/quickshell/lanzador.json"
    FileView {
        id: archivoUsos
        path: ventana.rutaUsos
        onLoaded: { try { ventana.usos = JSON.parse(text()); } catch (e) { ventana.usos = {}; } }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"])

    // ── Búsqueda ────────────────────────────────────────────────────────
    function normalizar(s) {
        // minúsculas y sin tildes: "Configuración" → "configuracion"
        return (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }
    // ¿Están las letras de q en orden dentro de t? (devuelve un puntaje, 0 = no)
    function salteado(q, t) {
        let i = 0, huecos = 0, ultimo = -1;
        for (let j = 0; j < t.length && i < q.length; j++) {
            if (t[j] === q[i]) { if (ultimo >= 0) huecos += j - ultimo - 1; ultimo = j; i++; }
        }
        return i === q.length ? Math.max(1, 25 - huecos) : 0;
    }
    function puntaje(app, q) {
        const nombre = normalizar(app.name);
        if (q === "") return 1;
        let p = 0;
        if (nombre.startsWith(q)) p = 100;
        else if (nombre.split(/[\s\-_.]+/).some(w => w.startsWith(q))) p = 80;
        else if (nombre.includes(q)) p = 60;
        else {
            const otros = [app.genericName, ...(app.keywords ?? []), app.id].map(normalizar);
            if (otros.some(t => t.startsWith(q))) p = 45;
            else if (otros.some(t => t.includes(q))) p = 35;
            else if (normalizar(app.comment).includes(q)) p = 15;
            else p = salteado(q, nombre);
        }
        return p;
    }

    readonly property var resultados: {
        const q = normalizar(buscador.text.trim());
        return DesktopEntries.applications.values
            .map(app => ({ app: app, p: puntaje(app, q) }))
            .filter(r => r.p > 0)
            .map(r => ({ app: r.app, p: r.p + Math.min(30, (usos[r.app.id] ?? 0) * 3) }))   // las que más usas suben
            .sort((a, b) => b.p - a.p || a.app.name.localeCompare(b.app.name))
            .slice(0, 40)
            .map(r => r.app);
    }

    function lanzar(app) {
        if (!app) return;
        if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e", ...app.command]);
        else app.execute();
        const u = Object.assign({}, usos);
        u[app.id] = (u[app.id] ?? 0) + 1;
        usos = u;
        archivoUsos.setText(JSON.stringify(u, null, 1));
        abierto = false;
    }

    // ── Velo + clic fuera ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: ventana.abierto ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: ventana.abierto = false }
    }

    // ── La tarjeta ──────────────────────────────────────────────────────
    Rectangle {
        id: tarjeta
        width: 560
        height: columna.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 + (ventana.abierto ? 0 : -12)
        opacity: ventana.abierto ? 1 : 0
        scale: ventana.abierto ? 1 : 0.98
        Behavior on y       { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        radius: 16
        color: Qt.alpha(Paleta.fondo, 0.90)
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: columna
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // Campo de búsqueda
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 11
                color: Qt.alpha(Paleta.texto, 0.06)
                border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.naranja, 0.5) : "transparent" }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text {
                        text: ""
                        color: Paleta.naranja
                        font { family: Paleta.fuente; pixelSize: 15 }
                    }
                    TextInput {
                        id: buscador
                        Layout.fillWidth: true
                        color: Paleta.texto
                        selectionColor: Qt.alpha(Paleta.naranja, 0.4)
                        font { family: Paleta.fuente; pixelSize: 16 }
                        clip: true
                        onTextChanged: lista.currentIndex = 0

                        Text {   // texto de ejemplo cuando está vacío
                            anchors.verticalCenter: parent.verticalCenter
                            visible: buscador.text === ""
                            text: "Buscar apps…"
                            color: Paleta.gris
                            font: buscador.font
                        }

                        Keys.onEscapePressed: ventana.abierto = false
                        Keys.onReturnPressed: ventana.lanzar(ventana.resultados[lista.currentIndex])
                        Keys.onEnterPressed: ventana.lanzar(ventana.resultados[lista.currentIndex])
                        Keys.onDownPressed: lista.incrementCurrentIndex()
                        Keys.onUpPressed: lista.decrementCurrentIndex()
                        Keys.onTabPressed: lista.incrementCurrentIndex()
                        Keys.onBacktabPressed: lista.decrementCurrentIndex()
                    }
                    Text {
                        text: ventana.resultados.length
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
            }

            // Resultados
            ListView {
                id: lista
                Layout.fillWidth: true
                implicitHeight: Math.min(count, 7) * 52
                clip: true
                model: ventana.resultados
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 140
                keyNavigationWraps: true

                highlight: Rectangle {
                    radius: 10
                    color: Qt.alpha(Paleta.naranja, 0.13)
                    Rectangle {   // rayita naranja a la izquierda, como en Firefox y waybar
                        width: 3; height: parent.height - 18
                        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                        radius: 2
                        color: Paleta.naranja
                    }
                }

                delegate: Item {
                    id: fila
                    required property var modelData
                    required property int index
                    width: lista.width
                    height: 52

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                        spacing: 12
                        IconImage {
                            implicitSize: 30
                            source: Quickshell.iconPath(fila.modelData.icon, "application-x-executable")
                            asynchronous: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: fila.modelData.name
                                color: lista.currentIndex === fila.index ? Paleta.naranja : Paleta.texto
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 14; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: fila.modelData.genericName || fila.modelData.comment || ""
                                color: Paleta.gris
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 11 }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: lista.currentIndex = fila.index
                        onClicked: ventana.lanzar(fila.modelData)
                    }
                }
            }

            // Sin resultados
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6; Layout.bottomMargin: 6
                visible: ventana.resultados.length === 0
                text: "Nada coincide con «" + buscador.text + "»"
                color: Paleta.gris
                font { family: Paleta.fuente; pixelSize: 12; italic: true }
            }

            // Pie con ayuda de teclas
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "↵ abrir   ·   ↑↓ moverse   ·   esc cerrar"
                color: Qt.alpha(Paleta.gris, 0.8)
                font { family: Paleta.fuente; pixelSize: 10 }
            }
        }
    }
}
