#!/usr/bin/python3
"""Tiempo de pantalla por app: escucha los EVENTOS de Hyprland y suma segundos por ventana.

Cómo funciona
  Hyprland publica todo lo que pasa en un socket Unix:
      $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock
  Cada evento es una línea "nombre>>datos". Aquí solo interesa:
      activewindow>>kitty,título de la ventana      (cambió el foco o el título)
  Cuando llega, se apunta el tiempo transcurrido a la app ANTERIOR y se empieza a contar la nueva.
  Mientras hyprlock está activo no se cuenta nada.

Datos: ~/.local/state/tiempo-pantalla/AAAA-MM-DD.json  →  {"firefox": 5321.0, "kitty": 1200.5, …}
       (los lee el dashboard de Quickshell, SUPER+D)

Uso
  tiempo-pantalla.py          demonio (lo arranca modulos/autostart.lua)
  tiempo-pantalla.py --hoy    resumen de hoy en la terminal
"""
import datetime as dt
import fcntl
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

DATOS = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "tiempo-pantalla"
TICK = 5          # segundos entre comprobaciones (bloqueo, cambio de día)
GUARDAR_CADA = 30  # segundos entre escrituras a disco


def archivo(dia: dt.date) -> Path:
    return DATOS / f"{dia.isoformat()}.json"


def leer(dia: dt.date) -> dict:
    try:
        return json.loads(archivo(dia).read_text())
    except (OSError, ValueError):
        return {}


def guardar(dia: dt.date, tiempos: dict) -> None:
    DATOS.mkdir(parents=True, exist_ok=True)
    tmp = archivo(dia).with_suffix(".tmp")
    tmp.write_text(json.dumps(tiempos, indent=1, sort_keys=True))
    tmp.replace(archivo(dia))  # renombrar es atómico: nadie lee un archivo a medio escribir


def bloqueado() -> bool:
    """¿Está hyprlock en marcha? (se mira en /proc, sin lanzar procesos)"""
    for p in Path("/proc").iterdir():
        if p.name.isdigit():
            try:
                if (p / "comm").read_text().strip() == "hyprlock":
                    return True
            except OSError:
                pass
    return False


def ventana_activa() -> str:
    try:
        salida = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True).stdout
        return json.loads(salida).get("class", "") or ""
    except (OSError, ValueError):
        return ""


def formato(seg: float) -> str:
    h, m = divmod(int(seg) // 60, 60)
    return f"{h} h {m:02d} min" if h else f"{m} min"


def resumen() -> None:
    tiempos = leer(dt.date.today())
    if not tiempos:
        print("Hoy aún no hay datos.")
        return
    total = sum(tiempos.values())
    print(f"Hoy en pantalla: {formato(total)}\n")
    for app, seg in sorted(tiempos.items(), key=lambda x: -x[1]):
        barra = "█" * max(1, round(20 * seg / total))
        print(f"  {app[:28]:<28} {formato(seg):>11}  {barra}")


def demonio() -> None:
    # Una sola instancia: si ya hay otra corriendo, salir sin hacer nada
    candado = open(Path(os.environ["XDG_RUNTIME_DIR"]) / "tiempo-pantalla.lock", "w")
    try:
        fcntl.flock(candado, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)

    ruta = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr" / os.environ["HYPRLAND_INSTANCE_SIGNATURE"] / ".socket2.sock"
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(str(ruta))
    sock.settimeout(TICK)

    dia = dt.date.today()
    tiempos = leer(dia)
    actual = ventana_activa()
    marca = time.monotonic()      # reloj que no salta si cambias la hora del sistema
    guardado = marca
    resto = b""

    def apuntar():
        """Suma a la app actual el tiempo desde la última marca."""
        nonlocal marca
        ahora = time.monotonic()
        if actual and not bloqueado():
            tiempos[actual] = round(tiempos.get(actual, 0) + (ahora - marca), 1)
        marca = ahora

    while True:
        try:
            datos = sock.recv(4096)
            if not datos:                      # Hyprland se cerró: guardar y salir
                apuntar(); guardar(dia, tiempos)
                return
            resto += datos
            *lineas, resto = resto.split(b"\n")
            for linea in lineas:
                evento, _, valor = linea.decode(errors="replace").partition(">>")
                if evento == "activewindow":
                    clase = valor.split(",", 1)[0]
                    if clase != actual:
                        apuntar()
                        actual = clase
        except socket.timeout:
            pass                               # nada nuevo: es solo el "tick"

        apuntar()
        if dt.date.today() != dia:             # pasó la medianoche: cerrar el día y empezar otro
            guardar(dia, tiempos)
            dia, tiempos = dt.date.today(), {}
        if time.monotonic() - guardado >= GUARDAR_CADA:
            guardar(dia, tiempos)
            guardado = time.monotonic()


if __name__ == "__main__":
    resumen() if "--hoy" in sys.argv else demonio()
