"""Pruebas de interacción con componentes reales de Quickshell, sin la sesión del usuario.

Se omiten si no está instalado qs. HOME, runtime, servicios y datos son temporales.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

RAIZ = Path(__file__).resolve().parents[1]
QML = RAIZ / "quickshell/.config/quickshell"
ARCHIVOS = ("Paleta", "EstiloPanel", "FondoBoton", "FondoPanel", "BotonCompacto", "ControlRapido",
            "ModoTeclado", "IndicadorTeclado", "Eventos", "EstadoAgenda", "AvisoRecarga", "EstadoRecarga", "TarjetaRecarga", "AccionesResultado", "SelectorPanel")


@unittest.skipUnless(shutil.which("qs"), "Requiere Quickshell instalado")
class InteraccionQml(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="orion-qml-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.config = self.base / "config"
        self.config.mkdir()
        self.scripts = self.base / ".config/hypr/scripts"
        self.scripts.mkdir(parents=True)
        self.runtime = self.base / "runtime"
        self.runtime.mkdir(mode=0o700)
        for nombre in ARCHIVOS:
            shutil.copy(QML / f"{nombre}.qml", self.config)
        (self.config / "EstadoEscritorio.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property string perfil: "minimo"; property var datos: ({}); property bool privacidad: false; property bool capturaPrivada: false }
''')
        (self.scripts / "gcal.py").write_text('print(\'{"cliente":false,"conectado":false}\')')

    def entorno(self):
        return {**os.environ, "HOME": str(self.base), "XDG_RUNTIME_DIR": str(self.runtime),
               "XDG_CONFIG_HOME": str(self.base / ".config"), "XDG_CACHE_HOME": str(self.base / "cache"),
               "XDG_STATE_HOME": str(self.base / "state"), "QT_QPA_PLATFORM": "offscreen",
               "QT_QPA_PLATFORMTHEME": "", "QT_QUICK_CONTROLS_STYLE": "Basic", "QT_QUICK_BACKEND": "software",
               "PATH": str(self.base / "bin") + os.pathsep + os.environ.get("PATH", os.defpath),
               "HYPRLAND_INSTANCE_SIGNATURE": "", "WAYLAND_DISPLAY": "", "DBUS_SESSION_BUS_ADDRESS":"unix:path="+str(self.base/"sin-bus") }

    def ejecutar(self, cuerpo):
        (self.config / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
    function comprobar(condicion, mensaje) {
        if (!condicion) { console.error("ORION_FALLO: " + mensaje); Qt.quit(); }
    }
''' + cuerpo + "\n}")
        r = subprocess.run(["qs", "-p", str(self.config), "--no-color"], env=self.entorno(),
                           capture_output=True, text=True, timeout=8)
        salida = r.stdout + r.stderr
        self.assertEqual(r.returncode, 0, salida)
        self.assertNotIn("ORION_FALLO", salida)
        self.assertNotIn("Failed to load configuration", salida)
        self.assertIn("ORION_OK", salida)
        return salida

    def test_mensaje_renderiza_formula_y_descarta_respuesta_anterior(self):
        for nombre in ("MensajeAgente",):
            shutil.copy(QML / (nombre+".qml"),self.config)
        origen=RAIZ/"hypr/.config/hypr/scripts"
        shutil.copy(origen/"agente_render.py",self.scripts)
        shutil.copytree(origen/"vendor",self.scripts/"vendor")
        self.ejecutar(r'''
    MensajeAgente { id: mensaje; width: 700; texto: "Primero $x_1$" }
    Timer { interval: 200; running:true; onTriggered: mensaje.texto="Resultado final $x_2$" }
    Timer { interval: 2300; running:true; onTriggered: {
        comprobar(mensaje.html.indexOf("Resultado final")>=0,"debe mostrar la última consulta");
        comprobar(mensaje.html.indexOf("<img")>=0,"debe componer la fórmula");
        comprobar(mensaje.aviso==="","no debe degradar el renderizado");
        comprobar(mensaje.implicitHeight>30,"debe reservar espacio para texto y controles");
        console.log("ORION_OK");Qt.quit();
    }}
''')

    def test_inspector_edita_recupera_y_oculta_detalles_en_privacidad(self):
        (self.scripts/"acciones.py").write_text('''import sys,json
from pathlib import Path
p=Path(__file__).with_suffix('.valor')
op=sys.argv[1];d=json.loads(sys.argv[2])
if op=='opciones':
 print(json.dumps({'ok':True,'vista':p.read_text() if p.exists() else 'Original','revision':'r1','acciones':[{'codigo':'guardar','titulo':'Editar','campos':[{'nombre':'texto','etiqueta':'Texto','valor':'Original','tipo':'multilinea','opciones':[]}]}]}))
elif op=='ejecutar':
 p.write_text(d['valores']['texto']);print(json.dumps({'ok':True,'mensaje':'Guardado','deshacer':'token'}))
else:
 p.write_text('Original');print(json.dumps({'ok':True,'mensaje':'Recuperado'}))
''')
        self.ejecutar('''
    id: prueba
    property int paso:0
    AccionesResultado { id: inspector; width:600 }
    Timer { interval:80; repeat:true; running:true; onTriggered:{
        if(inspector.ocupado)return;
        if(prueba.paso===0){inspector.abrir({tipo:"plantilla",id:"demo"});prueba.paso=1;}
        else if(prueba.paso===1 && inspector.opciones.length){
            inspector.elegir(inspector.opciones[0]);
            prueba.comprobar(inspector.valores.texto==="Original","formulario prellenado");
            inspector.valor("texto","Nuevo");inspector.ejecutar();prueba.paso=2;
        }else if(prueba.paso===2 && inspector.vista==="Nuevo"){
            prueba.comprobar(inspector.tokenDeshacer==="token","recuperación disponible");
            inspector.lanzar("deshacer",{token:inspector.tokenDeshacer});prueba.paso=3;
        }else if(prueba.paso===3 && inspector.vista==="Original"){
            EstadoEscritorio.privacidad=true;
            prueba.comprobar(inspector.vista==="" && inspector.opciones.length===0,"privacidad borra detalles");
            console.log("ORION_OK");Qt.quit();
        }
    }}
''')

    def test_recarga_invalida_conserva_interfaz_y_la_siguiente_se_recupera(self):
        fichero = self.config / "shell.qml"
        fichero.write_text('''import QtQuick
import Quickshell
ShellRoot {
    readonly property string errorRecarga: EstadoRecarga.error
    Component.onCompleted: console.log("ORION_LISTO")
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) {
            Qt.callLater(() => {
                if (!errorRecarga) console.error("ORION_FALLO: falta aviso persistente");
                else console.log("ORION_RECARGA_FALLIDA_OK");
            });
        }
    }
}
''')
        registro = self.base / "recarga.log"
        with registro.open("w") as salida:
            proceso = subprocess.Popen(["qs", "-p", str(self.config), "--no-color"], env=self.entorno(), stdout=salida, stderr=salida)
            try:
                def esperar(marca):
                    limite = time.monotonic() + 5
                    while time.monotonic() < limite:
                        texto = registro.read_text()
                        if marca in texto:
                            return
                        if proceso.poll() is not None:
                            break
                        time.sleep(0.05)
                    self.fail(registro.read_text())
                esperar("ORION_LISTO")
                fichero.write_text("Esta configuración es inválida {")
                esperar("ORION_RECARGA_FALLIDA_OK")
                self.assertIsNone(proceso.poll(), registro.read_text())
                fichero.write_text('''import QtQuick
import Quickshell
ShellRoot {
    readonly property string errorRecarga: EstadoRecarga.error
    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Qt.callLater(() => {
                if (errorRecarga) console.error("ORION_FALLO: error no resuelto");
                console.log("ORION_OK"); Qt.quit();
            });
        }
    }
}
''')
                esperar("ORION_OK")
                proceso.wait(timeout=3)
                self.assertNotIn("ORION_FALLO", registro.read_text())
            finally:
                if proceso.poll() is None:
                    proceso.terminate()
                    proceso.wait(timeout=3)

    def test_control_no_anuncia_exito_hasta_confirmar_y_permite_reintentar(self):
        respuesta = {"ok": False, "estado": {"disponible": True, "activo": False}, "error": "Sin permiso"}
        script = self.scripts / "conmutadores.sh"
        script.write_text("#!/bin/sh\nsleep 0.15\nprintf '%s\\n' '" + json.dumps(respuesta) + "'\nexit 1\n")
        script.chmod(0o755)
        self.ejecutar('''
    id: prueba
    property bool fallo: false
    ControlRapido {
        id: c; cosa: "wifi"; nombre: "Wi-Fi"
        dato: ({disponible:true, activo:false})
        onConfirmado: (d) => dato = d
        onFallo: (m) => { prueba.fallo = true; prueba.comprobar(m === "Sin permiso", "motivo del fallo"); }
    }
    Timer { interval: 50; running: true; onTriggered: {
        c.clicked(); prueba.comprobar(c.ocupado && !c.activo, "no activar optimistamente");
    } }
    Timer { interval: 40; repeat: true; running: true; onTriggered: {
        if (!prueba.fallo || c.ocupado) return;
        prueba.comprobar(!c.activo && c.enabled && c.error === "Sin permiso", "estado recuperable tras fallo");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def test_modo_reconstruye_estado_actual_con_api_lua(self):
        programas = self.base / "bin"
        programas.mkdir()
        hyprctl = programas / "hyprctl"
        hyprctl.write_text('''#!/bin/sh
[ "$1" = repl ] && [ "$2" = 'hl.get_current_submap()' ] || exit 3
printf '%s\n' lanzar
''')

        hyprctl.chmod(0o755)
        self.ejecutar('''
    id: prueba
    property bool consultado: false
    Timer { interval: 50; running: true; onTriggered: { ModoTeclado.sincronizar(); prueba.consultado = true; } }
    Timer { interval: 50; running: true; repeat: true; onTriggered: {
        if (!prueba.consultado || ModoTeclado.actual !== "lanzar") return;
        prueba.comprobar(ModoTeclado.activo && ModoTeclado.ayuda.includes("Esc"), "reconstrucción con salida");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def test_movimiento_es_preferencia_independiente_de_la_bateria(self):
        self.ejecutar('''
    id: prueba
    Timer { interval: 50; running: true; onTriggered: {
        EstadoEscritorio.perfil = "cristal";
        EstadoEscritorio.datos = {bateria:"true"};
        Paleta.reducirMovimiento = false;
        prueba.comprobar(EstiloPanel.movimiento && !EstiloPanel.efectos, "batería reduce efectos sin imponer movimiento reducido");
        Paleta.reducirMovimiento = true;
        prueba.comprobar(!EstiloPanel.movimiento && !Paleta.animarColor, "preferencia reduce animaciones y fundido");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def test_control_confirmado_cambia_estado_y_modo_se_puede_reconstruir(self):
        script = self.scripts / "conmutadores.sh"
        script.write_text('''#!/bin/sh
printf '%s\n' '{"ok":true,"estado":{"disponible":true,"activo":true},"error":""}'
''')
        script.chmod(0o755)
        self.ejecutar('''
    id: prueba
    property bool confirmado: false
    ControlRapido {
        id: c; cosa: "wifi"; nombre: "Wi-Fi"; dato: ({disponible:true, activo:false})
        onConfirmado: (d) => { dato = d; prueba.confirmado = true; }
    }
    Timer { interval: 50; running: true; onTriggered: c.clicked() }
    Timer { interval: 40; repeat: true; running: true; onTriggered: {
        if (!prueba.confirmado || c.ocupado) return;
        prueba.comprobar(c.activo && !c.error, "confirmación real");
        ModoTeclado.recibir("redimensionar");
        prueba.comprobar(ModoTeclado.activo && ModoTeclado.ayuda.includes("Esc"), "modo y salida");
        ModoTeclado.recibir("reset");
        prueba.comprobar(!ModoTeclado.activo, "salida del modo");
        ModoTeclado.recibir("lanzar");
        prueba.comprobar(ModoTeclado.ayuda.includes("F navegador"), "ayuda de lanzar");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def preparar_hoy(self):
        for nombre in ("HoyPaneles","SaludPanel","Almacenamiento","Calendario","FlechaMes","NuevoEvento","CampoPanel","TarjetaPanel","Etiqueta","Tiempo","Interruptor"):
            shutil.copy(QML / f"{nombre}.qml",self.config)
        (self.config / "Clima.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property bool listo: true; property int codigo: 0; property bool deDia: true; property real temp: 18; property int lluviaHoy: 20; property string lugar: "Bogotá"; function icono(c,d) { return "☀"; } function texto(c) { return "Despejado"; } }
''')
        (self.config / "Recordatorios.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property var lista: []; function hora(ms) { return "12:00"; } }
''')
        (self.config / "Continuidad.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property var ultimo: null }
''')
        (self.config / "Sistema.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property real cpu: .2; property real ram: .5; property real temp: 45 }
''')
        (self.config / "Eventos.qml").write_text('''pragma Singleton
import Quickshell
Singleton {
    property var lista: [{inicio:new Date(2030,0,1,12),fin:new Date(2030,0,1,13),titulo:"Clase",todoDia:false}]
    property var tareas: []
    property bool ocupado: false
    property string errorTareas: ""
    property bool conectado: true
    function proximos(n) { return lista.slice(0,n); }
    function diaTexto(d) { return d.toDateString(); }
}
''')

    def test_hoy_filtra_por_dia_y_cabe_en_el_area_de_720(self):
        self.preparar_hoy()
        self.ejecutar('''
    id: prueba
    HoyPaneles { id: hoy; width: 944; fecha: new Date(2030,0,1) }
    Timer { interval: 150; running: true; onTriggered: {
        prueba.comprobar(hoy.columns === 2 && hoy.items.length === 1, "agenda del día seleccionado");
        prueba.comprobar(hoy.implicitHeight <= 400, "calendario y columnas sin recorte");
        hoy.fecha = new Date(2030,0,2);
        prueba.comprobar(hoy.items.length === 0, "selección de otro día filtra eventos");
        hoy.volverHoy();
        prueba.comprobar(hoy.fecha.toDateString() === new Date().toDateString(), "regreso a Hoy");
        hoy.width = 600;
        prueba.comprobar(hoy.columns === 1, "una columna en ancho reducido");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def test_salud_separa_avisos_de_rutina_y_conserva_todas_las_revisiones(self):
        self.preparar_hoy()
        self.ejecutar('''
    id: prueba
    SaludPanel {
        id: salud; width: 944; height: 510
        datos: ({comprobaciones:[{nombre:"Copia",valor:"pendiente",estado:"aviso",detalle:"Conecta el disco"},{nombre:"Disco",valor:"correcto",estado:"ok",detalle:"Sin errores"}]})
    }
    Timer { interval: 100; running: true; onTriggered: {
        prueba.comprobar(salud.alertas.length === 1 && salud.rutina.length === 1, "prioridad de avisos");
        salud.todas = true;
        prueba.comprobar(salud.rutina.length === 1, "desplegar no elimina comprobaciones");
        console.log("ORION_OK"); Qt.quit();
    } }
''')

    def test_no_molestar_vence_sin_anular_motivo_automatico(self):
        shutil.copy(QML / "Notificaciones.qml",self.config)
        shutil.copy(QML / "NotificacionesLogica.js",self.config)
        for nombre,prop in [("Concentracion","activo"),("Reunion","activa")]:
            (self.config/(nombre+".qml")).write_text('pragma Singleton\nimport Quickshell\nSingleton { property bool '+prop+': false }')
        self.ejecutar('''
    id: prueba
    readonly property bool activo: Notificaciones.noMolestar
    Timer { interval: 100; running: true; onTriggered: {
        Notificaciones.pausar("60");
        prueba.comprobar(Notificaciones.manual && Notificaciones.noMolestar, "pausa manual de una hora");
        Notificaciones.motivo("reunion",true);
        Notificaciones.comprobarVencimiento(Date.now()+3601000);
        prueba.comprobar(!Notificaciones.manual && Notificaciones.noMolestar, "vencimiento no cancela reunión");
        Notificaciones.motivo("reunion",false);
        prueba.comprobar(!Notificaciones.noMolestar, "fin de todos los motivos");
        Concentracion.activo=true;Notificaciones.pausar("concentracion");
        prueba.comprobar(Notificaciones.manual, "pausa hasta actividad");
        Concentracion.activo=false;Notificaciones.comprobarVencimiento(Date.now());
        prueba.comprobar(!Notificaciones.manual, "termina con la actividad");
        console.log("ORION_OK");Qt.quit();
    } }
''')

    def test_avisos_se_agrupan_sin_perder_mensajes_o_conversaciones(self):
        shutil.copy(QML / "NotificacionesLogica.js",self.config)
        (self.config/'GruposPrueba.qml').write_text('''import QtQuick
import "NotificacionesLogica.js" as Logica
QtObject {
    function grupos(datos) { return Logica.agrupar(datos); }
}
''')
        self.ejecutar('''
    id: prueba
    GruposPrueba { id: logica }
    Timer { interval: 50; running: true; onTriggered: {
        const lista=[{id:1,desktopEntry:"chat",appName:"Chat",hints:{}},{id:2,desktopEntry:"chat",appName:"Chat",hints:{}},{id:3,desktopEntry:"mail",appName:"Correo",hints:{}}];
        const grupos=logica.grupos(lista);
        prueba.comprobar(grupos.length===2 && grupos.reduce((n,g) => n+g.items.length,0)===3,"agrupar conserva mensajes");
        const conversaciones=logica.grupos([{appName:"Chat",hints:{"x-orion-conversation-id":"a"}},{appName:"Chat",hints:{"x-orion-conversation-id":"b"}}]);
        prueba.comprobar(conversaciones.length===2,"conversaciones independientes");
        console.log("ORION_OK");Qt.quit();
    } }
''')

    def test_agenda_preserva_datos_ante_error_y_se_recupera(self):
        evento = {"inicio": "2030-01-01T12:00:00+00:00", "fin": "2030-01-01T13:00:00+00:00",
                  "titulo": "Clase", "lugar": "", "todoDia": False, "uid": "serie-1"}
        respuestas = [json.dumps({"eventos": [evento], "estado": "actualizado", "actualizado": 100, "error": ""}),
                      json.dumps({"eventos": [evento], "estado": "desactualizado", "actualizado": 100, "error": "Sin red"}),
                      "{inválido", json.dumps({"eventos": [], "estado": "actualizado", "actualizado": 200, "error": ""})]
        (self.scripts / "eventos.py").write_text('''from pathlib import Path
import json
p = Path(__file__).with_suffix('.contador')
n = int(p.read_text()) if p.exists() else 0
p.write_text(str(n+1))
print(json.loads(''' + repr(json.dumps(respuestas)) + ''')[min(n,3)])
''')
        self.ejecutar('''
    id: prueba
    property int paso: 0
    readonly property bool leyendo: Eventos.leyendo
    Timer { interval: 100; running: true; repeat: true; onTriggered: {
        if (Eventos.leyendo || Eventos.estadoAgenda === "cargando") return;
        if (prueba.paso === 0) prueba.comprobar(Eventos.estadoAgenda === "actualizado" && Eventos.lista.length === 1, "primera lectura");
        if (prueba.paso === 1) prueba.comprobar(Eventos.estadoAgenda === "desactualizado" && Eventos.sincronizadoEn === 100, "caché identificada");
        if (prueba.paso === 2) prueba.comprobar(Eventos.lista.length === 1 && Eventos.estadoAgenda === "desactualizado", "respuesta rota conserva datos");
        if (prueba.paso === 3) {
            prueba.comprobar(Eventos.lista.length === 0 && Eventos.estadoAgenda === "actualizado" && Eventos.sincronizadoEn === 200, "recuperar y vaciar agenda realmente vacía");
            console.log("ORION_OK"); Qt.quit(); return;
        }
        prueba.paso++; Eventos.actualizar();
    } }
''')
