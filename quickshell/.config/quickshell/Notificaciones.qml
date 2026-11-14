// Notificaciones: Quickshell hace de SERVIDOR de notificaciones.
// Cualquier app que llame a notify-send / libnotify acaba aquí.
//   lista        → todas las guardadas (historial del centro de control)
//   emergentes   → las que se ven ahora mismo arriba a la derecha
//   noMolestar   → no se muestran emergentes (salvo las críticas); sobreviven a recargas
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "NotificacionesLogica.js" as Logica

Singleton {
    id: raiz

    readonly property var lista: servidor.trackedNotifications.values
    readonly property var grupos: Logica.agrupar(lista)
    property var expandidos: ({})
    function desplegar(clave) { const nuevos=Object.assign({},expandidos); nuevos[clave]=!nuevos[clave]; expandidos=nuevos; }
    property var emergentes: []
    property var horas: ({})                 // id → hora de llegada (para "hace 5 min")

    // PersistentProperties: estos valores sobreviven a una recarga de Quickshell
    PersistentProperties {
        id: persistente
        reloadableId: "notificaciones"
        property bool noMolestar: false
        property real hasta: 0
        property string actividad: ""
        property int retenidas: 0
        property string motivosJson: "{}"
    }
    property alias manual: persistente.noMolestar
    property bool automatico: false
    readonly property string explicacion: {
        pulso;
        const motivos=Object.keys(JSON.parse(persistente.motivosJson || "{}")).filter(k => JSON.parse(persistente.motivosJson || "{}")[k]);
        const manualTexto=!manual ? "" : persistente.actividad ? "hasta terminar " + persistente.actividad : persistente.hasta ? "hasta las " + Qt.formatTime(new Date(persistente.hasta),"HH:mm") : "manual";
        return [manualTexto,automatico ? "automático" : "",...motivos].filter(Boolean).join(" · ") || "Desactivado";
    }
    function pausar(modo) {
        persistente.hasta=0; persistente.actividad="";
        if (modo === "off") { manual=false; return; }
        if (modo === "concentracion" || modo === "reunion") {
            if (!(modo === "concentracion" ? Concentracion.activo : Reunion.activa)) return;
            persistente.actividad=modo;
        } else if (modo !== "siempre") persistente.hasta=Date.now()+Number(modo)*60000;
        manual=true;
    }
    function comprobarVencimiento(ahora) {
        if (manual && (Logica.vencida(persistente.hasta,ahora) || persistente.actividad === "concentracion" && !Concentracion.activo || persistente.actividad === "reunion" && !Reunion.activa)) {
            manual=false; persistente.hasta=0; persistente.actividad="";
        }
    }
    Timer { interval: 1000; repeat: true; running: raiz.manual; triggeredOnStart: true; onTriggered: raiz.comprobarVencimiento(Date.now()) }
    onNoMolestarChanged: {
        if (!noMolestar && persistente.retenidas > 0) {
            const total=persistente.retenidas; persistente.retenidas=0;
            Quickshell.execDetached(["notify-send","-a","ORION","Resumen de avisos",total+" avisos recibidos durante No molestar. Revísalos agrupados en el centro de control."]);
        }
    }
    // «Responder» en una tarjeta: el panel del móvil (Movil.qml) abre la respuesta con teclado
    signal responderPedido(var noti)
    function responder(n) { responderPedido(n); }
    readonly property bool porAutomatizacion: automatico || Object.values(JSON.parse(persistente.motivosJson || "{}")).some(x => x)
    readonly property bool noMolestar: manual || porAutomatizacion
    function motivo(nombre, activo) {
        const nuevos = JSON.parse(persistente.motivosJson || "{}");
        if (activo) nuevos[nombre] = true;
        else delete nuevos[nombre];
        persistente.motivosJson = JSON.stringify(nuevos);
    }
    Component.onCompleted: { motivo("captura",EstadoEscritorio.capturaPrivada === true); Qt.callLater(() => Quickshell.execDetached([
        "hyprctl", "dispatch", "escritorio.sincronizar() or hl.dsp.no_op()"])); }

    Connections {
        target: EstadoEscritorio
        ignoreUnknownSignals: true
        function onCapturaPrivadaChanged() { raiz.motivo("captura",EstadoEscritorio.capturaPrivada); }
    }

    NotificationServer {
        id: servidor
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true
        inlineReplySupported: true       // contestar desde el PC (WhatsApp/SMS del móvil vía KDE Connect)

        onNotification: (n) => {
            n.tracked = true;                // sin esto la notificación se descarta
            const h = Object.assign({}, raiz.horas);
            h[n.id] = Date.now();
            raiz.horas = h;
            if (n.lastGeneration) return;    // traída de antes de recargar: no volver a mostrarla
            if (raiz.noMolestar && n.urgency !== NotificationUrgency.Critical) persistente.retenidas++;
            if (!raiz.noMolestar || n.urgency === NotificationUrgency.Critical)
                raiz.emergentes = [n, ...raiz.emergentes].slice(0, 5);
            n.closed.connect(() => raiz.quitarEmergente(n));
        }
    }

    // Cuánto dura una emergente: lo que pida la app, o 3 s (baja) / 6 s (normal) / fija (crítica)
    function duracion(n) {
        if (n.expireTimeout > 0) return n.expireTimeout * 1000;
        if (n.urgency === NotificationUrgency.Critical) return 0;
        return n.urgency === NotificationUrgency.Low ? 3000 : 6000;
    }

    function quitarEmergente(n) {
        emergentes = emergentes.filter(x => x !== n);
        // las "transitorias" no se guardan en el historial
        if (n.transient && n.tracked) n.expire();
    }

    function borrarTodo() {
        for (const n of lista.slice()) n.dismiss();
        emergentes = [];
    }

    function alternarNoMolestar() { pausar(manual ? "off" : "siempre"); }

    function haceCuanto(n) {
        const t = horas[n.id];
        if (!t) return "";
        const s = Math.floor((Date.now() - t) / 1000);
        if (s < 60) return "ahora";
        if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
        if (s < 86400) return `hace ${Math.floor(s / 3600)} h`;
        return new Date(t).toLocaleDateString(Qt.locale("es_ES"), "d MMM");
    }

    // Icono de la app: puede llegar como nombre de tema, ruta o URL
    function icono(n) {
        const i = n.appIcon || "";
        if (i === "") {
            const e = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName);
            return e ? Quickshell.iconPath(e.icon, true) : "";
        }
        if (i.startsWith("/")) return "file://" + i;
        if (i.includes("://")) return i;
        return Quickshell.iconPath(i, true);
    }

    // Reloj para refrescar los "hace X min" cada 30 s
    property int pulso: 0
    Timer { interval: 30000; running: true; repeat: true; onTriggered: raiz.pulso++ }
}
