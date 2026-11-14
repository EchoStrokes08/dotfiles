#!/usr/bin/env python3
"""Acciones tipadas de ORION: resolver identidad, validar capacidades, ejecutar y recuperar.

acciones.py opciones|ejecutar|deshacer JSON
No acepta comandos de shell ni rutas de bibliotecas proporcionadas por la interfaz.
"""
import datetime as dt
import configparser
import mimetypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid
from urllib.parse import urlparse, unquote, quote
import mesa
import flujo
import gcal
from escritorio import atomico, ejecutar

HOME = Path.home()
ESTADO = Path(os.environ.get('XDG_STATE_HOME', str(HOME / '.local/state'))) / 'orion-acciones'


def campo(nombre, etiqueta, valor='', tipo='texto', opciones=None):
    return {'nombre':nombre,'etiqueta':etiqueta,'valor':valor,'tipo':tipo,'opciones':opciones or []}


def accion(codigo, titulo, campos=None):
    return {'codigo':codigo,'titulo':titulo,'campos':campos or []}


def titulo_web(url, titulo=''):
    if titulo.strip() and not titulo.startswith(('http://','https://')):
        return titulo.strip()
    u=urlparse(url)
    ruta=unquote(u.path).rstrip('/').split('/')[-1].replace('-',' ').replace('_',' ')
    return (ruta[:90] + ' · ' if ruta else '') + (u.hostname or 'Página web')


def ventana(ref):
    direccion=mesa.normalizar_direccion(ref['id'])
    w=next((w for w in json.loads(ejecutar(['hyprctl','-j','clients'])) if w['address']==direccion),None)
    if not w or (ref.get('pid') is not None and ref['pid'] != w['pid']):
        raise ValueError('La ventana ya no está disponible. Actualiza la búsqueda.')
    return w


def elemento(ref):
    tipo=ref.get('tipo'); ident=ref.get('id','')
    if tipo=='ventana': return ventana(ref)
    if tipo=='plantilla':
        if not ident:return {'id':'','titulo':'','texto':''}
        lista=mesa.plantillas('lista')['plantillas']
    elif tipo=='proyecto':
        if not ident:return {'id':'','nombre':'','siguiente':'','recursos':[],'carpeta':''}
        lista=flujo.cargar_proyectos()['proyectos']
    elif tipo=='archivo':
        p=Path(ident).expanduser().resolve(strict=True)
        if not p.is_relative_to(HOME.resolve()): raise ValueError('Elige un archivo de tu carpeta personal.')
        return p
    elif tipo=='web':
        u=urlparse(ident)
        if u.scheme not in ('https','http') or not u.hostname:raise ValueError('Dirección web no válida')
        return ident
    elif tipo=='actividad' and ident in ('reunion','concentracion'): return ident
    elif tipo=='recordatorio':
        ruta=HOME/'.local/state/quickshell/recordatorios.json'
        lista=json.loads(ruta.read_text())
        d=next((x for x in lista if x['id']==ident),None)
        if not d:raise ValueError('El recordatorio ya no está pendiente.')
        return d
    elif tipo=='evento':
        lista=json.loads((HOME/'.cache/calendario/eventos.json').read_text())
        d=next((x for x in lista if x.get('uid','')==ident and (not ref.get('calendario') or x.get('calendario')==ref['calendario']) and abs(dt.datetime.fromisoformat(x['inicio']).timestamp()*1000-ref['inicio'])<1000),None)
        if not d:raise ValueError('El evento ya no está en la copia de la agenda. Actualízala.')
        return d
    elif tipo=='tarea':
        t=next((t for t in gcal.tareas() if t['id']==ident),None)
        if not t:raise ValueError('La tarea ya no está pendiente.')
        return t
    else:raise ValueError('Este resultado no ofrece acciones secundarias.')
    dato=next((x for x in lista if x['id']==ident),None)
    if not dato:raise ValueError('El elemento ya no existe. Actualiza la lista.')
    return dato


def revision(dato):
    return hashlib.sha256(json.dumps(dato,sort_keys=True,default=str).encode()).hexdigest()


