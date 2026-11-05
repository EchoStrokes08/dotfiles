// Quickshell — punto de entrada. Quickshell lee ~/.config/quickshell/shell.qml al lanzar `qs`.
//
// QML en 30 segundos:
//   Tipo { propiedad: valor }      crea un objeto (cada archivo Mayúscula.qml es un tipo nuevo)
//   propiedad: otra.cosa * 2       es un BINDING: se recalcula solo cuando "otra.cosa" cambia
//   onAlgoChanged: { ... }         código que corre cuando cambia "algo"
//   id: nombre                     para referirse al objeto desde otros sitios
//
// Abrir/cerrar desde fuera (lo usa SUPER+D):  qs ipc call dashboard toggle
// Ver errores y recargar: Quickshell recarga solo al guardar; el log sale en la terminal de `qs`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    Dashboard { id: dashboard }
    Lanzador { id: lanzador }
    OSD {}

    // Una barra por pantalla; si conectas un monitor, aparece otra sola
    Variants {
        id: barras
        model: Quickshell.screens
        Barra {
            required property var modelData
            screen: modelData
            onRelojPulsado: dashboard.abierto = !dashboard.abierto
        }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { dashboard.abierto = !dashboard.abierto; }
        function abrir(): void  { dashboard.abierto = true; }
        function cerrar(): void { dashboard.abierto = false; }
        // Ir a un workspace desde fuera (pruebas/scripts):  qs ipc call dashboard irA 3
        function irA(n: int): void { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`); }
    }

    // Lanzador de apps (SUPER+R):  qs ipc call lanzador toggle
    IpcHandler {
        target: "lanzador"
        function toggle(): void { dashboard.abierto = false; lanzador.abierto = !lanzador.abierto; }
        function buscar(texto: string): void { dashboard.abierto = false; lanzador.abrirCon(texto); }
        function lanzar(texto: string): void { lanzador.lanzarPrimero(texto); }
    }

    // Avisar a las barras de que algo cambió:  qs ipc call barra refrescar buds
    // (buds, modo-juego, red, brillo o todo). Lo usan modo_juego.lua, tema.sh y Buds Manager.
    IpcHandler {
        target: "barra"
        function refrescar(que: string): void {
            for (const b of barras.instances) b.refrescar(que);
        }
    }
}
