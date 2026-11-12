#!/usr/bin/env python3
"""Actualizar Arch con red de seguridad. Lo abre actualizaciones.sh instalar (barra, lanzador, Brújula).

ANTES   batería suficiente o cargador · espacio libre · noticias de Arch sin leer (informant) ·
        aviso de lo delicado (kernel, Hyprland, Quickshell, Mesa…) · el snapshot lo hace snap-pac solo
DURANTE yay -Syu
DESPUÉS qué snapshots se hicieron (antes/después) · archivos .pacnew · servicios fallidos ·
        si hace falta reiniciar · lo apunta en ~/.local/state/brujula/actualizaciones.jsonl

    actualizar.py             el flujo completo (interactivo, en una terminal)
    actualizar.py deshacer    devolver / a como estaba antes de la ÚLTIMA actualización
                              (snapper undochange pre..post; pide confirmación y tu contraseña)
    actualizar.py historial   las últimas actualizaciones, en JSON
"""
import datetime as dt
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HOME = Path.home()
REGISTRO = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula/actualizaciones.jsonl"
DELICADOS = {
    "linux": "kernel: hará falta reiniciar", "linux-lts": "kernel LTS: hará falta reiniciar",
    "systemd": "systemd: conviene reiniciar", "glibc": "glibc: conviene reiniciar",
    "mesa": "gráficos (Mesa): reinicia la sesión", "hyprland": "Hyprland: cierra sesión y vuelve a entrar",
    "aquamarine": "Hyprland (Aquamarine): cierra sesión y vuelve a entrar", "quickshell": "Quickshell: se recarga solo; si algo falla, «qs» de nuevo",
    "linux-firmware": "firmware: reinicia", "grub": "GRUB: el instalador del sistema lo regenera", "nvidia": "drivers NVIDIA: reinicia",
}
V, A, R, G, N = "\033[32m", "\033[33m", "\033[31m", "\033[90m", "\033[0m"


def sh(args, timeout=30):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def paso(t):
    print(f"\n\033[1;33m── {t} ──{N}")


def ok(t):
    print(f"  {V}✓{N} {t}")


def mal(t):
    print(f"  {R}✗{N} {t}")


def aviso(t):
    print(f"  {A}!{N} {t}")


def preguntar(texto, defecto=True):
    try:
        r = input(f"  {texto} [{'S/n' if defecto else 's/N'}] ").strip().lower()
    except EOFError:
        return False
    return defecto if not r else r in ("s", "si", "sí", "y", "yes")


def snapshots_pacman():
    """[(pre, post, fecha, descripción)] de snap-pac, de más antiguo a más nuevo."""
    salida = sh(["snapper", "-c", "root", "--csvout", "list", "--columns", "number,type,pre-number,date,description"])
    pres, pares = {}, []
    for l in salida.splitlines()[1:]:
        partes = l.split(",", 4)
        if len(partes) < 5:
            continue
        num, tipo, pre, fecha, desc = partes
        if tipo == "pre":
            pres[num] = (fecha, desc)
        elif tipo == "post" and pre in pres:
            pares.append((int(pre), int(num), pres[pre][0], pres[pre][1]))
    return pares


def bateria():
    for b in Path("/sys/class/power_supply").glob("BAT*"):
        try:
            pct = int((b / "capacity").read_text())
            estado = (b / "status").read_text().strip()
        except (OSError, ValueError):
            continue
        cable = any((p / "online").read_text().strip() == "1" for p in Path("/sys/class/power_supply").glob("*")
                    if (p / "type").exists() and (p / "type").read_text().strip() == "Mains")
        return pct, cable or estado in ("Charging", "Full")
    return 100, True


def antes():
    paso("Antes de actualizar")
    pct, cable = bateria()
    if not cable and pct < 40:
        mal(f"Batería al {pct} % sin cargador. Una actualización cortada a medias puede dejar el sistema sin arrancar.")
        if not preguntar("¿Seguir de todas formas?", False):
            return None
    else:
        ok(f"Energía: {'con cargador' if cable else f'batería al {pct} %'}")
    libre = shutil.disk_usage("/").free / 2**30
    if libre < 5:
        mal(f"Solo {libre:.1f} GiB libres: limpia antes (paccache -r, yay -Sc).")
        return None
    ok(f"Espacio libre: {libre:.0f} GiB")

    if shutil.which("informant") and subprocess.run(["informant", "check"], capture_output=True).returncode != 0:
        aviso("Hay noticias de Arch sin leer. Pueden pedir pasos manuales ANTES de actualizar:")
        subprocess.run(["informant", "read", "--all"])
        if not preguntar("¿Las has leído y quieres continuar?"):
            return None
    else:
        ok("Noticias de Arch: nada nuevo")

    pendientes = sh(["checkupdates"], 90).splitlines() + sh(["yay", "-Qua"], 90).splitlines()
    nombres = [l.split()[0] for l in pendientes if l.strip()]
    if not nombres:
        ok("No hay nada que actualizar.")
        return None
    ok(f"{len(nombres)} paquetes por actualizar")
    delicados = [f"{n} → {DELICADOS[n]}" for n in nombres if n in DELICADOS]
    for d in delicados:
        aviso(d)
    if Path("/usr/bin/snapper").exists() and Path("/usr/share/libalpm/hooks/05-snap-pac-pre.hook").exists():
        ok("snap-pac hará un snapshot de / justo antes y otro justo después (salen en GRUB)")
    else:
        aviso("No encuentro snap-pac: no habrá snapshot automático.")
        if not preguntar("¿Continuar sin red de seguridad?", False):
            return None
    return {"nombres": nombres, "delicados": delicados, "pares_antes": {p[1] for p in snapshots_pacman()}}


