#!/usr/bin/env python3
"""Replay con identidad de proceso, exclusión mutua y política por sesión."""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from escritorio import atomico, directorio, estado

DESTINO = Path.home() / "Videos/Replays"


def identidad(pid):
    try:
        p = Path('/proc') / str(pid)
        args = (p / 'cmdline').read_bytes().decode().strip('\0').split('\0')
        if p.stat().st_uid != os.getuid() or Path(args[0]).name != 'gpu-screen-recorder':
            return None
        if '-r' not in args or '-o' not in args or args[args.index('-o') + 1] != str(DESTINO):
            return None
        # /proc/stat: el campo comm puede tener espacios; starttime es el campo 22.
        inicio = (p / 'stat').read_text().rsplit(')', 1)[1].split()[19]
        return {"pid": int(pid), "inicio": inicio}
    except (OSError, ValueError, IndexError):
        return None


def buscar(archivo):
    try:
        dato = json.loads(archivo.read_text())
        if identidad(dato['pid']) == dato:
            return dato
    except (OSError, ValueError, KeyError):
        pass
    # Adopta únicamente un replay del usuario con el destino esperado (migración del script anterior).
    for p in Path('/proc').iterdir():
        if p.name.isdigit():
            dato = identidad(int(p.name))
            if dato:
                atomico(archivo, dato)
                return dato
    return None


def iniciar(archivo, log):
    DESTINO.mkdir(parents=True, exist_ok=True)
    opciones = subprocess.run(['gpu-screen-recorder', '--list-capture-options'], capture_output=True, text=True, timeout=5, check=True).stdout
    monitor = next((l.split('|')[0] for l in opciones.splitlines() if l.startswith('eDP-1|')), None)
    if monitor is None:
        monitor = next((l.split('|')[0] for l in opciones.splitlines() if l.startswith(('HDMI-', 'DP-', 'eDP-', 'DVI-')) and '|' in l), None)
    if not monitor:
        raise ValueError('No hay salida disponible para replay')
    with log.open('w') as salida:
        proc = subprocess.Popen(['gpu-screen-recorder', '-w', monitor, '-f', '60', '-c', 'mp4', '-a', 'default_output',
                                 '-r', '30', '-replay-storage', 'ram', '-o', str(DESTINO),
                                 '-sc', str(Path(__file__).with_suffix('.sh'))],
                                stdout=salida, stderr=salida, start_new_session=True)
    time.sleep(0.25)
    dato = identidad(proc.pid)
    if not dato or proc.poll() is not None:
        raise ValueError('El grabador no arrancó; consulta replay.log en el directorio runtime')
    atomico(archivo, dato)


def main():
    accion = sys.argv[1] if len(sys.argv) > 1 else 'estado'
    if accion not in ('start', 'stop', 'toggle', 'save', 'auto', 'reconciliar', 'estado'):
        # Callback del grabador: no ejecutar texto recibido, solo notificar archivo existente.
        if Path(accion).is_file():
            subprocess.run(['notify-send', '-a', 'Replay', 'Replay guardado', Path(accion).name], timeout=3)
            return
        raise ValueError('Acción de replay desconocida')
    runtime, firma = directorio()
    carpeta = runtime / f'hypr-replay-{firma}'
    carpeta.mkdir(mode=0o700, exist_ok=True)
    with (carpeta / 'lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        archivo = carpeta / 'proceso.json'
        modo = carpeta / 'modo'
        dato = buscar(archivo)
        e = estado()
        if accion == 'estado':
            print('grabando' if dato else 'apagado')
            return
        if accion == 'save':
            if not dato:
                raise ValueError('Replay apagado')
            os.kill(dato['pid'], signal.SIGUSR1)
            return
        if accion in ('start', 'stop', 'toggle', 'auto'):
            modo.write_text({'start': 'si', 'stop': 'no', 'auto': 'auto', 'toggle': 'no' if dato else 'si'}[accion])
        preferencia = modo.read_text().strip() if modo.exists() else 'auto'
        deseado = preferencia == 'si' or (preferencia == 'auto' and e.get('pausar_replay') == 'false')
        # Privacidad siempre gana, incluso sobre el encendido manual.
        deseado = deseado and e.get('privacidad_activa', e.get('privacidad')) != 'true'
        if dato and not deseado:
            os.kill(dato['pid'], signal.SIGINT)
            for _ in range(30):
                if identidad(dato['pid']) != dato:
                    break
                time.sleep(0.1)
            else:
                raise ValueError('El grabador sigue cerrándose; no se inicia otra instancia')
            archivo.unlink(missing_ok=True)
        elif not dato and deseado:
            iniciar(archivo, carpeta / 'replay.log')
        print('Replay ' + ('encendido' if deseado else 'apagado') + ' · ' + preferencia)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
