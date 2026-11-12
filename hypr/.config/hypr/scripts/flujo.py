#!/usr/bin/env python3
"""Proyectos persistentes, organización por tarea y acciones sobre una selección temporal."""
import argparse
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from urllib.parse import unquote, urlparse
from escritorio import atomico, directorio, ejecutar, estado
from mesa import plantillas, normalizar_direccion

APPS = {
    'terminal': ['kitty'], 'navegador': ['firefox', '--new-window', 'about:blank'],
    'editor': ['code', '--new-window'], 'archivos': ['thunar'],
}
CLASES = {'kitty': 'terminal', 'firefox': 'navegador', 'code-oss': 'editor', 'code': 'editor', 'thunar': 'archivos'}
LAYOUTS = {'comparar': 'master', 'programar': 'master', 'investigar': 'scrolling', 'concentrarse': 'monocle'}
ALLOWED_LAYOUTS = {'dwindle', 'master', 'scrolling', 'monocle'}


def despachar(expr):
    salida = ejecutar(['hyprctl', 'dispatch', expr])
    if salida != 'ok': raise ValueError('Hyprland rechazó la operación: ' + salida)


def clientes(): return json.loads(ejecutar(['hyprctl', '-j', 'clients']))
def espacio(): return json.loads(ejecutar(['hyprctl', '-j', 'activeworkspace']))


def ruta_local():
    base = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'mesa-trabajo'
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    return base / 'proyectos.json'


def ruta_temporal(nombre):
    runtime, firma = directorio()
    return runtime / f'hypr-{nombre}-{firma}.json'


@contextlib.contextmanager
def bloqueo(ruta):
    with ruta.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def cargar_proyectos():
    p = ruta_local()
    d = json.loads(p.read_text()) if p.exists() else {'version': 1, 'ultimo': '', 'proyectos': []}
    if d.get('version') != 1 or not isinstance(d.get('proyectos'), list) or len(d['proyectos']) > 30:
        raise ValueError('Biblioteca de proyectos inválida')
    return d


def validar_ruta(texto, carpeta=False):
    if not texto: return ''
    if any(ord(c) < 32 or ord(c) == 127 for c in texto) or len(texto) > 4096: raise ValueError('Ruta inválida')
    p = Path(texto).expanduser()
    if not p.is_absolute(): raise ValueError('Usa una ruta absoluta o ~/ para tus recursos')
    p = p.resolve()
    if not p.exists() or (carpeta and not p.is_dir()): raise ValueError('La carpeta o recurso no existe')
    return str(p)


def clase_app(w):
    clase = w.get('class', '').lower()
    if clase.startswith('continuidad-'): return 'terminal'
    return CLASES.get(clase)


def lista_apps(ventanas):
    resultado, vistos = [], set()
    for w in ventanas:
        app = clase_app(w)
        ws = w.get('workspace', {}).get('id', 0)
        if app and type(ws) is int and 1 <= ws <= 10 and (app, ws) not in vistos:
            resultado.append({'app': app, 'workspace': ws})
            vistos.add((app, ws))
    return resultado[:40]


def plan_proyecto(p, actuales):
    if p.get('perfil') not in ('cristal', 'lectura', 'minimo', 'rendimiento'):
        raise ValueError('Perfil del proyecto inválido')
    carpeta = validar_ruta(p.get('carpeta', ''), carpeta=True)
    recursos = [validar_ruta(x) for x in p.get('recursos', [])]
    if len(recursos) > 12: raise ValueError('Demasiados recursos')
    apps, vistos = [], set()
    for a in p.get('apps', []):
        app, ws = a.get('app'), a.get('workspace')
        if app not in APPS or type(ws) is not int or not 1 <= ws <= 10:
            raise ValueError('Aplicación o espacio guardado inválido')
        if (app, ws) in vistos: continue
        vistos.add((app, ws))
        if any(clase_app(w) == app and w.get('workspace', {}).get('id') == ws for w in actuales): continue
        args = list(APPS[app])
        if app == 'terminal':
            args += ['--class', 'continuidad-' + p['id']]
            if carpeta: args += ['--directory', carpeta]
        if app == 'editor' and carpeta: args.append(carpeta)
        if app == 'archivos' and carpeta: args.append(carpeta)
        apps.append({'workspace': ws, 'argv': args})
    return {'apps': apps, 'recursos': recursos}


