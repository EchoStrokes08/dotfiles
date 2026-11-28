#!/usr/bin/env python3
"""Opera GX a juego con el escritorio, como Firefox (SUPER+A → O).

Opera GX no tiene userChrome.css: se personaliza con "GX Mods" (una extensión con un bloque "mod").
Este script arma un mod con la paleta activa y lo carga al abrir Opera:
    tema       acento y base de la paleta (~/.local/state/tema/colores.css), en HSL como los pide GX
    wallpaper  el mismo fondo del escritorio (~/.local/state/tema/wallpaper) en la página de inicio
    estilos    barras de desplazamiento finas con el acento en todas las webs
    sonidos    ninguno: sin música de fondo ni teclas que suenan

El mod se escribe en ~/.local/share/opera-gx-orion (generado: no editar) y se carga con
--load-extension. Al cambiar de tema se ve la próxima vez que abras Opera (como en Firefox):
un mod desempaquetado no se recarga en marcha, así que la sincronización automática nunca
reinicia Opera. Si quieres verlo al momento, reinícialo tú.
    opera-gx.py [direcciones…]    genera el mod y abre Opera GX
    opera-gx.py --solo-generar    solo genera (para pruebas)
    opera-gx.py --sincronizar     deja el mod al día con el tema del sistema sin tocar Opera si
                                  está abierto (lo llama tema.py en cada cambio de tema o wallpaper,
                                  incluida la rotación automática). Se ve al próximo arranque.
    opera-gx.py --reiniciar       reaplica el tema ahora mismo: regenera el mod y, si Opera está
                                  abierto, lo reinicia restaurando la sesión (hazlo tú a mano).
"""
import colorsys
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ESTADO = Path.home() / ".local/state/tema"
MOD = Path.home() / ".local/share/opera-gx-orion"
PREFS = Path.home() / ".config/opera-gx/Default/Preferences"
PERFIL = Path.home() / ".config/opera-gx"   # donde Opera deja su SingletonLock

# Ayu: respaldo si todavía no hay paleta generada
RESPALDO = {"fondo": "0e1419", "texto": "e5e1cf", "acento": "f19618", "seleccion": "243340", "gris": "5c6773"}


def leer_paleta():
    css = ESTADO / "colores.css"
    p = dict(RESPALDO)
    if css.exists():
        p.update({m[1]: m[2].lower() for m in re.finditer(r"@define-color\s+(\w+)\s+#([0-9a-fA-F]{6})", css.read_text())})
    return p


