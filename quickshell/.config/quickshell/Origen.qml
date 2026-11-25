// Origen: desde dónde se abrió un panel, para que nazca de ahí (y vuelva ahí al cerrarse).
//   Quien abre (la isla del reloj, la campana…):  Origen.marcar(item, pantalla)
//   El panel, al abrirse:                           const p = Origen.tomar(pantalla)   → el punto (x, y) o null
// La marca caduca enseguida: si el panel se abre con el teclado, no hay origen y entra como siempre.
//   qs ipc call origen marcar X Y   → desde un script: el próximo panel nace de ese punto de la pantalla
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: origen
    property var marca: null

    function marcar(item, pantalla) {
        if (!item) return;
        const p = item.mapToItem(null, item.width / 2, item.height / 2);   // ventana de la barra = pantalla
        marca = { x: p.x, y: p.y, pantalla: pantalla ?? "", t: Date.now() };
    }
    function marcarPunto(x, y, pantalla) {
        marca = { x: x, y: y, pantalla: pantalla ?? "", t: Date.now() };
    }
    function tomar(pantalla) {
        const m = marca;
        marca = null;
        if (!m || Date.now() - m.t > 800) return null;
        if (m.pantalla && pantalla && m.pantalla !== pantalla) return null;
        return { x: m.x, y: m.y };
    }
}