def proyectos(accion, ident='', nombre='', siguiente='', carpeta='', recursos=''):
    ruta = ruta_local()
    with bloqueo(ruta):
        d = cargar_proyectos()
        if accion == 'guardar':
            if not nombre.strip() or len(nombre) > 100 or len(siguiente) > 2000:
                raise ValueError('Nombre requerido (máx. 100); próxima tarea máx. 2000 caracteres')
            folder = validar_ruta(carpeta, carpeta=True)
            rutas = [validar_ruta(x.strip()) for x in recursos.splitlines() if x.strip()]
            if len(rutas) > 12: raise ValueError('Admite hasta 12 recursos por proyecto')
            if ident and not any(p['id'] == ident for p in d['proyectos']): raise ValueError('Proyecto inexistente')
            if not ident:
                if len(d['proyectos']) >= 30: raise ValueError('Límite de 30 proyectos alcanzado')
                ident = uuid.uuid4().hex
            _, firma = directorio()
            p = {'id': ident, 'nombre': nombre.strip(), 'siguiente': siguiente, 'carpeta': folder,
                 'recursos': rutas, 'apps': lista_apps(clientes()), 'perfil': estado().get('perfil', 'cristal'),
                 'fecha': int(time.time()), 'instancia': firma}
            d['proyectos'] = [x for x in d['proyectos'] if x['id'] != ident] + [p]
            d['ultimo'] = ident
            atomico(ruta, d)
            return {'proyectos': d['proyectos'], 'ultimo': ident, 'seleccion': ident, 'mensaje': 'Proyecto guardado. Su próxima tarea estará disponible al volver.'}
        p = next((x for x in d['proyectos'] if x['id'] == (ident or d['ultimo'])), None)
        if accion == 'lista': return {'proyectos': d['proyectos'], 'ultimo': d['ultimo']}
        if not p: raise ValueError('No hay un proyecto seleccionado')
        if not re.fullmatch(r'[a-f0-9]{32}', p['id']): raise ValueError('Identificador de proyecto inválido')
        if accion == 'eliminar':
            d['proyectos'] = [x for x in d['proyectos'] if x['id'] != p['id']]
            if d['ultimo'] == p['id']: d['ultimo'] = d['proyectos'][-1]['id'] if d['proyectos'] else ''
            atomico(ruta, d)
            return {'proyectos': d['proyectos'], 'ultimo': d['ultimo'], 'mensaje': 'Proyecto eliminado'}
        if accion == 'retomar':
            plan = plan_proyecto(p, clientes())
            faltantes = sorted({x['argv'][0] for x in plan['apps'] if not shutil.which(x['argv'][0])})
            if plan['recursos'] and not shutil.which('xdg-open'): faltantes.append('xdg-open')
            if faltantes: raise ValueError('Faltan aplicaciones: ' + ', '.join(faltantes))
            pendiente = ruta_temporal('proyecto-pendiente')
            previo = json.loads(pendiente.read_text()) if pendiente.exists() else {}
            if previo.get('id') == p['id'] and time.time() - previo.get('fecha', 0) < 15:
                raise ValueError('Ese proyecto ya se está abriendo; espera unos segundos')
            atomico(pendiente, {'id': p['id'], 'fecha': time.time()})
            despachar(f'escritorio.perfil("{p["perfil"]}") or hl.dsp.no_op()')
            for a in plan['apps']:
                # Código Lua solo con números validados y una cadena JSON; el shell recibe argumentos escapados.
                comando = json.dumps(shlex.join(a['argv']), ensure_ascii=False)
                despachar(f'hl.dsp.exec_cmd({comando}, {{workspace="{a["workspace"]}"}})')
            for recurso in plan['recursos']:
                # Abrir recursos es una acción explícita del usuario; nunca se ejecutan como comandos de shell.
                subprocess.Popen(['xdg-open', recurso], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            d['ultimo'] = p['id']; atomico(ruta, d)
            return {'mensaje': f'Proyecto retomado: {len(plan["apps"])} aplicaciones solicitadas y {len(plan["recursos"])} recursos. No se restauran pestañas ni documentos sin guardar.'}
    raise ValueError('Acción de proyecto inválida')


def firma_ventanas(ws, ventanas):
    return sorted((normalizar_direccion(w['address']), w['pid']) for w in ventanas
                  if w.get('workspace', {}).get('id') == ws and not w.get('floating') and not w.get('fullscreen'))


def organizar(accion, tarea='comparar', token=''):
    ruta = ruta_temporal('organizacion')
    undo = ruta_temporal('organizacion-anterior')
    with bloqueo(ruta):
        ws, ventanas = espacio(), clientes()
        if type(ws.get('id')) is not int or ws['id'] < 1: raise ValueError('Abre un espacio normal para organizar')
        layout = ws.get('tiledLayout')
        if layout not in ALLOWED_LAYOUTS: raise ValueError('El layout actual no admite recuperación segura aquí')
        if accion == 'prever':
            if tarea not in LAYOUTS: raise ValueError('Tarea desconocida')
            firma = firma_ventanas(ws['id'], ventanas)
            if len(firma) < 2: raise ValueError('Necesitas al menos dos ventanas en mosaico, sin pantalla completa')
            candidatas = [w for w in ventanas if [normalizar_direccion(w['address']), w['pid']] in [list(x) for x in firma]]
            preferidas = [w for w in candidatas if clase_app(w) == ('editor' if tarea == 'programar' else 'navegador')]
            principal = (preferidas or candidatas)[0]
            p = {'token': uuid.uuid4().hex, 'fecha': time.time(), 'workspace': ws['id'], 'anterior': layout,
                 'layout': LAYOUTS[tarea], 'tarea': tarea, 'ventanas': firma, 'principal': principal['address']}
            atomico(ruta, p)
            return {'plan': p, 'mensaje': f'Espacio {ws["id"]}: {len(firma)} ventanas → {p["layout"]}. No se trasladan ni cierran aplicaciones.'}
        if accion == 'volver':
            if not undo.exists(): raise ValueError('No hay una organización anterior para recuperar')
            p = json.loads(undo.read_text())
            if ws['id'] != p.get('workspace'): raise ValueError(f'Vuelve al espacio {p.get("workspace")} para recuperar su layout')
            if p.get('anterior') not in ALLOWED_LAYOUTS: raise ValueError('Layout anterior inválido')
            salida = ejecutar(['hyprctl', 'eval', f'hl.workspace_rule({{workspace="{ws["id"]}",layout="{p["anterior"]}"}})'])
            if salida != 'ok': raise ValueError(salida)
            undo.unlink()
            return {'plan': None, 'mensaje': 'Layout anterior recuperado; la geometría exacta del árbol no se conserva.'}
        if accion != 'aplicar' or not ruta.exists(): raise ValueError('Genera primero una previsualización')
        p = json.loads(ruta.read_text())
        if p.get('token') != token or time.time()-p.get('fecha',0)>120: raise ValueError('La previsualización caducó; genera otra')
        if p.get('layout') not in ALLOWED_LAYOUTS or p.get('anterior') not in ALLOWED_LAYOUTS or LAYOUTS.get(p.get('tarea')) != p.get('layout'): raise ValueError('Plan inválido')
        if p.get('workspace') != ws['id'] or [list(x) for x in firma_ventanas(ws['id'], ventanas)] != p.get('ventanas'):
            raise ValueError('Cambiaron las ventanas o el espacio; vuelve a previsualizar')
        normalizar_direccion(p['principal'])
        if p['principal'] not in {x[0] for x in p['ventanas']}: raise ValueError('Ventana principal ajena al plan')
        atomico(undo, p)
        codigo = f'if hl.get_active_workspace().id ~= {ws["id"]} then error("Cambio de espacio") end; '
        codigo += f'hl.workspace_rule({{workspace="{ws["id"]}",layout="{p["layout"]}"}}); '
        codigo += f'hl.dispatch(hl.dsp.focus({{window="address:{p["principal"]}"}}))'
        if p['tarea'] == 'programar': codigo += '; hl.dispatch(hl.dsp.layout("swapwithmaster master ignoremaster"))'
        salida = ejecutar(['hyprctl', 'eval', codigo])
        if salida != 'ok': raise ValueError('No se completó la organización: '+salida)
        ruta.unlink()
        return {'plan': None, 'mensaje': 'Organización aplicada. Puedes volver al layout anterior desde este panel.'}


def leer_seleccion(token=''):
    ruta = ruta_temporal('seleccion')
    if not ruta.exists(): raise ValueError('Captura una selección antes de elegir una acción')
    d = json.loads(ruta.read_text())
    if time.time()-d.get('fecha',0)>600:
        ruta.unlink(); raise ValueError('La selección caducó; captura otra')
    if token and d.get('token') != token: raise ValueError('La selección cambió; revisa la vista previa')
    if not isinstance(d.get('texto'), str) or not 0 < len(d['texto']) <= 32000: raise ValueError('Selección inválida')
    return d


def recurso(texto):
    t = texto.strip()
    if '\n' in t or '\0' in t: return ''
    u = urlparse(t)
    if u.scheme in ('http','https') and u.hostname: return t
    if u.scheme == 'file' and u.netloc in ('','localhost'): t = unquote(u.path)
    elif u.scheme: return ''
    if t.startswith(('/', '~/')):
        with contextlib.suppress(ValueError, OSError): return validar_ruta(t)
    return ''


def seleccion(accion, token=''):
    ruta = ruta_temporal('seleccion')
    with bloqueo(ruta):
        if accion == 'capturar':
            texto, origen = '', ''
            for args, nombre in [(['wl-paste','--primary','--no-newline','--type','text'],'selección'), (['wl-paste','--no-newline','--type','text'],'portapapeles')]:
                try: texto = subprocess.run(args, capture_output=True, text=True, check=True, timeout=2).stdout
                except (OSError, subprocess.SubprocessError): continue
                if texto.strip(): origen = nombre; break
            if not texto.strip(): raise ValueError('No hay una selección ni texto en el portapapeles')
            if len(texto)>32000: raise ValueError('Selecciona hasta 32 000 caracteres')
            d = {'token': uuid.uuid4().hex, 'fecha': time.time(), 'texto': texto, 'origen': origen}
            atomico(ruta, d)
        elif accion == 'limpiar':
            if ruta.exists():
                d = json.loads(ruta.read_text())
                if token and d.get('token') == token: ruta.unlink()
            return {'mensaje': 'Selección temporal retirada'}
        else: d = leer_seleccion(token)
        if accion in ('capturar','vista'):
            return {'seleccion': {'token':d['token'],'vista':d['texto'][:700], 'caracteres':len(d['texto']), 'origen':d['origen'], 'recurso':bool(recurso(d['texto']))}, 'mensaje':'Revisa el texto antes de actuar. No se ejecuta automáticamente.'}
        if not token: raise ValueError('Falta confirmar la selección')
        texto = d['texto']
        if accion in ('copiar','mayusculas','minusculas','limpiar-espacios'):
            if accion == 'mayusculas': texto = texto.upper()
            if accion == 'minusculas': texto = texto.lower()
            if accion == 'limpiar-espacios': texto = '\n'.join(' '.join(x.split()) for x in texto.splitlines()).strip()
            subprocess.run(['wl-copy','--',texto],check=True,timeout=4)
        elif accion == 'plantilla':
            plantillas('guardar',titulo='Selección · '+dt.datetime.now().strftime('%m-%d %H:%M'),texto=texto)
        elif accion == 'nota':
            notas = Path.home()/'Documents/notas.md'; notas.parent.mkdir(exist_ok=True)
            with notas.open('a') as f:
                fcntl.flock(f,fcntl.LOCK_EX)
                f.write('\n- '+dt.datetime.now().strftime('%Y-%m-%d %H:%M')+' ·\n'+''.join('  > '+l+'\n' for l in texto.splitlines()))
        elif accion in ('resumir','explicar','traducir'):
            runtime,_ = directorio(); fd,nombre=tempfile.mkstemp(dir=runtime)
            try:
                with os.fdopen(fd,'w') as f: f.write(texto)
                os.replace(nombre,runtime/'ia-entrada.txt')
            finally:
                if os.path.exists(nombre):os.unlink(nombre)
            ejecutar(['qs','ipc','call','ia','abrir',accion,''])
        elif accion == 'abrir':
            destino = recurso(texto)
            if not destino: raise ValueError('La selección no es una URL web ni una ruta existente')
            subprocess.Popen(['xdg-open',destino],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        else: raise ValueError('Acción de selección desconocida')
        return {'mensaje': 'Acción completada sobre la selección capturada'}


def main():
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='tipo',required=True)
    a=sub.add_parser('abrir');a.add_argument('pagina',choices=['continuidad','organizar','seleccion'])
    a=sub.add_parser('proyecto');a.add_argument('accion',choices=['lista','guardar','retomar','eliminar'])
    for nombre in ('id','nombre','siguiente','carpeta','recursos'):a.add_argument('--'+nombre,default='')
    a=sub.add_parser('organizar');a.add_argument('accion',choices=['prever','aplicar','volver']);a.add_argument('--tarea',choices=list(LAYOUTS),default='comparar');a.add_argument('--token',default='')
    a=sub.add_parser('seleccion');a.add_argument('accion',choices=['capturar','vista','limpiar','copiar','mayusculas','minusculas','limpiar-espacios','plantilla','nota','resumir','explicar','traducir','abrir']);a.add_argument('--token',default='')
    a=p.parse_args()
    if a.tipo=='abrir':
        if a.pagina=='seleccion':seleccion('capturar')
        ejecutar(['qs','ipc','call','flujo','abrir',a.pagina]);return
    if a.tipo=='proyecto':r=proyectos(a.accion,a.id,a.nombre,a.siguiente,a.carpeta,a.recursos)
    elif a.tipo=='organizar':r=organizar(a.accion,a.tarea,a.token)
    else:r=seleccion(a.accion,a.token)
    print(json.dumps(r,ensure_ascii=False))


if __name__=='__main__':
    try:main()
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as e:
        print(json.dumps({'error':str(e)},ensure_ascii=False),file=sys.stderr);sys.exit(1)
