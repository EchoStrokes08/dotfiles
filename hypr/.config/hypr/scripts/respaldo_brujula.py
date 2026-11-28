#!/usr/bin/env python3
"""Conecta el disco configurado y lanza la copia manual desde el escritorio."""
import json
from pathlib import Path
import shlex
import subprocess
import sys


CONFIG = Path("/etc/respaldo/config")
RESPALDO = Path("/usr/local/bin/respaldo")


def comando_terminal():
    return ["kitty", "--class", "kitty-salud", "--hold", "-e", sys.executable, str(Path(__file__).resolve())]


def uuid_configurado():
    for linea in CONFIG.read_text().splitlines():
        clave, _, valor = linea.partition("=")
        if clave.strip() == "UUID":
            tokens = shlex.split(valor, comments=True)
            if len(tokens) == 1:
                return tokens[0]
    raise ValueError("Falta el UUID en /etc/respaldo/config.")


def disco(uuid):
    datos = subprocess.check_output(
        ["lsblk", "--json", "--list", "--paths", "-o", "PATH,UUID,FSTYPE,MOUNTPOINTS"],
        text=True, timeout=5,
    )
    return next((d for d in json.loads(datos)["blockdevices"]
                 if (d.get("uuid") or "").casefold() == uuid.casefold()), None)


def puntos_montaje(dispositivo):
    return [ruta for ruta in dispositivo.get("mountpoints") or [] if ruta]


def copiar():
    if not RESPALDO.is_file():
        print("Falta instalar el servicio de respaldo del sistema.")
        return 1

    uuid = uuid_configurado()
    dispositivo = disco(uuid)
    if dispositivo is None:
        print(f"Conecta el disco de respaldo (UUID {uuid}) y vuelve a pulsar «Copiar ahora».")
        return 1

    puntos = puntos_montaje(dispositivo)
    if not puntos:
        print(f"Montando el disco de respaldo ({dispositivo['path']})…", flush=True)
        montaje = subprocess.run(["udisksctl", "mount", "-b", dispositivo["path"]])
        # Udiskie también puede haberlo montado mientras se ejecutaba udisksctl.
        puntos = puntos_montaje(disco(uuid) or {})
        if not puntos:
            print("El disco sigue sin montarse. La copia no pudo iniciar.")
            if dispositivo.get("fstype") == "ntfs" and montaje.returncode:
                print("Si el volumen NTFS figura como pendiente de comprobación, revísalo en Windows con chkdsk.")
            return 1

    opciones = subprocess.check_output(
        ["findmnt", "-fno", "OPTIONS", "--mountpoint", puntos[0]], text=True, timeout=5,
    )
    if "ro" in opciones.strip().split(","):
        print("El disco está montado en solo lectura. Hace falta montarlo con escritura para crear la copia.")
        return 1

    return subprocess.run([str(RESPALDO), "ahora"]).returncode


if __name__ == "__main__":
    try:
        sys.exit(copiar())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"No se pudo iniciar la copia de seguridad: {error}")
