.pragma library

// nombreDe(n): nombre legible cuando el aviso llega sin appName (p. ej. Zapzap solo manda desktopEntry)
function agrupar(lista, nombreDe) {
    const grupos = {}, orden = [];
    for (const n of lista.slice().reverse()) {
        const app = String(n.desktopEntry || n.appName || "aplicacion");
        const hints = n.hints || {};
        const conversacion = String(hints["x-kde-origin-name"] || hints["x-orion-conversation-id"] || "");
        const clave = app + "\u0000" + conversacion;
        if (!grupos[clave]) {
            grupos[clave] = {clave:clave,nombre:n.appName || (nombreDe && nombreDe(n)) || "Aplicación",conversacion:conversacion,items:[]};
            orden.push(clave);
        }
        grupos[clave].items.push(n);
    }
    return orden.map(k => grupos[k]);
}

function vencida(hasta, ahora) { return hasta > 0 && ahora >= hasta; }
