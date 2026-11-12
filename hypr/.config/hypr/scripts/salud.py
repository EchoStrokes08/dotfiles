#!/usr/bin/env python3
"""Salud del sistema de un vistazo (pestaña «Salud» de Brújula). Todo sin contraseña de administrador.

    salud.py            JSON: {"estado": ok|aviso|mal, "comprobaciones": [...]}
    salud.py resumen    una línea: «2 avisos: respaldo, USB»

Cada comprobación: id, nombre, estado (ok · aviso · mal · info), valor (corto), detalle y una acción
opcional {texto, cmd}. Fuentes: UDisks (SMART del NVMe), lm_sensors, /sys (batería), df, systemd,
snapper, el registro del kernel de este arranque, Hyprland y la caché de Actualizaciones.qml.
"""
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

HOME = Path.home()
SCRIPTS = Path(__file__).resolve().parent
ORDEN = {"mal": 0, "aviso": 1, "info": 2, "ok": 3}


def sh(args, timeout=6):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def hace(segundos):
    s = int(segundos)
    if s < 3600:
        return f"hace {max(1, s // 60)} min"
    if s < 86400:
        return f"hace {s // 3600} h"
    d = s // 86400
    return "hace 1 día" if d == 1 else f"hace {d} días"


def c(ident, nombre, estado, valor, detalle, accion=None, glifo="f05e0"):
    return {"id": ident, "nombre": nombre, "estado": estado, "valor": valor, "detalle": detalle,
            "accion": accion, "glifo": glifo}


def terminal(orden):
    return ["kitty", "--class", "kitty-salud", "-e", "sh", "-c", orden + "; echo; read -rp 'Enter para cerrar ' _"]


# ── comprobaciones ───────────────────────────────────────────────────────
def respaldo():
    try:
        ultima = int(Path("/var/lib/respaldo/ultima").read_text().strip() or 0)
    except (OSError, ValueError):
        ultima = 0
    accion = {"texto": "Copiar ahora", "cmd": terminal("respaldo ahora")}
    if not ultima:
        return c("respaldo", "Copia de seguridad", "mal", "nunca", "No hay registro de ninguna copia. Conecta el disco TOSHIBA.", accion, "f0e26")
    edad = time.time() - ultima
    estado = "ok" if edad < 3 * 86400 else "aviso" if edad < 8 * 86400 else "mal"
    return c("respaldo", "Copia de seguridad", estado, hace(edad),
             "Al día." if estado == "ok" else "Conecta el disco TOSHIBA: la copia empieza sola.", accion, "f0e26")


def disco():
    raiz = "/org/freedesktop/UDisks2/drives"
    arbol = sh(["busctl", "--system", "tree", "--list", "org.freedesktop.UDisks2"])
    for ruta in [l for l in arbol.splitlines() if l.startswith(raiz + "/")]:
        crudo = sh(["busctl", "--system", "--json=short", "call", "org.freedesktop.UDisks2", ruta,
                    "org.freedesktop.UDisks2.NVMe.Controller", "SmartGetAttributes", "a{sv}", "0"])
        if not crudo:
            continue
        try:
            a = {k: v["data"] for k, v in json.loads(crudo)["data"][0].items()}
            props = json.loads(sh(["busctl", "--system", "--json=short", "call", "org.freedesktop.UDisks2", ruta,
                                   "org.freedesktop.DBus.Properties", "GetAll", "s", "org.freedesktop.UDisks2.NVMe.Controller"]))["data"][0]
        except (ValueError, KeyError, IndexError):
            continue
        avisos = props.get("SmartCriticalWarning", {}).get("data", [])
        usado, reserva, errores = a.get("percent_used", 0), a.get("avail_spare", 100), a.get("media_errors", 0)
        temp = (props.get("SmartTemperature", {}).get("data", 0) or 0) - 273
        horas = props.get("SmartPowerOnHours", {}).get("data", 0)
        estado = "mal" if avisos or errores or reserva <= a.get("spare_thresh", 10) else "aviso" if usado >= 80 else "ok"
        detalle = (f"Desgaste {usado} % · reserva {reserva} % · {errores} errores de lectura · {temp} °C · {horas} h encendido"
                   + (" · AVISO del disco: " + ", ".join(avisos) if avisos else ""))
        return c("disco", "Disco (SMART)", estado, f"{100 - usado} % de vida", detalle, glifo="f02ca")
    return c("disco", "Disco (SMART)", "info", "—", "No se pudo leer el SMART por UDisks.", glifo="f02ca")


