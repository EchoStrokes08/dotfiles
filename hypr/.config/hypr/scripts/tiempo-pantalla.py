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

Límites: ~/.config/tiempo-pantalla/limites.json  →  {"org.vinegarhq.Sober": 60, "vesktop": 60}
       (minutos al día por class de ventana; SUPER+I dice la class). Al llegar al límite avisa,
       y otra vez cada 30 min de más. Se lee en cada aviso: los cambios valen sin reiniciar nada.

Uso
  tiempo-pantalla.py          demonio (lo arranca modulos/autostart.lua)
  tiempo-pantalla.py --hoy    resumen de hoy en la terminal
  tiempo-pantalla.py --semana JSON con los últimos 7 días (lo usa el dashboard para el gráfico)
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
LIMITES = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "tiempo-pantalla" / "limites.json"
REPETIR = 30 * 60  # tras pasar el límite, avisar de nuevo cada 30 min


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
    """¿Está la pantalla bloqueada? Con la de Quickshell (qs ipc call bloqueo estado) o con hyprlock."""
    try:
        r = subprocess.run(["qs", "ipc", "call", "bloqueo", "estado"], capture_output=True, text=True, timeout=2)
        if r.stdout.strip() in ("bloqueado", "bloqueando"):
            return True
    except (OSError, subprocess.TimeoutExpired):
        pass
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


def nombre_bonito(clase: str) -> str:
    return {"org.vinegarhq.Sober": "Roblox", "com.rtosta.zapzap": "WhatsApp", "vesktop": "Discord"}.get(
        clase, clase.split(".")[-1].capitalize())


def revisar_limites(tiempos: dict, avisos: dict) -> None:
    """Avisa al llegar al límite de una app y luego cada REPETIR segundos de más."""
    try:
        limites = json.loads(LIMITES.read_text())
    except (OSError, ValueError):
        return
    for clase, minutos in limites.items():
        usado, limite = tiempos.get(clase, 0), float(minutos) * 60
        if usado >= limite and usado >= avisos.get(clase, limite):
            avisos[clase] = usado + REPETIR
            extra = f" (+{formato(usado - limite)} de más)" if usado - limite >= 60 else ""
            subprocess.Popen(["notify-send", "-u", "critical", "-a", "Tiempo de pantalla", "-i", "appointment-soon",
                              f"Llevas {formato(usado)} en {nombre_bonito(clase)} hoy",
                              f"Tu límite es {formato(limite)}{extra}. ¿Un descanso?"])


def semana() -> None:
    """Últimos 7 días (de más viejo a hoy): total y app principal, en JSON."""
    hoy = dt.date.today()
    res = []
    for i in range(6, -1, -1):
        d = hoy - dt.timedelta(days=i)
        t = leer(d)
        top = max(t.items(), key=lambda x: x[1])[0] if t else ""
        res.append({"dia": d.isoformat(), "total": round(sum(t.values())), "top": nombre_bonito(top) if top else ""})
    print(json.dumps(res, ensure_ascii=False))


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
    avisos = {}                   # clase → a partir de qué segundos volver a avisar (hoy)

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
        revisar_limites(tiempos, avisos)
        if dt.date.today() != dia:             # pasó la medianoche: cerrar el día y empezar otro
            guardar(dia, tiempos)
            dia, tiempos, avisos = dt.date.today(), {}, {}
        if time.monotonic() - guardado >= GUARDAR_CADA:
            guardar(dia, tiempos)
            guardado = time.monotonic()


if __name__ == "__main__":
    if "--hoy" in sys.argv:
        resumen()
    elif "--semana" in sys.argv:
        semana()
    else:
        demonio()
