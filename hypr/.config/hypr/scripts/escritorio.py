#!/usr/bin/env python3
"""Centro de escritorio: diagnóstico resumido y checkpoints por instancia, sin títulos ni comandos de apps."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def ejecutar(args, timeout=5):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=True).stdout.strip()


def directorio():
    firma = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not runtime or not re.fullmatch(r"[\w-]+", firma):
        raise ValueError("No hay una instancia gráfica válida en este entorno")
    return Path(runtime), firma


def estado():
    runtime, firma = directorio()
    try:
        lineas = (runtime / f"hypr-escritorio-{firma}.state").read_text().splitlines()
    except FileNotFoundError:
        return {}
    return dict(l.split("=", 1) for l in lineas if "=" in l)


def atomico(ruta, datos):
    fd, nombre = tempfile.mkstemp(dir=ruta.parent, prefix=".escritorio-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(datos, f, ensure_ascii=False)
        os.replace(nombre, ruta)
    finally:
        if os.path.exists(nombre):
            os.unlink(nombre)


def espacio_id(w):
    """Id del workspace de una ventana de `hyprctl clients`. Hyprland 0.57 no incluye "id" en los
    espacios especiales (scratchpads): se tratan como -1, igual que antes."""
    return (w.get("workspace") or {}).get("id", -1)


def captura():
    _, firma = directorio()
    ventanas = json.loads(ejecutar(["hyprctl", "-j", "clients"]))
    return {"version": 1, "instancia": firma, "fecha": int(time.time()), "ventanas": [
        {"address": w["address"], "pid": w["pid"], "class": w["class"], "workspace": espacio_id(w)}
        for w in ventanas if w.get("mapped", True) and espacio_id(w) > 0
    ]}


def plan_restauracion(guardado, actual, firma):
    if guardado.get("version") != 1 or guardado.get("instancia") != firma:
        raise ValueError("El checkpoint pertenece a otra sesión o versión")
    actuales = {w["address"]: w for w in actual["ventanas"]}
    acciones = []
    omitidas = 0
    for w in guardado["ventanas"]:
        ahora = actuales.get(w.get("address"))
        # Evita reutilización de direcciones y mover otra app. No evalúa texto del checkpoint como Lua.
        if not ahora or (ahora["pid"], ahora["class"]) != (w.get("pid"), w.get("class")):
            omitidas += 1
            continue
        if not isinstance(w.get("workspace"), int) or isinstance(w["workspace"], bool) or w["workspace"] < 1:
            raise ValueError("Workspace inválido en checkpoint")
        if not re.fullmatch(r"0x[0-9a-fA-F]+", w["address"]):
            raise ValueError("Dirección de ventana inválida")
        if ahora["workspace"] != w["workspace"]:
            acciones.append(w)
    return acciones, omitidas


def checkpoint(accion):
    runtime, firma = directorio()
    carpeta = runtime / f"hypr-checkpoints-{firma}"
    carpeta.mkdir(mode=0o700, exist_ok=True)
    with (carpeta / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        ruta = carpeta / "actual.json"
        undo = carpeta / "deshacer.json"
        actual = captura()
        if accion == "guardar":
            atomico(ruta, actual)
            return f"Checkpoint guardado: {len(actual['ventanas'])} ventanas"
        fuente = undo if accion == "deshacer" else ruta
        if not fuente.exists():
            raise ValueError("No hay checkpoint" if accion != "deshacer" else "No hay restauración que deshacer")
        plan, omitidas = plan_restauracion(json.loads(fuente.read_text()), actual, firma)
        # Registrar antes de mover: también permite recuperar una restauración parcialmente fallida.
        atomico(undo, actual)
        for w in plan:
            ejecutar(["hyprctl", "dispatch", 'hl.dsp.window.move({window="address:' + w["address"] +
                      '",workspace=' + str(w["workspace"]) + ',follow=false})'])
        return f"{len(plan)} ventanas movidas · {omitidas} cerradas o no disponibles"


def diagnostico():
    e = estado()
    filas = ["ESTADO DEL ESCRITORIO", f"Perfil: {e.get('perfil', 'sin coordinador')}"]
    motivos = [k for k in ("bateria", "presentacion", "concentracion", "privacidad", "juego_activo") if e.get(k) == "true"]
    filas.append("Motivos activos: " + (", ".join(motivos) or "ninguno"))
    comprobaciones = [
        ("Configuración Hyprland", ["hyprctl", "configerrors"], lambda x: x or "sin errores"),
        ("Unidades fallidas del sistema", ["systemctl", "--failed", "--no-legend", "--no-pager"], lambda x: str(len(x.splitlines()))),
        ("Unidades fallidas del usuario", ["systemctl", "--user", "--failed", "--no-legend", "--no-pager"], lambda x: str(len(x.splitlines()))),
        ("Perfil de energía", ["powerprofilesctl", "get"], str),
        ("Replay", [str(Path(__file__).with_name("replay.sh")), "estado"], str),
        ("Estado del bloqueo", ["qs", "ipc", "call", "bloqueo", "estado"], str),
    ]
    for nombre, cmd, formatear in comprobaciones:
        try:
            filas.append(nombre + ": " + formatear(ejecutar(cmd, timeout=3)))
        except (OSError, subprocess.SubprocessError):
            filas.append(nombre + ": no disponible")
    try:
        monitores = json.loads(ejecutar(["hyprctl", "-j", "monitors"]))
        filas.append("Pantallas: " + " · ".join(f"{m['width']}×{m['height']} / {m['scale']}×" for m in monitores))
    except (OSError, ValueError, subprocess.SubprocessError):
        filas.append("Pantallas: no disponible")
    filas.append("Diagnóstico sin títulos de ventanas, SSID, IP ni registros completos.")
    return "\n".join(filas)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="accion", required=True)
    sub.add_parser("menu")
    sub.add_parser("estado")
    sub.add_parser("diagnostico")
    perf = sub.add_parser("perfil")
    perf.add_argument("nombre", choices=["cristal", "lectura", "minimo", "rendimiento"])
    sub.add_parser("privacidad")
    rp = sub.add_parser("replay")
    rp.add_argument("modo", choices=["auto", "start", "stop", "save", "estado"])
    j = sub.add_parser("juego")
    j.add_argument("modo", choices=["automatico", "si", "no"])
    cp = sub.add_parser("checkpoint")
    cp.add_argument("operacion", choices=["guardar", "restaurar", "deshacer"])
    a = p.parse_args()
    if a.accion == "menu":
        ejecutar(["qs", "ipc", "call", "centroEscritorio", "toggle"])
    elif a.accion == "estado":
        print(json.dumps(estado(), ensure_ascii=False, indent=2))
    elif a.accion == "diagnostico":
        print(diagnostico())
    elif a.accion == "replay":
        print(ejecutar([str(Path(__file__).with_name("replay.sh")), a.modo], timeout=10) or "Replay guardado")
    elif a.accion == "checkpoint":
        print(checkpoint(a.operacion))
    else:
        expresion = "escritorio.privacidad()" if a.accion == "privacidad" else (
            f'escritorio.perfil("{a.nombre}")' if a.accion == "perfil" else f'escritorio.juego("{a.modo}")')
        ejecutar(["hyprctl", "dispatch", expresion + " or hl.dsp.no_op()"])
        print("Perfil aplicado: " + a.nombre if a.accion == "perfil" else
              "Juego: " + a.modo if a.accion == "juego" else "Privacidad actualizada")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        print("No se pudo completar la acción: " + str(exc), file=sys.stderr)
        sys.exit(1)