def aplicaciones_para(ruta):
    carpetas=[HOME/'.local/share/applications',Path('/usr/share/applications')]
    recomendadas=[]
    try:
        mime=mimetypes.guess_type(str(ruta))[0] or 'application/octet-stream'
        salida=subprocess.run(['gio','mime',mime],capture_output=True,text=True,timeout=3).stdout
        recomendadas=re.findall(r'[A-Za-z0-9._+-]+\.desktop',salida)
    except (OSError,subprocess.SubprocessError):pass
    opciones=[]
    vistos=set()
    rutas=[p for carpeta in carpetas for p in carpeta.glob('*.desktop')]
    rutas.sort(key=lambda p:(p.name not in recomendadas,p.name))
    for p in rutas:
        if p.name in vistos:continue
        try:
            datos=configparser.ConfigParser(interpolation=None,strict=False);datos.read(p,encoding='utf-8')
            app=datos['Desktop Entry']
            if app.get('Type')!='Application' or app.get('Hidden','false')=='true' or app.get('NoDisplay','false')=='true':continue
            nombre=app.get('Name[es]',app.get('Name',p.stem))
            opciones.append({'valor':p.name,'texto':nombre});vistos.add(p.name)
        except (OSError,ValueError,KeyError,configparser.Error):continue
    return opciones[:60]


def opciones(ref):
    d=elemento(ref); tipo=ref['tipo']; ident=ref.get('id',''); acciones=[]; vista=''
    if tipo=='ventana':
        espacios=json.loads(ejecutar(['hyprctl','-j','workspaces']))
        clientes=json.loads(ejecutar(['hyprctl','-j','clients']))
        lista=[]
        for n in range(1,11):
            ws=next((w for w in espacios if w.get('id')==n),{})
            apps=sorted({w.get('class','') for w in clientes if w.get('workspace',{}).get('id')==n})
            nombre=ws.get('name') or str(n)
            lista.append({'valor':str(n),'texto':('Espacio '+nombre if nombre.isdigit() else nombre)+(' · '+', '.join(apps[:3]) if apps else ' · vacío')})
        acciones=[accion('enfocar','Ir a la ventana'),accion('mover','Mover a otro espacio',[campo('workspace','Destino',str(d['workspace'].get('id',1) if d['workspace'].get('id',1) in range(1,11) else 1),'selector',lista)]),
                  accion('aparcar','Recuperar ventana' if d['workspace']['name']=='special:aparcadas' else 'Aparcar ventana'),
                  accion('cerrar','Cerrar ventana',[campo('confirmar','Puede haber trabajo sin guardar. Escribe CERRAR para continuar.','','confirmacion')])]
        vista=d.get('class','')+' · '+d['workspace']['name']
    elif tipo=='plantilla':
        campos=[campo('titulo','Nombre',d['titulo']),campo('texto','Texto de la plantilla',d['texto'],'multilinea')]
        acciones=[accion('guardar','Editar plantilla' if ident else 'Crear plantilla',campos)]
        if ident:acciones=[accion('copiar','Copiar plantilla'),*acciones,accion('duplicar','Duplicar'),accion('eliminar','Borrar · se puede deshacer')]
        vista=d['texto']
    elif tipo=='proyecto':
        campos=[campo('nombre','Nombre',d['nombre']),campo('siguiente','Siguiente paso',d.get('siguiente',''),'multilinea')]
        acciones=[accion('guardar','Guardar proyecto actual',campos)] if not ident else [accion('retomar','Retomar proyecto'),accion('editar','Editar nombre y siguiente paso',campos),accion('actualizar','Actualizar ventanas del proyecto'),accion('archivar','Archivar · se puede deshacer')]
        vista=(d.get('siguiente') or 'Sin siguiente paso')+'\n'+str(len(d.get('apps',[])))+' aplicaciones · '+str(len(d.get('recursos',[])))+' recursos'
    elif tipo=='archivo':
        apps=aplicaciones_para(d)
        acciones=[accion('abrir','Abrir'),accion('carpeta','Abrir carpeta'),accion('ruta','Copiar ruta'),accion('abrir_con','Abrir con…',[campo('aplicacion','Aplicación', (apps[0]['valor'] if apps else ''),'selector',apps)])]
        if not apps:acciones=[a for a in acciones if a['codigo']!='abrir_con']
        vista=str(d)
        if d.is_file() and d.stat().st_size<=200000 and d.suffix.lower() in ('.txt','.md','.py','.json','.qml','.lua','.csv','.log') and not re.search(r'(\.env|secret|token|credencial|\.ssh|\.aws)',str(d),re.I):
            vista+='\n\n'+d.read_text(errors='replace')[:4000]
    elif tipo=='web':
        acciones=[accion('abrir','Abrir enlace'),accion('copiar','Copiar enlace'),accion('privada','Abrir en ventana privada'),accion('ocultar','Ocultar de ORION · se puede deshacer')]
        vista=ident
    elif tipo=='actividad':
        acciones=[accion('iniciar','Iniciar actividad',[campo('minutos','Duración en minutos','30')]),accion('terminar','Terminar actividad')]
        vista='Reunión activa privacidad y No molestar.' if ident=='reunion' else 'Concentración oculta distracciones hasta terminar.'
    elif tipo=='recordatorio':
        acciones=[accion('descartar','Descartar · se puede deshacer'),accion('posponer','Posponer',[campo('fecha','Nueva fecha y hora (AAAA-MM-DD HH:MM)',dt.datetime.fromtimestamp(d['cuando']/1000).strftime('%Y-%m-%d %H:%M'))])]
        vista=d['texto']+'\n'+dt.datetime.fromtimestamp(d['cuando']/1000).strftime('%d/%m/%Y %H:%M')
    elif tipo=='evento':
        acciones=[accion('calendario','Ver y editar en Google Calendar')]
        vista=d['titulo']+'\n'+dt.datetime.fromisoformat(d['inicio']).strftime('%d/%m/%Y %H:%M')+'\n'+d.get('lugar','')
    elif tipo=='tarea':
        acciones=[accion('editar','Cambiar título',[campo('titulo','Título de la tarea',d.get('titulo',''))]),accion('completar','Marcar completada'),accion('posponer','Cambiar fecha',[campo('fecha','Nueva fecha (AAAA-MM-DD)',dt.date.today().isoformat())])]
        vista=d['titulo']
    return {'ok':True,'acciones':acciones,'vista':vista[:5000],'revision':revision(d)}