def espacio():
    total, usado, libre = shutil.disk_usage("/")
    pct = usado * 100 // total
    estado = "ok" if pct < 85 else "aviso" if pct < 95 else "mal"
    accion = {"texto": "Ver qué ocupa", "cmd": ["kitty", "--class", "kitty-salud", "-e", "sh", "-c", "command -v gdu >/dev/null && gdu ~ || du -xh --max-depth=1 ~ | sort -h; read -r _"]}
    return c("espacio", "Espacio libre", estado, f"{libre / 2**30:.0f} GiB libres",
             f"{pct} % usado de {total / 2**30:.0f} GiB (Btrfs comprimido: el uso real es menor).", accion, "f02ca")


def scrub():
    salida = sh(["systemctl", "show", "btrfs-scrub@-.service", "-p", "Result", "-p", "ExecMainExitTimestamp"]) + "\n" + \
        sh(["systemctl", "show", "btrfs-scrub@-.timer", "-p", "LastTriggerUSec"])
    p = dict(l.split("=", 1) for l in salida.splitlines() if "=" in l)
    # el temporizador recuerda la última vez aunque hayas reiniciado; el servicio solo dentro de este arranque
    cuando = p.get("ExecMainExitTimestamp") or p.get("LastTriggerUSec", "")
    try:
        t = dt.datetime.strptime(" ".join(cuando.split()[1:3]), "%Y-%m-%d %H:%M:%S").timestamp()
    except ValueError:
        return c("scrub", "Comprobación Btrfs (scrub)", "info", "pendiente", "Aún no se ha ejecutado: el temporizador lo hará solo.", glifo="f0cfa")
    edad = time.time() - t
    estado = "mal" if p.get("Result") != "success" else "ok" if edad < 40 * 86400 else "aviso"
    return c("scrub", "Comprobación Btrfs (scrub)", estado, hace(edad),
             "Sin errores en la última comprobación de datos." if estado == "ok" else f"Resultado: {p.get('Result')}. Revisa: journalctl -u btrfs-scrub@-.service",
             glifo="f0cfa")


def snapshots():
    salida = sh(["snapper", "-c", "root", "--csvout", "list", "--columns", "number,type,pre-number,date,description"], 10)
    filas = [l.split(",", 4) for l in salida.splitlines()[1:] if l.count(",") >= 4]
    if not filas:
        return c("snapshots", "Snapshots", "info", "—", "No se pudo leer snapper.", glifo="f0bd9")

    def fecha(f):
        try:
            return dt.datetime.fromisoformat(f.strip()).timestamp()
        except ValueError:
            return 0
    ultimo = max(fecha(f[3]) for f in filas)
    pre = [f for f in filas if f[1] == "pre"]
    edad = time.time() - ultimo
    estado = "ok" if edad < 3 * 3600 else "aviso" if edad < 2 * 86400 else "mal"
    detalle = f"{len(filas)} snapshots de /. "
    if pre:
        p = pre[-1]
        detalle += f"Antes de la última instalación: #{p[0]} ({dt.datetime.fromtimestamp(fecha(p[3])):%d/%m %H:%M}). Se ven en GRUB."
    return c("snapshots", "Snapshots", estado, hace(edad), detalle, glifo="f0bd9")


def temperatura():
    try:
        d = json.loads(sh(["sensors", "-j"]) or "{}")
    except ValueError:
        d = {}
    valores = []
    for chip, datos in d.items():
        if not chip.startswith(("k10temp", "amdgpu", "coretemp", "nvme")):
            continue
        for sensor in datos.values():
            if isinstance(sensor, dict):
                valores += [v for k, v in sensor.items() if k.endswith("_input") and k.startswith("temp") and isinstance(v, (int, float))]
    if not valores:
        return c("temperatura", "Temperatura", "info", "—", "Sin sensores legibles.", glifo="f050f")
    t = max(valores)
    estado = "ok" if t < 80 else "aviso" if t < 92 else "mal"
    return c("temperatura", "Temperatura", estado, f"{t:.0f} °C",
             "Normal." if estado == "ok" else "Caliente: revisa qué consume (btop) y que las rejillas no estén tapadas.",
             {"texto": "Abrir btop", "cmd": ["kitty", "--class", "kitty-salud", "-e", "btop"]}, "f050f")


