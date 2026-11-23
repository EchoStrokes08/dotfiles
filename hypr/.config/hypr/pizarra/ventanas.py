"""Selecciona ventanas de Hyprland por identidad de proceso y sesión."""
import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import brujula
import mesa


def hypr(consulta):
    return json.loads(subprocess.check_output(["hyprctl", "-j", consulta], timeout=3))


def identidad(w):
    return {k: w.get(k) for k in ("address", "pid", "class", "title")} | {
        "sesion": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")}


def coincide(w, ref):
    return all(identidad(w)[k] == ref.get(k) for k in ("address", "pid", "class", "sesion"))


def main():
    accion = sys.argv[1]
    if accion == "origen":
        return identidad(hypr("activewindow"))
    if accion == "traer":
        pid = json.load(sys.stdin)["pid"]
        existente = next((w for w in hypr("clients") if w.get("pid") == pid and
                          w.get("class") == "orion-pizarra"), None)
        if existente:
            mesa.ventana("enfocar", existente["address"])
        return bool(existente)
    ventanas = [w for w in hypr("clients") if w.get("mapped") and w.get("class") != "orion-pizarra"]
    if accion == "lista":
        return [identidad(w) | {"nombre": brujula.nombre_de(w["class"])} for w in ventanas]
    ref = json.load(sys.stdin)
    vivo = next((w for w in ventanas if coincide(w, ref)), None)
    if vivo:
        mesa.ventana("enfocar", vivo["address"])
        return "enfocada"
    if accion == "volver":
        return "cerrada"
    app = brujula.app_de(ref.get("class", ""))
    if not app:
        raise ValueError("No hay una aplicación instalada asociada a esta ventana.")
    if accion == "activar":
        return "ofrecer"
    if accion == "abrir":
        subprocess.Popen(["gtk-launch", app["id"]], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return "abierta"
    raise ValueError("Acción desconocida.")


if __name__ == "__main__":
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, ValueError, subprocess.SubprocessError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
