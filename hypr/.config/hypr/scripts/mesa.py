#!/usr/bin/env python3
"""Mesa de trabajo: ventanas, plantillas, reuniones temporizadas y rutinas."""
import argparse
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from escritorio import atomico, captura, checkpoint, directorio, ejecutar, espacio_id

PREDEFINIDAS = [
    {'id': 'plan', 'titulo': 'Plan del día', 'texto': '# {{fecha}}\n\nPrioridad de hoy:\n1. \n2. \n3. \n\nAl terminar: '},
    {'id': 'reunion', 'titulo': 'Notas de reunión', 'texto': '# Reunión · {{fecha}} {{hora}}\n\nObjetivo:\n\nDecisiones:\n\nPróximos pasos:\n- Responsable / tarea / fecha'},
    {'id': 'error', 'titulo': 'Reporte de error', 'texto': 'Problema:\n\nCómo reproducirlo:\n1. \n\nResultado esperado:\n\nResultado observado:\n\nEntorno: '},
]


def ruta_plantillas():
    base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'mesa-trabajo'
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    return base / 'plantillas.json'


def validar_plantilla(titulo, texto):
    if not isinstance(titulo, str) or not titulo.strip() or len(titulo) > 100:
        raise ValueError('El nombre debe tener entre 1 y 100 caracteres')
    if not isinstance(texto, str) or not texto.strip() or len(texto) > 16000 or '\0' in texto:
        raise ValueError('El texto debe tener entre 1 y 16 000 caracteres y no contener NUL')


def expandir(texto, ahora=None):
    ahora = ahora or dt.datetime.now().astimezone()
    valores = {'fecha': ahora.strftime('%Y-%m-%d'), 'hora': ahora.strftime('%H:%M'), 'usuario': os.environ.get('USER', '')}
    return re.sub(r'\{\{(fecha|hora|usuario)\}\}', lambda m: valores[m[1]], texto)


def plantillas(operacion, identificador='', titulo='', texto=''):
    ruta = ruta_plantillas()
    with ruta.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        datos = json.loads(ruta.read_text()) if ruta.exists() else [dict(x) for x in PREDEFINIDAS]
        if not isinstance(datos, list) or len(datos) > 200:
            raise ValueError('Biblioteca de plantillas inválida')
        mensaje = ''
        if operacion == 'guardar':
            validar_plantilla(titulo, texto)
            existente = next((x for x in datos if x['id'] == identificador), None)
            if existente:
                existente.update(titulo=titulo.strip(), texto=texto)
            else:
                if len(datos) >= 200:
                    raise ValueError('Límite de 200 plantillas alcanzado')
                identificador = uuid.uuid4().hex
                datos.append({'id': identificador, 'titulo': titulo.strip(), 'texto': texto})
            mensaje = 'Plantilla guardada'
        elif operacion in ('eliminar', 'copiar'):
            existente = next((x for x in datos if x['id'] == identificador), None)
            if not existente:
                raise ValueError('La plantilla ya no existe; actualiza la lista')
            if operacion == 'eliminar':
                datos = [x for x in datos if x['id'] != identificador]
                mensaje = 'Plantilla eliminada'
            else:
                subprocess.run(['wl-copy', '--', expandir(existente['texto'])], check=True, timeout=4)
                mensaje = 'Copiada con fecha y hora actualizadas'
        elif operacion == 'capturar':
            texto = ejecutar(['wl-paste', '--no-newline'], timeout=3)
            validar_plantilla(titulo, texto)
            if len(datos) >= 200:
                raise ValueError('Límite de 200 plantillas alcanzado')
            datos.append({'id': uuid.uuid4().hex, 'titulo': titulo.strip(), 'texto': texto})
            mensaje = 'Portapapeles guardado como plantilla'
        elif operacion != 'lista':
            raise ValueError('Operación de plantilla inválida')
        if operacion in ('guardar', 'eliminar', 'capturar'):
            atomico(ruta, datos)
        return {'plantillas': datos, 'mensaje': mensaje, 'seleccion': identificador if operacion == 'guardar' else ''}