def hsl(hexa, luz=None):
    """Color hex → {"h","s","l"} como lo guarda GX (grados y porcentajes). luz fuerza la L."""
    r, g, b = (int(hexa[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return {"h": round(h * 360, 1), "s": round(s * 100, 1), "l": round(luz if luz is not None else l * 100, 1)}


def estilos(p):
    return f"""/* Generado por opera-gx.py con la paleta activa */
* {{ scrollbar-width: thin; scrollbar-color: #{p["acento"]}99 transparent; }}
::selection {{ background: #{p["acento"]}55; }}
"""


def manifiesto(p, fondo):
    claro = sum(int(p["fondo"][i:i + 2], 16) for i in (0, 2, 4)) > 384
    base = hsl(p["fondo"])
    tema = {
        "id": "orion",
        "name": "ORION",
        # GX deriva todas las superficies de la base: la oscura es el fondo del escritorio tal cual
        "dark": {"gx_accent": hsl(p["acento"]), "gx_secondary_base": base if not claro else hsl(p["fondo"], 8)},
        "light": {"gx_accent": hsl(p["acento"]), "gx_secondary_base": base if claro else hsl(p["fondo"], 92)},
    }
    payload = {
        "theme": [tema],
        "page_styles": [{"id": "orion-paginas", "name": "ORION", "css": ["estilos/paginas.css"], "matches": ["*://*/*"]}],
    }
    if fondo:
        capa = {"groups": [{"layers": [{"type": "image", "resource": fondo,
                                        "options": {"blend_mode": "normal", "grayscale": False}}]}],
                "preview": {"352x248": fondo},
                "speeddial_position": "top", "text_shadow": "#000000",
                # islas = barra de pestañas, de direcciones y lateral: opacas a medias para que se lean
                # sobre el wallpaper; viñeta suave para que los bordes no compitan con el contenido
                "ui_settings": {"background_blur": 0, "background_opacity": 0, "focus_mode": False,
                                "islands_opacity": 70, "vignette_strength": 35}}
        payload["wallpaper"] = [{"id": "orion", "name": "ORION",
                                 "dark": {**capa, "text_color": f"#{p['texto']}"},
                                 "light": {**capa, "text_color": f"#{p['texto']}"}}]
    return {
        "manifest_version": 3,
        "name": "ORION",
        "version": "1.0",
        "description": "Opera GX con la paleta y el wallpaper del escritorio (generado por opera-gx.py)",
        "developer": {"name": "dotfiles"},
        "mod": {"schema_version": 2, "payload": payload},
    }


def generar():
    p = leer_paleta()
    tmp = MOD.with_name(MOD.name + ".tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    (tmp / "estilos").mkdir(parents=True)
    (tmp / "estilos/paginas.css").write_text(estilos(p))
    fondo = None
    wall = (ESTADO / "wallpaper").resolve()
    if wall.is_file() and wall.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
        fondo = "fondo/wallpaper" + wall.suffix.lower()
        (tmp / "fondo").mkdir()
        shutil.copyfile(wall, tmp / fondo)
    (tmp / "manifest.json").write_text(json.dumps(manifiesto(p, fondo), indent=2, ensure_ascii=False))
    shutil.rmtree(MOD, ignore_errors=True)
    tmp.rename(MOD)


def id_extension(ruta):
    """ID de una extensión cargada con --load-extension: sha256 de la ruta, 32 cifras hex pasadas a a-p."""
    return "".join(chr(int(c, 16) + 97) for c in hashlib.sha256(str(ruta).encode()).hexdigest()[:32])


def activar():
    """Deja elegidos el tema y el wallpaper del mod y apaga los sonidos (solo con Opera cerrado:
    al salir reescribe Preferences). Son preferencias normales, sin firma; la primera vez que se
    abre Opera todavía no existen y se activan en el siguiente arranque."""
    if not PREFS.exists():
        return
    prefs = json.loads(PREFS.read_text())
    mio = f"mods/{id_extension(MOD)}/orion"
    prefs.setdefault("ui", {})["active_theme_id"] = mio
    prefs.setdefault("rich_wallpapers", {})["selected_id"] = mio
    gx = prefs.setdefault("gx", {})
    gx.pop("sounds_browser_sounds_set", None)
    gx.pop("sounds_typing_sounds_set_2", None)
    gx["play_background_music"] = False
    # Primera vez (si ya lo cambiaste en Ajustes, se respeta): seguir donde lo dejaste en vez de abrir
    # GX Corner, y la barra lateral sin recompensas ni Twitch
    prefs.setdefault("session", {}).setdefault("restore_on_startup", 1)
    visibles = prefs["ui"].setdefault("browser", {}).setdefault("sidebar", {}).setdefault("item_prefs", {}).setdefault("visibility", {})
    for item in ("GxRewards", "aelmefcddnelhophneodelaokjogeemi"):   # el segundo es la extensión de Twitch
        visibles.setdefault(item, False)
    tmp = PREFS.with_name("Preferences.orion-tmp")
    tmp.write_text(json.dumps(prefs, separators=(",", ":")))
    tmp.replace(PREFS)


def pids():
    r = subprocess.run(["pgrep", "-x", "opera"], capture_output=True, text=True)
    return [int(x) for x in r.stdout.split()]


def abierto():
    return bool(pids())


def lanzar(args):
    os.execvp("opera-gx", ["opera-gx", f"--load-extension={MOD}", "--ozone-platform-hint=auto",
                           "--enable-features=TouchpadOverscrollHistoryNavigation", *args])


def lanzar_suelto(args):
    """Como lanzar(), pero sin reemplazar este proceso: Opera queda desvinculado de la terminal
    (sesión nueva, sin heredar stdio) para que sobreviva al cierre de la consola. Para --reiniciar,
    que se ejecuta desde una terminal y no debe morir con ella."""
    with open(os.devnull, "r+b") as nulo:
        subprocess.Popen(["opera-gx", f"--load-extension={MOD}", "--ozone-platform-hint=auto",
                          "--enable-features=TouchpadOverscrollHistoryNavigation", *args],
                         stdin=nulo, stdout=nulo, stderr=nulo, start_new_session=True)


def lock_huerfano():
    """SingletonLock apunta a HOST-PID; es huérfano si ese PID ya no existe. Opera no arranca si
    queda un lock vivo de otra instancia, y al cerrarse a veces tarda en soltarlo o lo deja colgado."""
    lock = PERFIL / "SingletonLock"
    try:
        destino = os.readlink(lock)
    except OSError:
        return False   # no hay lock
    pid = destino.rsplit("-", 1)[-1]
    if not pid.isdigit():
        return False
    try:
        os.kill(int(pid), 0)   # señal 0: solo comprueba si el proceso existe
    except ProcessLookupError:
        return True
    except PermissionError:
        return False   # existe pero no es nuestro: no tocar
    return False


def cerrar_limpio(espera=10.0):
    """Cierra Opera con SIGTERM y espera a que salga y suelte su SingletonLock, para que guarde la
    sesión (sin SIGKILL: un cierre forzado haría aparecer el aviso de restaurar y perder la sesión)
    y para que el nuevo Opera no vea un lock vivo. Si el lock queda huérfano, lo borra.
    Devuelve True si no quedó ningún proceso."""
    vivos = pids()
    for pid in vivos:
        try:
            os.kill(pid, 15)   # SIGTERM: cierre ordenado
        except ProcessLookupError:
            pass
    fin = time.monotonic() + espera
    while time.monotonic() < fin:
        if not abierto() and not lock_huerfano():
            break
        time.sleep(0.2)
    if abierto():
        return False
    if lock_huerfano():   # Opera salió pero dejó el lock colgado: quitarlo para que el nuevo arranque
        (PERFIL / "SingletonLock").unlink(missing_ok=True)
    return True


def sincronizar():
    """Deja el mod al día con el tema del sistema SIN tocar Opera si está abierto. Un mod
    desempaquetado no se recarga en marcha, así que, como Firefox, el cambio se ve la próxima vez
    que abras Opera. Con Opera cerrado además lo elige ya en Preferences. Lo llama tema.py en cada
    cambio de tema o de wallpaper (incluida la rotación automática), por eso aquí no se reinicia:
    para forzar el reinicio y verlo al momento, usa --reiniciar."""
    generar()
    if not abierto():
        activar()
    return 0


def reiniciar():
    """Reaplica el tema del sistema reiniciando Opera (a mano). Regenera el mod, cierra Opera
    guardando la sesión y lo reabre restaurándola (activar() dejó restore_on_startup=1). Con Opera
    cerrado equivale a --sincronizar."""
    if not abierto():
        generar()
        activar()
        return 0
    if not cerrar_limpio():
        print("opera-gx: Opera sigue abierto; no se reinició para sincronizar el tema", file=sys.stderr)
        return 1
    generar()
    activar()   # ahora que está cerrado, elige el mod en Preferences
    lanzar_suelto([])   # desvinculado de la terminal: Opera sobrevive al cierre de la consola
    return 0


def main(args):
    if "--solo-generar" in args:
        generar()
        return 0
    if "--sincronizar" in args:
        return sincronizar()
    if "--reiniciar" in args:
        return reiniciar()
    if not abierto():   # con Opera abierto solo se le pasan las direcciones (no tocar su mod en marcha)
        generar()
        activar()
    lanzar(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
