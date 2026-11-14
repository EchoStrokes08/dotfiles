#!/usr/bin/env python3
"""Captura explícita que oculta información de ORION durante la toma."""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import uuid


def ruta():
    return Path(os.environ['XDG_RUNTIME_DIR'])/'orion-captura-privada.json'


def leer():
    try:return json.loads(ruta().read_text())
    except (OSError,ValueError):return {'activo':False}


def escribir(d):
    destino=ruta();temporal=destino.with_suffix('.'+uuid.uuid4().hex+'.tmp')
    with temporal.open('x') as f:
        os.chmod(temporal,0o600);json.dump(d,f)
    os.replace(temporal,destino)


def vigente(d,ahora=None):
    return bool(d.get('activo') and d.get('expira',0)>(time.time()*1000 if ahora is None else ahora))


def liberar(token):
    d=leer()
    if d.get('token')==token:escribir({'activo':False})


def capturar(modo,script=None,espera=.65):
    if modo not in ('region','pantalla','ventana'):raise ValueError('Modo de captura no válido')
    with ruta().with_suffix('.lock').open('w') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise ValueError('Ya hay una captura privada en curso')
        token=uuid.uuid4().hex;proceso=None
        def cancelar(*_):raise InterruptedError('Captura cancelada')
        anteriores={s:signal.signal(s,cancelar) for s in (signal.SIGTERM,signal.SIGINT)}
        try:
            escribir({'activo':True,'expira':int(time.time()*1000)+120000,'token':token})
            time.sleep(espera)
            proceso=subprocess.Popen(['bash',str(script or Path(__file__).with_name('capturas.sh')),modo],env={**os.environ,'ORION_CAPTURA_TOKEN':token},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
            while vigente(leer()) and proceso.poll() is None:time.sleep(.05)
            if leer().get('activo') and proceso.poll() is None:raise TimeoutError('La selección de captura caducó')
            # Tras grim, el proceso queda atendiendo los botones de la notificación.
            if proceso.poll() not in (None,0):raise RuntimeError('No se pudo guardar la captura')
        except BaseException:
            if proceso and proceso.poll() is None:
                try:os.killpg(proceso.pid,signal.SIGTERM)
                except ProcessLookupError:pass
            raise
        finally:
            liberar(token)
            for s,previo in anteriores.items():signal.signal(s,previo)


def main():
    try:
        modo=sys.argv[1] if len(sys.argv)>1 else 'region'
        if modo=='estado':
            if not ruta().exists():escribir({'activo':False})
            print(json.dumps(leer()))
        elif modo=='comprobar':
            d=leer()
            return 0 if vigente(d,time.time()*1000+2000) and d.get('token')==sys.argv[2] else 1
        elif modo=='liberar':liberar(sys.argv[2])
        else:capturar(modo)
        return 0
    except Exception:
        subprocess.run(['notify-send','-a','ORION','Captura privada','No se pudo completar. La privacidad temporal se ha restaurado.'],check=False)
        return 1

if __name__=='__main__':sys.exit(main())