def normalizar_direccion(valor):
    valor = valor.removeprefix('0x')
    if not re.fullmatch(r'[0-9a-fA-F]{1,16}', valor):
        raise ValueError('Dirección de ventana inválida')
    return '0x' + valor


def ventana(operacion, direccion, workspace=None):
    direccion = normalizar_direccion(direccion)
    actuales = json.loads(ejecutar(['hyprctl', '-j', 'clients']))
    w = next((x for x in actuales if x['address'] == direccion), None)
    if not w:
        raise ValueError('La ventana ya se cerró')
    runtime, firma = directorio()
    ruta = runtime / f'hypr-aparcadas-{firma}.json'
    with ruta.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        datos = json.loads(ruta.read_text()) if ruta.exists() else {}
        selector = '"address:' + direccion + '"'
        aparcada = w['workspace']['name'] == 'special:aparcadas'
        if operacion == 'enfocar' and not aparcada:
            expr = 'hl.dsp.focus({window=' + selector + '})'
        elif operacion == 'flotante':
            expr = 'hl.dsp.window.float({window=' + selector + ',action="toggle"})'
        else:
            if operacion == 'aparcar' and not aparcada:
                if espacio_id(w) <= 0:
                    raise ValueError('No se aparcan ventanas de otros espacios especiales')
                datos[direccion] = {'pid': w['pid'], 'class': w['class'], 'workspace': espacio_id(w)}
                destino = '"special:aparcadas"'
            elif operacion in ('aparcar', 'enfocar') and aparcada:
                anterior = datos.get(direccion, {})
                coincide = anterior.get('pid') == w['pid'] and anterior.get('class') == w['class']
                ws_original = anterior.get('workspace')
                coincide = coincide and type(ws_original) is int and ws_original > 0
                destino = str(ws_original) if coincide else str(json.loads(ejecutar(['hyprctl', '-j', 'activeworkspace']))['id'])
                datos.pop(direccion, None)
            elif operacion == 'mover':
                if type(workspace) is not int or not 1 <= workspace <= 10:
                    raise ValueError('Elige un espacio del 1 al 10')
                destino = str(workspace)
                datos.pop(direccion, None)
            else:
                raise ValueError('Acción de ventana inválida')
            expr = 'hl.dsp.window.move({window=' + selector + ',workspace=' + destino + ',follow=false})'
        resultado = ejecutar(['hyprctl', 'dispatch', expr])
        if resultado != 'ok':
            raise ValueError('Hyprland no completó la acción: ' + resultado)
        atomico(ruta, datos)
        if operacion == 'enfocar' and aparcada:
            ejecutar(['hyprctl', 'dispatch', 'hl.dsp.focus({window=' + selector + '})'])
    return {'mensaje': 'Ventana actualizada'}


def unidad_reunion():
    _, firma = directorio()
    return 'hypr-reunion-' + firma


def ruta_reunion():
    runtime, firma = directorio()
    return runtime / f'hypr-reunion-{firma}.json'


