// ZoomVista: la vista general «tipo Mission Control». Va en la capa superior de Vista (Superpuesta.encima).
//   abrir(ruta, miniatura)   la captura de la pantalla (hecha justo antes de abrir) empieza ocupándolo todo
//                            y se encoge hasta el sitio de la miniatura del espacio activo, donde se funde
//                            con la miniatura en vivo.
//   cerrar(miniatura)        la miniatura elegida crece hasta llenar la pantalla mientras el panel se va.
// El destino se recalcula en cada fotograma: la tarjeta también se mueve mientras entra.
import QtQuick
import Quickshell.Widgets

Item {
    id: z
    anchors.fill: parent

    property Item destino: null
    property string modo: ""               // "abrir" · "cerrar" · "" (quieto: no se ve)
    property string captura: ""
    property int numero: 0
    property real p: 0                     // 0 = pantalla completa · 1 = en la miniatura
    property rect objetivo: Qt.rect(width / 2, height / 2, 0, 0)
    visible: modo !== "" && (modo === "cerrar" || imagen.status === Image.Ready)

    function medir() {
        if (!destino) return;
        const r = destino.mapToItem(z, 0, 0, destino.width, destino.height);
        objetivo = Qt.rect(r.x, r.y, r.width, r.height);
    }
    function abrir(ruta, miniatura) {
        cerrando.stop();
        destino = miniatura; captura = ruta; numero++;
        medir();
        modo = "abrir"; p = 0;
        abriendo.restart();
    }
    function cerrar(miniatura) {
        abriendo.stop();
        destino = miniatura;
        medir();
        modo = "cerrar"; p = 1;
        cerrando.restart();
    }
    function terminar() { modo = ""; captura = ""; }

    FrameAnimation { running: z.modo !== ""; onTriggered: z.medir() }

    // La hoja: interpolada entre la pantalla completa y la miniatura
    ClippingRectangle {
        id: hoja
        x: z.objetivo.x * z.p
        y: z.objetivo.y * z.p
        width: z.width + (z.objetivo.width - z.width) * z.p
        height: z.height + (z.objetivo.height - z.height) * z.p
        radius: EstiloPanel.rControl * z.p
        color: "transparent"
        // al abrir, en el último tramo se funde con la miniatura en vivo que hay debajo
        opacity: z.modo === "abrir" ? Math.min(1, (1 - z.p) / .25) : 1
        Image {
            id: imagen
            anchors.fill: parent
            visible: z.modo === "abrir"
            source: z.captura ? "file://" + z.captura + "?n=" + z.numero : ""
            cache: false
            asynchronous: false
        }
        ShaderEffectSource {
            anchors.fill: parent
            visible: z.modo === "cerrar"
            sourceItem: z.modo === "cerrar" ? z.destino : null
            live: true
            smooth: true
        }
    }

    NumberAnimation {
        id: abriendo
        target: z; property: "p"; from: 0; to: 1
        // curva pausada: con OutCubic casi todo el viaje pasaba en los primeros 150 ms y no se apreciaba
        duration: 560; easing.type: Easing.InOutCubic
        onFinished: z.terminar()
    }
    NumberAnimation {
        id: cerrando
        target: z; property: "p"; from: 1; to: 0
        duration: EstiloPanel.normal; easing.type: Easing.InOutCubic
        onFinished: z.terminar()
    }
}
