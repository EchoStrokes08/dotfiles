// Conexiones (SUPER+K o clic en la red de la barra): Wi-Fi y Bluetooth sin salir del escritorio.
//   Tab cambia de pestaña · ↑↓ elegir · Enter conectar/desconectar · Supr olvidar · Esc cerrar
//   Wi-Fi: las redes con candado y sin guardar piden la contraseña en la misma fila.
//   Bluetooth: clic en un dispositivo nuevo = emparejar + confiar + conectar.
//
// Usa los módulos nativos de Quickshell (hablan con NetworkManager y BlueZ por D-Bus):
//   Networking.devices → dispositivo Wi-Fi → .networks (cada red: name, signalStrength 0-1, security, known, connected)
//   Bluetooth.defaultAdapter → .devices (name, icon, paired, connected, battery…)
// Mientras el panel está abierto se escanea (Wi-Fi: scannerEnabled, Bluetooth: discovering);
// al cerrarlo se apaga para no gastar batería.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

Superpuesta {
    id: cx
    espacio: "conexiones"
    anchoTarjeta: 560

    property string pestana: "wifi"          // "wifi" | "bluetooth"
    property string pidiendoClave: ""         // nombre de la red cuya contraseña se está escribiendo
    property var errores: ({})                // { "nombre de red": "texto del error" }
    property int tic: 0                       // sube cada 2 s: reordena las listas (la señal cambia)

    function g(cp) { return String.fromCodePoint(cp); }
    function abrirEn(p) { pestana = p; abierto = true; }

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var adaptador: Bluetooth.defaultAdapter

    // Escanear solo con el panel abierto y en su pestaña
    Binding { target: cx.wifi; property: "scannerEnabled"; value: cx.abierto && cx.pestana === "wifi"; when: cx.wifi !== null }
    Binding { target: cx.adaptador; property: "discovering"
              value: cx.abierto && cx.pestana === "bluetooth" && (cx.adaptador?.enabled ?? false); when: cx.adaptador !== null }

    Timer { interval: 2000; repeat: true; running: cx.abierto && cx.pidiendoClave === ""; onTriggered: cx.tic++ }

    onAbriendose: { pidiendoClave = ""; errores = {}; lista.currentIndex = 0; lista.forceActiveFocus(); }
    onAbiertoChanged: if (!abierto) pidiendoClave = ""
    onPestanaChanged: { pidiendoClave = ""; lista.currentIndex = 0; }

    // ── Listas ordenadas ────────────────────────────────────────────────
    readonly property var redes: {
        tic;   // dependencia: recalcular en cada tic
        if (!wifi || !wifi.networks) return [];
        return wifi.networks.values
            .filter(n => n.name !== "")
            .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }
    readonly property var dispositivos: {
        tic;
        if (!adaptador) return [];
        return adaptador.devices.values
            .filter(d => d.paired || d.deviceName !== "")     // sin nombre = ruido de alrededor
            .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));
    }
    readonly property var elementos: pestana === "wifi" ? redes : dispositivos
    readonly property bool radioEncendida: pestana === "wifi" ? Networking.wifiEnabled : (adaptador?.enabled ?? false)

    function conmutarRadio() {
        if (pestana === "wifi") Networking.wifiEnabled = !Networking.wifiEnabled;
        else if (adaptador) adaptador.enabled = !adaptador.enabled;
    }

    // ── Acciones ────────────────────────────────────────────────────────
    function necesitaClave(n) {
        return !n.known && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
    }
    function activar(x) {
        if (!x) return;
        const e = Object.assign({}, errores); delete e[x.name]; errores = e;
        if (pestana === "wifi") {
            if (x.connected) x.disconnect();
            else if (necesitaClave(x)) pidiendoClave = x.name;
            else x.connect();
        } else {
            if (x.connected) x.disconnect();
            else if (x.paired) x.connect();
            else { x.trusted = true; x.pair(); }     // al terminar de emparejar se conecta (ver Connections abajo)
        }
    }
    function olvidar(x) {
        if (!x) return;
        if (pestana === "wifi" ? x.known : x.paired) x.forget();
    }
    function enviarClave(n, clave) {
        if (clave.length < 8) { ponerError(n.name, "La contraseña WPA tiene al menos 8 caracteres"); return; }
        pidiendoClave = "";
        n.connectWithPsk(clave);
        lista.forceActiveFocus();
    }
    function ponerError(nombre, texto) { const e = Object.assign({}, errores); e[nombre] = texto; errores = e; }
    function motivo(r) {
        switch (r) {
            case ConnectionFailReason.NoSecrets:
            case ConnectionFailReason.WifiClientFailed: return "Contraseña incorrecta";
            case ConnectionFailReason.WifiAuthTimeout:  return "El router no respondió a tiempo";
            case ConnectionFailReason.WifiNetworkLost:  return "La red ya no está al alcance";
            default:                                    return "No se pudo conectar";
        }
    }

    // Iconos
    function iconoRed(n) {
        const s = n.signalStrength, c = n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
        const i = s > 0.75 ? 3 : s > 0.5 ? 2 : s > 0.25 ? 1 : 0;
        return g((c ? [0xF0921, 0xF0924, 0xF0927, 0xF092A] : [0xF091F, 0xF0922, 0xF0925, 0xF0928])[i]);
    }
    function iconoBt(d) {
        const i = d.icon;
        return g(i.startsWith("audio-head") ? 0xF02CB : i === "audio-card" ? 0xF04C3 : i === "input-mouse" ? 0xF037D
               : i === "input-keyboard" ? 0xF030C : i === "input-gaming" ? 0xF0EB5 : i === "phone" ? 0xF011C
               : i === "computer" ? 0xF0322 : 0xF00AF);
    }
    function detalleRed(n) {
        if (cx.errores[n.name]) return cx.errores[n.name];
        if (n.stateChanging || n.state === ConnectionState.Connecting) return "Conectando…";
        if (n.state === ConnectionState.Disconnecting) return "Desconectando…";
        const seg = n.security === WifiSecurityType.Open ? "Abierta" : n.security === WifiSecurityType.Owe ? "Abierta (cifrada)"
                  : WifiSecurityType.toString(n.security).replace("Psk", "").replace("Sae", "WPA3");
        return (n.connected ? "Conectada" : n.known ? "Guardada" : seg) + " · " + Math.round(n.signalStrength * 100) + " %";
    }
    function detalleBt(d) {
        if (d.pairing) return "Emparejando… (acepta en el otro dispositivo si lo pide)";
        if (d.state === BluetoothDeviceState.Connecting) return "Conectando…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Desconectando…";
        const bat = d.batteryAvailable ? ` · ${g(0xF0079)} ${Math.round(d.battery * 100)} %` : "";
        return (d.connected ? "Conectado" : d.paired ? "Emparejado" : "Nuevo · clic para emparejar") + bat;
    }

    // ── Interfaz ────────────────────────────────────────────────────────
    ColumnLayout {
        width: parent.width
        spacing: 10

        // Pestañas + interruptor de la radio
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [ { id: "wifi", icono: 0xF0928, nombre: "Wi-Fi" }, { id: "bluetooth", icono: 0xF00AF, nombre: "Bluetooth" } ]
                Rectangle {
                    required property var modelData
                    readonly property bool activa: cx.pestana === modelData.id
                    implicitWidth: filaPest.implicitWidth + 24; implicitHeight: 34; radius: 10
                    color: activa ? Qt.alpha(Paleta.naranja, 0.20) : Qt.alpha(Paleta.texto, zonaPest.containsMouse ? 0.08 : 0.04)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Row {
                        id: filaPest
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: cx.g(modelData.icono); color: activa ? Paleta.naranja : Paleta.gris; font { family: Paleta.fuente; pixelSize: 15 } }
                        Text { text: modelData.nombre; color: activa ? Paleta.texto : Paleta.gris; font { family: Paleta.fuente; pixelSize: 12; bold: true } }
                    }
                    MouseArea { id: zonaPest; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { cx.pestana = modelData.id; lista.forceActiveFocus(); } }
                }
            }
            Item { Layout.fillWidth: true }
            Text {   // escaneando
                visible: cx.radioEncendida
                text: cx.g(0xF0450)
                color: Paleta.gris
                font { family: Paleta.fuente; pixelSize: 13 }
                RotationAnimation on rotation { from: 0; to: 360; duration: 1600; loops: Animation.Infinite; running: cx.abierto && cx.radioEncendida }
            }
            Rectangle {   // interruptor
                implicitWidth: 44; implicitHeight: 24; radius: 12
                color: cx.radioEncendida ? Paleta.naranja : Qt.alpha(Paleta.texto, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }
                Rectangle {
                    width: 18; height: 18; radius: 9; y: 3
                    x: cx.radioEncendida ? parent.width - width - 3 : 3
                    color: cx.radioEncendida ? Paleta.fondo : Paleta.texto
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cx.conmutarRadio() }
            }
        }

        ListView {
            id: lista
            Layout.fillWidth: true
            implicitHeight: Math.min(contentHeight, 420)
            visible: cx.radioEncendida && cx.elementos.length > 0
            clip: true
            spacing: 4
            model: cx.elementos
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            keyNavigationWraps: true
            focus: true
            highlight: Rectangle {
                radius: 9
                color: Qt.alpha(Paleta.naranja, 0.13)
                Rectangle { width: 3; height: parent.height - 14; radius: 2; color: Paleta.naranja
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter } }
            }
            Keys.onTabPressed: cx.pestana = cx.pestana === "wifi" ? "bluetooth" : "wifi"
            Keys.onReturnPressed: cx.activar(cx.elementos[currentIndex])
            Keys.onEnterPressed: cx.activar(cx.elementos[currentIndex])
            Keys.onDeletePressed: cx.olvidar(cx.elementos[currentIndex])
            Keys.onSpacePressed: cx.conmutarRadio()

            delegate: Item {
                id: fila
                required property var modelData
                required property int index
                readonly property bool esWifi: cx.pestana === "wifi"
                readonly property bool activo: modelData.connected
                readonly property bool guardado: esWifi ? modelData.known : modelData.paired
                readonly property bool pideClave: esWifi && cx.pidiendoClave === modelData.name
                readonly property bool conError: esWifi && !!cx.errores[modelData.name]
                width: lista.width
                height: pideClave ? 92 : 50

                // Avisos de la red/dispositivo de esta fila
                Connections {
                    target: fila.esWifi ? fila.modelData : null
                    ignoreUnknownSignals: true
                    function onConnectionFailed(r) { cx.ponerError(fila.modelData.name, cx.motivo(r)); }
                }
                Connections {
                    target: fila.esWifi ? null : fila.modelData
                    ignoreUnknownSignals: true
                    function onPairedChanged() { if (fila.modelData.paired) fila.modelData.connect(); }
                }

                MouseArea {
                    id: zonaFila
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: lista.currentIndex = fila.index
                    onClicked: (e) => { if (e.button === Qt.RightButton) cx.olvidar(fila.modelData); else if (!fila.pideClave) cx.activar(fila.modelData); }
                }

                ColumnLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 6; bottomMargin: 6 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.preferredWidth: 22
                            text: fila.esWifi ? cx.iconoRed(fila.modelData) : cx.iconoBt(fila.modelData)
                            color: fila.activo ? Paleta.naranja : fila.guardado ? Paleta.texto : Paleta.gris
                            font { family: Paleta.fuente; pixelSize: 18 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: fila.modelData.name
                                color: fila.activo ? Paleta.naranja : Paleta.texto
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 13; bold: fila.activo }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: fila.esWifi ? cx.detalleRed(fila.modelData) : cx.detalleBt(fila.modelData)
                                color: fila.conError ? Paleta.rojo : Paleta.gris
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 10 }
                            }
                        }
                        Text {   // olvidar (solo guardados, al pasar el ratón)
                            visible: fila.guardado && zonaFila.containsMouse && !fila.pideClave
                            text: cx.g(0xF0A7A)
                            color: zonaOlvidar.containsMouse ? Paleta.rojo : Paleta.gris
                            font { family: Paleta.fuente; pixelSize: 14 }
                            MouseArea { id: zonaOlvidar; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor; onClicked: cx.olvidar(fila.modelData) }
                        }
                        Text {
                            visible: fila.activo
                            text: cx.g(0xF012C)
                            color: Paleta.naranja
                            font { family: Paleta.fuente; pixelSize: 15 }
                        }
                    }

                    // Contraseña (solo en la fila que la pide)
                    Rectangle {
                        visible: fila.pideClave
                        Layout.fillWidth: true
                        Layout.leftMargin: 34
                        implicitHeight: 34; radius: 9
                        color: Qt.alpha(Paleta.texto, 0.06)
                        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.5) }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                            spacing: 8
                            Text { text: cx.g(0xF033E); color: Paleta.naranja; font { family: Paleta.fuente; pixelSize: 13 } }
                            TextInput {
                                id: clave
                                Layout.fillWidth: true
                                color: Paleta.texto
                                clip: true
                                echoMode: verClave.ver ? TextInput.Normal : TextInput.Password
                                font { family: Paleta.fuente; pixelSize: 13 }
                                onVisibleChanged: { text = ""; if (visible) forceActiveFocus(); }
                                Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: "Contraseña…"; color: Paleta.gris; font: parent.font }
                                Keys.onReturnPressed: cx.enviarClave(fila.modelData, text)
                                Keys.onEnterPressed: cx.enviarClave(fila.modelData, text)
                                Keys.onEscapePressed: { cx.pidiendoClave = ""; lista.forceActiveFocus(); }
                            }
                            Text {
                                id: verClave
                                property bool ver: false
                                text: cx.g(ver ? 0xF0209 : 0xF0208)
                                color: Paleta.gris
                                font { family: Paleta.fuente; pixelSize: 14 }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: verClave.ver = !verClave.ver }
                            }
                        }
                    }
                }
            }
        }

        // Estados vacíos
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16; Layout.bottomMargin: 16
            visible: !lista.visible
            text: !cx.radioEncendida ? (cx.pestana === "wifi" ? "Wi-Fi apagado" : "Bluetooth apagado") + " · espacio para encender"
                  : cx.pestana === "wifi" && !cx.wifi ? "No hay tarjeta Wi-Fi"
                  : cx.pestana === "bluetooth" && !cx.adaptador ? "No hay adaptador Bluetooth"
                  : "Buscando…"
            color: Paleta.gris
            font { family: Paleta.fuente; pixelSize: 12; italic: true }
        }
        PieAtajos {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            atajos: [["Tab", "pestaña"], ["↵", "conectar"], ["Supr", "olvidar"], ["␣", "on/off"]]
        }
    }
}
