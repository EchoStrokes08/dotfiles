// Lanzamiento: las apps se abren desde su icono (CapaLanzamiento.qml dibuja la animación).
//   Lanzador.qml, al abrir una app:  Lanzamiento.desde(baldosaDelIcono, rutaDelIcono, pantalla)
// Guarda de dónde sale (el rectángulo del icono en la pantalla) y qué icono es; la capa calcula
// a dónde va (donde aparecerá la ventana) y espera al «openwindow» de Hyprland para fundirse.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: l
    property var peticion: null      // x, y, ancho, alto (origen), icono, pantalla
    property int numero: 0           // sube con cada lanzamiento

    function desde(item, icono, pantalla) {
        if (!item || !EstiloPanel.movimiento) return;
        const p = item.mapToItem(null, 0, 0);   // la ventana del lanzador ocupa toda la pantalla
        peticion = { x: p.x, y: p.y, ancho: item.width, alto: item.height, icono: icono ?? "", pantalla: pantalla ?? "" };
        numero++;
    }
}