def bateria():
    for b in Path("/sys/class/power_supply").glob("BAT*"):
        try:
            leer = lambda n: int((b / n).read_text())
            lleno = leer("energy_full") if (b / "energy_full").exists() else leer("charge_full")
            diseno = leer("energy_full_design") if (b / "energy_full_design").exists() else leer("charge_full_design")
            ciclos = leer("cycle_count") if (b / "cycle_count").exists() else -1
        except (OSError, ValueError):
            continue
        salud = lleno * 100 // max(1, diseno)
        estado = "ok" if salud >= 80 else "aviso" if salud >= 60 else "mal"
        limite = (b / "charge_types").read_text().strip() if (b / "charge_types").exists() else ""
        larga = "[Long_Life]" in limite
        return c("bateria", "Batería", estado, f"{salud} % de su capacidad",
                 f"{ciclos} ciclos." + (" Modo de conservación activo: carga hasta ~80 % para durar más." if larga
                                        else " Activa el modo de conservación en la barra para alargar su vida."), glifo="f0079")
    return c("bateria", "Batería", "info", "—", "Sin batería.", glifo="f0079")


def usb():
    n = len(re.findall(r"error -71", sh(["journalctl", "-k", "-b", "--no-pager", "-o", "cat"], 10)))
    estado = "ok" if n == 0 else "aviso"
    return c("usb", "USB", estado, f"{n} errores" if n else "sin errores",
             "Errores de comunicación USB (-71) en este arranque: suele ser un cable, puerto o hub. Prueba cambiando uno cada vez."
             if n else "Ningún error USB en este arranque.", glifo="f0553")


def servicios():
    sistema = [l.split()[0] for l in sh(["systemctl", "--failed", "--no-legend", "--plain"]).splitlines() if l.strip()]
    usuario = [l.split()[0] for l in sh(["systemctl", "--user", "--failed", "--no-legend", "--plain"]).splitlines() if l.strip()]
    fallos = sistema + usuario
    return c("servicios", "Servicios", "mal" if fallos else "ok", f"{len(fallos)} fallidos" if fallos else "todos bien",
             ("Fallidos: " + ", ".join(fallos[:5])) if fallos else "Ninguna unidad de systemd ha fallado.",
             {"texto": "Ver por qué", "cmd": terminal("systemctl --failed; systemctl --user --failed; journalctl -p err -b --no-pager | tail -30")} if fallos else None,
             "f0493")


def actualizaciones():
    texto = sh(["qs", "ipc", "call", "actualizaciones", "estado"], 3)
    d = dict(x.split("=", 1) for x in texto.split() if "=" in x)
    try:
        aur, noticias, vuln = (int(d.get(k, 0)) for k in ("aur", "noticias", "vulnerables"))
    except ValueError:
        aur = noticias = vuln = 0
    # los repos, de la copia de checkupdates (sin red, instantáneo): no depende de que la barra ya haya mirado
    repos = len([l for l in sh(["checkupdates", "-n"], 15).splitlines() if l.strip()])
    # ¿se actualizó el kernel y aún no has reiniciado?
    reinicio = not Path("/usr/lib/modules", os.uname().release).exists()
    total = repos + aur
    estado = "mal" if reinicio else "aviso" if vuln or noticias or total > 60 else "info" if total else "ok"
    partes = []
    if reinicio:
        partes.append("El kernel se actualizó: reinicia para usar el nuevo (y que funcionen USB y módulos nuevos).")
    if noticias:
        partes.append(f"{noticias} noticias de Arch sin leer (pueden pedir pasos a mano).")
    if vuln:
        partes.append(f"{vuln} paquetes con vulnerabilidades conocidas y arreglo disponible.")
    partes.append(f"{repos} de los repos y {aur} del AUR pendientes." if total else "Sistema al día.")
    return c("actualizaciones", "Actualizaciones", estado, "reinicia" if reinicio else f"{total} pendientes" if total else "al día",
             " ".join(partes), {"texto": "Actualizar", "cmd": [str(SCRIPTS / "actualizaciones.sh"), "instalar"]} if total else None,
             "f03d6")


