// Camara: ¿alguna app tiene la cámara abierta? (Teams, Meet, OBS…). Lee cuántas veces está abierto el
// driver de la webcam (/sys/module/uvcvideo/refcnt) cada 2 s: un archivo, sin lanzar procesos.
// Al encenderse y al apagarse lo dice la isla; mientras dura, BarraDerecha.qml enseña «Cámara» en verde
// junto al micrófono (como los puntos de privacidad del móvil).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: cam
    property bool enUso: false
    property bool listo: false            // la primera lectura no avisa (la cámara ya estaba así)

    FileView {
        id: contador
        path: "/sys/module/uvcvideo/refcnt"
        printErrors: false
        blockLoading: true
        onLoaded: {
            const ahora = (parseInt(text().trim()) || 0) > 0;
            if (ahora !== cam.enUso) {
                cam.enUso = ahora;
                if (cam.listo) Isla.mostrar(String.fromCodePoint(ahora ? 0xF05A0 : 0xF05A1), -1, ahora ? "Cámara encendida" : "Cámara apagada", ahora ? false : true, 2200);
            }
            cam.listo = true;
        }
        onLoadFailed: cam.listo = true      // sin webcam UVC: nunca hay nada que enseñar
    }
    Timer { interval: 2000; repeat: true; running: true; onTriggered: contador.reload() }
}
