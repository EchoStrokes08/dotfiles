#!/usr/bin/env python3
"""Estados y órdenes confirmadas del centro de control. Sin dependencias externas."""
import concurrent.futures
import glob
import json
import os
from pathlib import Path
import subprocess
import sys
import time

COSAS = ("wifi", "bluetooth", "replay", "rendimiento", "conservacion", "luz")
SCRIPTS = Path(__file__).resolve().parent
CONSERVACION = "/sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode"


def ejecutar(*args):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=4,
                           env={**os.environ, "LC_ALL": "C"})
    except FileNotFoundError:
        raise RuntimeError(f"Falta el programa {Path(args[0]).name}.") from None
    except subprocess.TimeoutExpired:
        raise RuntimeError("El servicio no respondió a tiempo.") from None
    if r.returncode:
        raise RuntimeError((r.stderr.strip() or r.stdout.strip() or "El servicio no está disponible.")[:300])
    return r.stdout.strip()


def archivo_conservacion():
    rutas = glob.glob(CONSERVACION)
    if not rutas:
        raise RuntimeError("Este equipo no ofrece conservación de batería.")
    return Path(rutas[0])


def leer(cosa):
    try:
        extra = {}
        if cosa == "wifi":
            if "wifi" not in ejecutar("nmcli", "-t", "-f", "TYPE", "device").splitlines():
                raise RuntimeError("No hay adaptador Wi-Fi disponible.")
            activo = ejecutar("nmcli", "radio", "wifi") == "enabled"
        elif cosa == "bluetooth":
            salida = ejecutar("bluetoothctl", "show")
            if "Powered:" not in salida:
                raise RuntimeError("No hay adaptador Bluetooth disponible.")
            activo = "Powered: yes" in salida
        elif cosa == "replay":
            detalle = json.loads(ejecutar("python3", str(SCRIPTS / "replay.py"), "detalle"))
            activo = detalle["grabando"]
            etiqueta = "Grabando" if activo else "Pausado" if "pausado" in detalle["texto"].lower() else "Automático" if detalle["politica"] == "auto" else "Desactivado"
            extra = {"etiqueta": etiqueta, "detalle": detalle["texto"]}
        elif cosa == "rendimiento":
            if "performance:" not in ejecutar("powerprofilesctl", "list"):
                raise RuntimeError("El equipo no ofrece energía de alto rendimiento.")
            activo = ejecutar("powerprofilesctl", "get") == "performance"
        elif cosa == "conservacion":
            archivo = archivo_conservacion()
            if not os.access(archivo, os.W_OK):
                raise RuntimeError("No hay permiso para cambiar la conservación de batería.")
            activo = archivo.read_text().strip() == "1"
        elif cosa == "luz":
            salida = ejecutar("hyprctl", "hyprsunset", "temperature")
            if not salida.isdigit():
                raise RuntimeError("La luz nocturna no está disponible; comprueba hyprsunset.")
            activo = int(salida) < 6000
        else:
            raise RuntimeError("Control desconocido.")
        return {"disponible": True, "activo": activo, "error": "", **extra}
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as e:
        return {"disponible": False, "activo": None, "error": str(e)}


def todos():
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(COSAS)) as pool:
        return dict(zip(COSAS, pool.map(leer, COSAS)))


def cambiar(cosa, activo):
    previo = leer(cosa)
    if not previo["disponible"]:
        return {"ok": False, "estado": previo, "error": previo["error"]}
    try:
        if previo["activo"] != activo:
            valor = "on" if activo else "off"
            if cosa == "wifi":
                ejecutar("nmcli", "radio", "wifi", valor)
            elif cosa == "bluetooth":
                ejecutar("bluetoothctl", "power", valor)
            elif cosa == "replay":
                ejecutar(str(SCRIPTS / "replay.sh"), "start" if activo else "stop")
            elif cosa == "rendimiento":
                ejecutar("powerprofilesctl", "set", "performance" if activo else "balanced")
            elif cosa == "conservacion":
                archivo_conservacion().write_text("1\n" if activo else "0\n")
            elif cosa == "luz":
                if activo:
                    ejecutar("hyprctl", "hyprsunset", "temperature", "4500")
                else:
                    ejecutar("hyprctl", "hyprsunset", "identity")
        # Espera acotada para radios que aceptan la orden antes de publicar su estado.
        for intento in range(5):
            actual = leer(cosa)
            if actual["disponible"] and actual["activo"] == activo:
                return {"ok": True, "estado": actual, "error": ""}
            if not actual["disponible"]:
                break
            if intento < 4:
                time.sleep(0.2)
        raise RuntimeError(actual["error"] or "El servicio no confirmó el cambio. Puede haber una política activa.")
    except (RuntimeError, OSError) as e:
        return {"ok": False, "estado": leer(cosa), "error": str(e)}


def main(args=None):
    args = sys.argv[1:] if args is None else args
    if args == ["json"]:
        print(json.dumps(todos(), ensure_ascii=False))
        return 0
    if args == ["todos"]:
        for cosa, dato in todos().items():
            print(cosa, "on" if dato["activo"] else "off" if dato["disponible"] else "unavailable")
        return 0
    if len(args) == 2 and args[0] in COSAS and args[1] == "estado":
        dato = leer(args[0])
        print("on" if dato["activo"] else "off" if dato["disponible"] else "unavailable")
        return 0 if dato["disponible"] else 1
    if len(args) == 2 and args[0] in COSAS and args[1] in ("on", "off"):
        dato = cambiar(args[0], args[1] == "on")
        print(json.dumps(dato, ensure_ascii=False))
        return 0 if dato["ok"] else 1
    print("uso: conmutadores.sh json|todos|<control> estado|on|off", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