def despues(info, codigo, inicio):
    paso("Después de actualizar")
    nuevos = [p for p in snapshots_pacman() if p[1] not in info["pares_antes"]]
    if nuevos:
        ok(f"Snapshots de esta actualización: #{nuevos[0][0]} (antes) … #{nuevos[-1][1]} (después)")
    else:
        aviso("No se creó ningún snapshot nuevo.")
    pacnew = [l for l in sh(["pacdiff", "-o"]).splitlines() if l.endswith((".pacnew", ".pacsave"))]
    if pacnew:
        aviso(f"{len(pacnew)} archivos de configuración nuevos (.pacnew): revísalos con «sudo pacdiff»")
        for f in pacnew[:6]:
            print(f"      {G}{f}{N}")
    else:
        ok("Sin archivos .pacnew")
    fallos = sh(["systemctl", "--failed", "--no-legend", "--plain"]).splitlines()
    (mal if fallos else ok)(f"{len(fallos)} servicios fallidos" if fallos else "Servicios: todos bien")
    reinicio = not Path("/usr/lib/modules", os.uname().release).exists() or any(
        n in info["nombres"] for n in ("linux", "linux-lts", "systemd", "glibc", "linux-firmware", "nvidia"))
    if reinicio:
        aviso("Reinicia cuando puedas para usar el sistema nuevo.")
    if codigo != 0:
        mal(f"yay terminó con error ({codigo}). Si algo no funciona: «actualizar.py deshacer» o elige el snapshot en GRUB.")
    REGISTRO.parent.mkdir(parents=True, exist_ok=True)
    with open(REGISTRO, "a") as f:
        f.write(json.dumps({"fecha": int(inicio), "segundos": int(time.time() - inicio), "paquetes": len(info["nombres"]),
                            "delicados": [d.split(" ")[0] for d in info["delicados"]], "codigo": codigo,
                            "pre": nuevos[0][0] if nuevos else None, "post": nuevos[-1][1] if nuevos else None,
                            "reinicio": reinicio, "pacnew": len(pacnew)}) + "\n")
    subprocess.run(["notify-send", "-a", "Actualizaciones", "-i", "system-software-update",
                    "Actualización terminada" if codigo == 0 else "La actualización tuvo errores",
                    f"{len(info['nombres'])} paquetes." + (" Reinicia cuando puedas." if reinicio else "")
                    + (f" {len(pacnew)} .pacnew por revisar." if pacnew else "")], capture_output=True)
    subprocess.run(["qs", "ipc", "call", "actualizaciones", "refrescar"], capture_output=True)


def deshacer():
    """Vuelve / a como estaba antes de la última actualización con snapper undochange."""
    pares = snapshots_pacman()
    registro = [json.loads(l) for l in REGISTRO.read_text().splitlines()] if REGISTRO.exists() else []
    ultima = next((r for r in reversed(registro) if r.get("pre") and r.get("post")), None)
    if ultima:
        pre, post = ultima["pre"], ultima["post"]
        cuando = dt.datetime.fromtimestamp(ultima["fecha"]).strftime("%d/%m %H:%M")
    elif pares:
        pre, post, cuando = pares[-1][0], pares[-1][1], pares[-1][2]
    else:
        print("No hay snapshots de pacman que deshacer.")
        return 1
    paso("Deshacer la última actualización")
    print(f"  Se devolverán los archivos de / a como estaban en el snapshot #{pre} (antes de la actualización del {cuando}).")
    print(f"  {G}Tu carpeta personal (/home) no se toca. Equivale a: sudo snapper -c root undochange {pre}..{post}{N}")
    print(f"  {G}Si el sistema ni siquiera arranca, usa en su lugar el menú de GRUB → «Arch Linux snapshots».{N}")
    print(f"\n  Archivos que cambiarían: {sh(['snapper', '-c', 'root', 'status', f'{pre}..{post}']).count(chr(10)) + 1}")
    try:
        r = input("\n  Escribe DESHACER (en mayúsculas) para confirmar: ").strip()
    except EOFError:
        r = ""
    if r != "DESHACER":
        print("  Cancelado. No se ha cambiado nada.")
        return 1
    codigo = subprocess.run(["sudo", "snapper", "-c", "root", "undochange", f"{pre}..{post}"]).returncode
    if codigo == 0:
        ok("Hecho. Reinicia para que todo use las versiones anteriores.")
    else:
        mal("snapper no pudo deshacer los cambios.")
    return codigo


def main():
    orden = sys.argv[1] if len(sys.argv) > 1 else "actualizar"
    if orden == "historial":
        lineas = REGISTRO.read_text().splitlines() if REGISTRO.exists() else []
        print(json.dumps([json.loads(l) for l in lineas[-10:]], ensure_ascii=False))
        return 0
    if orden == "deshacer":
        codigo = deshacer()
    else:
        info = antes()
        if info is None:
            codigo = 0
        else:
            paso("Actualizando (yay -Syu)")
            inicio = time.time()
            codigo = subprocess.run(["yay", "-Syu"]).returncode
            despues(info, codigo, inicio)
    try:
        input(f"\n{G}Enter para cerrar{N} ")
    except EOFError:
        pass
    return codigo


if __name__ == "__main__":
    sys.exit(main())