def reunion(accion, minutos=30):
    if accion == 'iniciar':
        if not 1 <= minutos <= 180:
            raise ValueError('Duración admitida: 1–180 minutos')
        args = ['systemd-run', '--user', '--collect', '--quiet', '--unit=' + unidad_reunion(),
                '--property=TimeoutStopSec=10', '--property=RuntimeMaxSec=' + str(minutos * 60 + 15)]
        for nombre in ('XDG_RUNTIME_DIR', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY'):
            args.append('--setenv=' + nombre + '=' + os.environ.get(nombre, ''))
        ejecutar(args + [sys.executable, str(Path(__file__).resolve()), '_reunion', str(minutos)])
        for _ in range(60):
            if ruta_reunion().exists(): break
            time.sleep(.05)
        else: raise ValueError('La reunión no confirmó la inhibición; revisa el servicio de usuario')
        return {'mensaje': f'Reunión iniciada: {minutos} min. Finaliza automáticamente.'}
    if accion == 'terminar':
        ejecutar(['systemctl', '--user', 'stop', unidad_reunion()], timeout=12)
        ruta_reunion().unlink(missing_ok=True)
        ejecutar(['hyprctl', 'dispatch', 'escritorio.motivo("reunion",false) or hl.dsp.no_op()'])
        return {'mensaje': 'Reunión terminada; se conservan tus otros modos'}
    raise ValueError('Acción de reunión inválida')


def trabajador_reunion(minutos):
    terminar = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: terminar.set())
    signal.signal(signal.SIGINT, lambda *_: terminar.set())
    ruta = ruta_reunion()
    inhibidor = None
    try:
        inhibidor = subprocess.Popen(['systemd-inhibit', '--what=idle:sleep', '--mode=block',
            '--who=Mesa de trabajo', '--why=Reunión temporizada', 'sleep', str(minutos * 60)],
            start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(.2)
        if inhibidor.poll() is not None:
            raise ValueError('No se pudo inhibir la inactividad; reunión cancelada')
        atomico(ruta, {'fin': int(time.time()) + minutos * 60, 'minutos': minutos})
        ejecutar(['hyprctl', 'dispatch', 'escritorio.motivo("reunion",true) or hl.dsp.no_op()'])
        limite = time.monotonic() + minutos * 60
        runtime, firma = directorio()
        while not terminar.wait(.5) and time.monotonic() < limite:
            if not (runtime / 'hypr' / firma / '.socket.sock').is_socket():
                break
            if inhibidor.poll() is not None:
                raise ValueError('La inhibición terminó antes de tiempo')
    finally:
        ruta.unlink(missing_ok=True)
        with contextlib.suppress(OSError, subprocess.SubprocessError):
            ejecutar(['hyprctl', 'dispatch', 'escritorio.motivo("reunion",false) or hl.dsp.no_op()'])
        if inhibidor is not None and inhibidor.poll() is None:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(inhibidor.pid, signal.SIGTERM)
            inhibidor.wait(timeout=3)


RUTINAS = {
    'estudiar': ('universidad', 'lectura', 25),
    'programar': ('programar', 'cristal', 50),
    'descansar': ('descanso', 'cristal', 0),
}


SESIONES = [r[0] for r in RUTINAS.values()]


def ruta_sesiones():
    base = ruta_plantillas().parent / 'sesiones'
    base.mkdir(mode=0o700, exist_ok=True)
    return base


def leer_tsv(ruta):
    apps = []
    if not ruta.exists():
        return apps
    for linea in ruta.read_text().splitlines():
        partes = linea.split('\t', 3)
        if len(partes) == 4 and partes[0].isdigit() and partes[3]:
            apps.append({'ws': int(partes[0]), 'clase': partes[1], 'nombre': partes[2], 'cmd': partes[3]})
    return apps


def validar_apps(apps):
    if type(apps) is not list or len(apps) > 12:
        raise ValueError('Elige hasta 12 aplicaciones')
    limpias = []
    for a in apps:
        if type(a) is not dict:
            raise ValueError('Aplicación inválida')
        ws, cmd = a.get('ws'), str(a.get('cmd', '')).strip()
        clase, nombre = str(a.get('clase', '')).strip(), str(a.get('nombre', '')).strip() or cmd
        if type(ws) is not int or not 1 <= ws <= 10:
            raise ValueError('Cada aplicación necesita un espacio del 1 al 10')
        if not cmd:
            raise ValueError('Falta el comando de ' + (nombre or 'una aplicación'))
        if any(c in x for x in (clase, nombre, cmd) for c in '\t\n\r'):
            raise ValueError('Los campos no pueden tener tabuladores ni saltos de línea')
        limpias.append({'ws': ws, 'clase': clase, 'nombre': nombre[:80], 'cmd': cmd})
    return limpias


def sesiones(operacion, identificador='', apps='[]'):
    carpeta = ruta_sesiones()
    if operacion != 'lista':
        if identificador not in SESIONES:
            raise ValueError('Sesión desconocida')
        propia = carpeta / f'{identificador}.tsv'
        if operacion == 'guardar':
            limpias = validar_apps(json.loads(apps))
            texto = ''.join(f"{a['ws']}\t{a['clase']}\t{a['nombre']}\t{a['cmd']}\n" for a in limpias)
            fd, temporal = tempfile.mkstemp(dir=carpeta, prefix='.sesion-')
            with os.fdopen(fd, 'w') as f:
                f.write(texto)
            os.replace(temporal, propia)
            mensaje = 'Apps guardadas: la próxima vez que empieces este modo se abrirán estas'
        else:
            propia.unlink(missing_ok=True)
            mensaje = 'Restauradas las apps de serie'
    else:
        mensaje = ''
    with contextlib.suppress(Exception):   # que Hyprland escriba las de serie (<id>.base.tsv)
        ejecutar(['hyprctl', 'dispatch', 'sesion.exportar() or hl.dsp.no_op()'])
    datos = {}
    for sid in SESIONES:
        propia = carpeta / f'{sid}.tsv'
        datos[sid] = {
            'personalizada': propia.exists(),
            'apps': leer_tsv(propia) if propia.exists() else leer_tsv(carpeta / f'{sid}.base.tsv'),
        }
    return {'sesiones': datos, 'mensaje': mensaje}


def rutina(nombre):
    sesion, perfil, minutos = RUTINAS[nombre]
    checkpoint('guardar')
    ejecutar(['hyprctl', 'dispatch', f'escritorio.perfil("{perfil}") or hl.dsp.no_op()'])
    ejecutar(['hyprctl', 'dispatch', f'sesion.abrir("{sesion}") or hl.dsp.no_op()'])
    if minutos:
        ejecutar(['qs', 'ipc', 'call', 'concentracion', 'empezar', str(minutos)])
    else:
        ejecutar(['qs', 'ipc', 'call', 'concentracion', 'terminar'])
    return {'mensaje': 'Rutina preparada; checkpoint anterior disponible en el centro del escritorio'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='tipo', required=True)
    p = sub.add_parser('plantilla')
    p.add_argument('operacion', choices=['lista', 'guardar', 'eliminar', 'copiar', 'capturar'])
    p.add_argument('--id', default='')
    p.add_argument('--titulo', default='')
    p.add_argument('--texto', default='')
    p = sub.add_parser('ventana')
    p.add_argument('operacion', choices=['enfocar', 'mover', 'aparcar', 'flotante'])
    p.add_argument('direccion')
    p.add_argument('--workspace', type=int)
    p = sub.add_parser('reunion')
    p.add_argument('operacion', choices=['iniciar', 'terminar'])
    p.add_argument('--minutos', type=int, default=30)
    p = sub.add_parser('microfono')
    p.add_argument('operacion', choices=['silenciar','activar'])
    p = sub.add_parser('_reunion')
    p.add_argument('minutos', type=int)
    p = sub.add_parser('sesion')
    p.add_argument('operacion', choices=['lista', 'guardar', 'restaurar'])
    p.add_argument('--id', default='')
    p.add_argument('--apps', default='[]')
    p = sub.add_parser('rutina')
    p.add_argument('nombre', choices=list(RUTINAS))
    a = parser.parse_args()
    if a.tipo == 'plantilla': resultado = plantillas(a.operacion, a.id, a.titulo, a.texto)
    elif a.tipo == 'ventana': resultado = ventana(a.operacion, a.direccion, a.workspace)
    elif a.tipo == 'reunion': resultado = reunion(a.operacion, a.minutos)
    elif a.tipo == 'microfono':
        ejecutar(['wpctl','set-mute','@DEFAULT_AUDIO_SOURCE@','1' if a.operacion == 'silenciar' else '0'])
        resultado = {'mensaje': 'Micrófono silenciado' if a.operacion == 'silenciar' else 'Micrófono activado'}
    elif a.tipo == 'rutina': resultado = rutina(a.nombre)
    elif a.tipo == 'sesion': resultado = sesiones(a.operacion, a.id, a.apps)
    else:
        if not 1 <= a.minutos <= 180: raise ValueError('Duración inválida')
        trabajador_reunion(a.minutos)
        return
    print(json.dumps(resultado, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(json.dumps({'error': str(exc)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