def guardar_deshacer(tipo, antes, despues=None):
    ESTADO.mkdir(mode=0o700,parents=True,exist_ok=True)
    token=uuid.uuid4().hex
    atomico(ESTADO/(token+'.json'),{'tipo':tipo,'antes':antes,'despues':despues,'fecha':time.time()})
    return token


def ocultos():
    try:return json.loads((ESTADO/'web-oculta.json').read_text())
    except (OSError,ValueError):return []


def ejecutar_accion(ref, codigo, valores=None):
    valores=valores or {}; tipo=ref['tipo']; ident=ref.get('id',''); d=elemento(ref)
    if ref.get('revision') and tipo in ('plantilla','proyecto','recordatorio','tarea') and revision(d)!=ref['revision']:raise ValueError('El elemento cambió desde que abriste sus acciones. Vuelve a consultarlo antes de editar.')
    permitidas={x['codigo'] for x in opciones(ref)['acciones']}
    if codigo not in permitidas:raise ValueError('La acción no está disponible para este elemento.')
    token=''; mensaje='Acción completada'
    if tipo=='ventana':
        if codigo=='cerrar':
            if valores.get('confirmar')!='CERRAR':raise ValueError('Escribe CERRAR para confirmar.')
            ejecutar(['hyprctl','dispatch','hl.dsp.window.close({window="address:'+mesa.normalizar_direccion(ident)+'"})'])
            mensaje='Se solicitó cerrar la ventana'
        else:
            ws=int(valores.get('workspace',0)) if codigo=='mover' else None
            mesa.ventana(codigo,ident,ws)
            if codigo in ('mover','aparcar'):
                actual=ventana(ref)
                token=guardar_deshacer('ventana',{'ref':ref,'workspace':d['workspace']},actual['workspace']['name'])
            mensaje='Ventana actualizada'
    elif tipo=='plantilla':
        if codigo in ('copiar','duplicar','guardar'):
            if codigo=='copiar':mesa.plantillas('copiar',ident);mensaje='Plantilla copiada'
            elif codigo=='duplicar':mesa.plantillas('guardar','',d['titulo'][:90]+' · copia',d['texto']);mensaje='Plantilla duplicada'
            else:mesa.plantillas('guardar',ident,valores.get('titulo',''),valores.get('texto',''));mensaje='Plantilla guardada'
        elif codigo=='eliminar':
            token=guardar_deshacer('plantilla',d)
            mesa.plantillas('eliminar',ident);mensaje='Plantilla enviada a recuperación'
    elif tipo=='proyecto':
        if codigo=='guardar':flujo.proyectos('guardar','',valores.get('nombre',''),valores.get('siguiente',''));mensaje='Proyecto guardado'
        elif codigo=='retomar':mensaje=flujo.proyectos('retomar',ident)['mensaje']
        elif codigo=='actualizar':
            mensaje=flujo.proyectos('guardar',ident,d['nombre'],d.get('siguiente',''),d.get('carpeta',''),'\n'.join(d.get('recursos',[])))['mensaje']
        elif codigo=='editar':
            nombre=valores.get('nombre','').strip();siguiente=valores.get('siguiente','')
            if not nombre or len(nombre)>100 or len(siguiente)>2000:raise ValueError('Revisa nombre (1–100) y siguiente paso (máximo 2000 caracteres).')
            ruta=flujo.ruta_local()
            with flujo.bloqueo(ruta):
                datos=flujo.cargar_proyectos();actual=next((p for p in datos['proyectos'] if p['id']==ident),None)
                if not actual:raise ValueError('El proyecto ya no existe')
                actual.update(nombre=nombre,siguiente=siguiente);atomico(ruta,datos)
            mensaje='Proyecto actualizado; se conservaron sus ventanas y recursos'
        elif codigo=='archivar':
            token=guardar_deshacer('proyecto',d);flujo.proyectos('eliminar',ident);mensaje='Proyecto archivado'
    elif tipo=='archivo':
        if codigo=='abrir':subprocess.Popen(['xdg-open',str(d)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);mensaje='Se solicitó abrir el archivo'
        elif codigo=='carpeta':subprocess.Popen(['xdg-open',str(d if d.is_dir() else d.parent)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);mensaje='Carpeta solicitada'
        elif codigo=='ruta':subprocess.run(['wl-copy','--',str(d)],check=True,timeout=4);mensaje='Ruta copiada'
        elif codigo=='abrir_con':
            app=valores.get('aplicacion','').removesuffix('.desktop')
            if not re.fullmatch(r'[A-Za-z0-9._+-]{1,150}',app):raise ValueError('Identificador de aplicación no válido')
            subprocess.run(['gtk-launch',app,str(d)],check=True,timeout=8);mensaje='Archivo enviado a la aplicación elegida'
    elif tipo=='web':
        if codigo=='copiar':subprocess.run(['wl-copy','--',d],check=True,timeout=4);mensaje='Enlace copiado'
        elif codigo in ('abrir','privada'):
            subprocess.Popen(['firefox',*(['--private-window'] if codigo=='privada' else []),d],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);mensaje='Se solicitó abrir el enlace'
        elif codigo=='ocultar':
            actuales=ocultos();token=guardar_deshacer('web',d);atomico(ESTADO/'web-oculta.json',list(dict.fromkeys([*actuales,d])));mensaje='Enlace oculto de ORION; el historial de Firefox se conserva'
    elif tipo=='actividad':
        minutos=int(valores.get('minutos',30))
        if not 1<=minutos<=240:raise ValueError('Elige entre 1 y 240 minutos.')
        if ident=='reunion':mesa.reunion('iniciar' if codigo=='iniciar' else 'terminar',minutos)
        else:
            salida=ejecutar(['qs','ipc','call','concentracion','empezar',str(minutos)] if codigo=='iniciar' else ['qs','ipc','call','concentracion','terminar'])
            if 'Not ready' in salida:raise ValueError('El coordinador no está listo. Reintenta.')
        mensaje='Actividad iniciada' if codigo=='iniciar' else 'Actividad terminada; políticas restauradas'
    elif tipo=='recordatorio':
        ruta=HOME/'.local/state/quickshell/recordatorios.json'
        with ruta.with_suffix('.lock').open('w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            datos=json.loads(ruta.read_text());actual=next((x for x in datos if x['id']==ident),None)
            if not actual:raise ValueError('El recordatorio ya no existe.')
            antes=dict(actual)
            if codigo=='descartar':datos=[x for x in datos if x['id']!=ident];despues=None
            else:
                fecha=dt.datetime.fromisoformat(valores.get('fecha','')).astimezone()
                if fecha.timestamp()<=time.time():raise ValueError('Elige una fecha futura.')
                actual['cuando']=int(fecha.timestamp()*1000);despues=dict(actual)
            token=guardar_deshacer('recordatorio',antes,despues);atomico(ruta,datos)
        mensaje='Recordatorio descartado' if codigo=='descartar' else 'Recordatorio pospuesto'
    elif tipo=='evento':
        fecha=dt.datetime.fromisoformat(d['inicio'])
        url=f'https://calendar.google.com/calendar/u/0/r/day/{fecha.year}/{fecha.month}/{fecha.day}'
        subprocess.Popen(['xdg-open',url],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);mensaje='Agenda solicitada en Google Calendar'
    elif tipo=='tarea':
        if codigo=='editar':
            titulo=valores.get('titulo','').strip()
            if not titulo:raise ValueError('Escribe el título de la tarea.')
            gcal.api('PATCH',gcal.TASKS+'/'+quote(ident,safe=''),{'title':titulo});mensaje='Título de tarea actualizado'
        elif codigo=='completar':gcal.hecha(ident);mensaje='Tarea completada en Google Tasks'
        else:
            fecha=dt.date.fromisoformat(valores.get('fecha',''))
            gcal.api('PATCH',gcal.TASKS+'/'+quote(ident,safe=''),{'due':fecha.isoformat()+'T00:00:00.000Z'});mensaje='Fecha de tarea actualizada'
    return {'ok':True,'mensaje':mensaje,'deshacer':token}


def deshacer(token):
    if not re.fullmatch(r'[0-9a-f]{32}',token):raise ValueError('Recuperación no válida')
    ruta=ESTADO/(token+'.json')
    if not ruta.exists():raise ValueError('Esta acción ya se recuperó o no está disponible')
    with ruta.with_suffix('.lock').open('w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        dato=json.loads(ruta.read_text());tipo=dato['tipo'];antes=dato['antes']
        if tipo=='plantilla':
            biblioteca=mesa.ruta_plantillas()
            with biblioteca.with_suffix('.lock').open('w') as guardar:
                fcntl.flock(guardar,fcntl.LOCK_EX)
                datos=json.loads(biblioteca.read_text()) if biblioteca.exists() else [dict(x) for x in mesa.PREDEFINIDAS]
                if any(x['id']==antes['id'] for x in datos):raise ValueError('Ya existe una plantilla con ese identificador. No se sobrescribió.')
                datos.append(antes);atomico(biblioteca,datos)
        elif tipo=='proyecto':
            biblioteca=flujo.ruta_local()
            with flujo.bloqueo(biblioteca):
                datos=flujo.cargar_proyectos()
                if any(x['id']==antes['id'] for x in datos['proyectos']):raise ValueError('El proyecto ya existe. No se sobrescribió.')
                datos['proyectos'].append(antes);datos['ultimo']=antes['id'];atomico(biblioteca,datos)
        elif tipo=='web':atomico(ESTADO/'web-oculta.json',[u for u in ocultos() if u!=antes])
        elif tipo=='recordatorio':
            biblioteca=HOME/'.local/state/quickshell/recordatorios.json'
            with biblioteca.with_suffix('.lock').open('w') as guardar:
                fcntl.flock(guardar,fcntl.LOCK_EX)
                datos=json.loads(biblioteca.read_text())
                actual=next((x for x in datos if x['id']==antes['id']),None)
                if actual != dato.get('despues'):raise ValueError('El recordatorio cambió después. No se sobrescribió.')
                if antes['cuando']<=time.time()*1000:raise ValueError('La hora original ya pasó. Crea un nuevo recordatorio con una hora futura.')
                datos=[x for x in datos if x['id']!=antes['id']]+[antes];atomico(biblioteca,datos)
        elif tipo=='ventana':
            w=ventana(antes['ref'])
            if w['workspace']['name']!=dato['despues']:raise ValueError('La ventana se movió después. Se conserva su ubicación actual.')
            if antes['workspace']['name']=='special:aparcadas':mesa.ventana('aparcar',antes['ref']['id'])
            else:mesa.ventana('mover',antes['ref']['id'],antes['workspace']['id'])
        else:raise ValueError('No se puede recuperar esta acción')
        ruta.unlink()
    return {'ok':True,'mensaje':'Acción recuperada','deshacer':''}


def main(argv=None):
    args=sys.argv[1:] if argv is None else argv
    try:
        dato=json.loads(args[1]);op=args[0]
        if op=='opciones':r=opciones(dato)
        elif op=='ejecutar':r=ejecutar_accion(dato['ref'],dato['accion'],dato.get('valores'))
        elif op=='deshacer':r=deshacer(dato['token'])
        else:raise ValueError('Operación desconocida')
    except (ValueError,KeyError,TypeError,OSError,IndexError,subprocess.SubprocessError,gcal.Error) as e:
        r={'ok':False,'error':str(e)[:500]}
    print(json.dumps(r,ensure_ascii=False));return 0 if r['ok'] else 1


if __name__=='__main__':sys.exit(main())