def pacnew():
    archivos = [l for l in sh(["pacdiff", "-o"], 15).splitlines() if l.endswith((".pacnew", ".pacsave"))]
    return c("pacnew", "Configuración nueva (.pacnew)", "aviso" if archivos else "ok",
             f"{len(archivos)} por revisar" if archivos else "nada pendiente",
             ("Paquetes que trajeron configuración nueva: " + ", ".join(Path(a).name for a in archivos[:4]) + ". Revísalas con «sudo pacdiff».")
             if archivos else "Ningún archivo .pacnew esperando.",
             {"texto": "Revisar", "cmd": terminal("sudo DIFFPROG='nvim -d' pacdiff")} if archivos else None, "f0214")


def memoria():
    info = {}
    for l in Path("/proc/meminfo").read_text().splitlines():
        k, v = l.split(":", 1)
        info[k] = int(v.split()[0])
    disp = info["MemAvailable"] * 100 // info["MemTotal"]
    swap = (info["SwapTotal"] - info["SwapFree"]) // 1024
    estado = "ok" if disp >= 15 else "aviso" if disp >= 5 else "mal"
    return c("memoria", "Memoria", estado, f"{disp} % libre",
             f"{info['MemAvailable'] // 1024} MiB disponibles · swap en uso: {swap} MiB (zram primero).", glifo="f035b")


def escritorio():
    errores = sh(["hyprctl", "configerrors"], 3).strip()
    grub = sh(["systemctl", "is-active", "grub-btrfsd"], 3)
    malos = []
    if errores:
        malos.append("errores en la configuración de Hyprland")
    if grub != "active":
        malos.append("grub-btrfsd parado (los snapshots nuevos no salen en GRUB)")
    return c("escritorio", "Escritorio y arranque", "aviso" if malos else "ok", "revisar" if malos else "bien",
             ("; ".join(malos) + ".") if malos else "Hyprland sin errores de configuración; GRUB recibe los snapshots.",
             {"texto": "Ver errores", "cmd": terminal("hyprctl configerrors")} if errores else None, "f0379")


COMPROBACIONES = [respaldo, disco, espacio, snapshots, actualizaciones, servicios, temperatura, bateria, memoria, scrub, usb, pacnew, escritorio]


def todo():
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(len(COMPROBACIONES)) as ex:
        res = []
        for f, fut in [(f, ex.submit(f)) for f in COMPROBACIONES]:
            try:
                res.append(fut.result(timeout=20))
            except Exception as e:   # una comprobación rota no tumba el panel
                res.append(c(f.__name__, f.__name__.capitalize(), "info", "—", f"No se pudo comprobar ({type(e).__name__})."))
    res.sort(key=lambda x: ORDEN[x["estado"]])
    peor = res[0]["estado"] if res else "ok"
    registro = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula/actualizaciones.jsonl"
    try:
        ultima = json.loads(registro.read_text().splitlines()[-1])
    except (OSError, ValueError, IndexError):
        ultima = None
    return {"estado": peor if peor in ("mal", "aviso") else "ok", "fecha": int(time.time()), "comprobaciones": res,
            "ultima_actualizacion": ultima}


def resumen(d):
    malos = [x for x in d["comprobaciones"] if x["estado"] in ("mal", "aviso")]
    if not malos:
        return "Todo en orden"
    return f"{len(malos)} {'cosa' if len(malos) == 1 else 'cosas'} que revisar: " + ", ".join(x["nombre"].lower() for x in malos[:4])


if __name__ == "__main__":
    d = todo()
    print(resumen(d) if len(sys.argv) > 1 and sys.argv[1] == "resumen" else json.dumps(d, ensure_ascii=False))
