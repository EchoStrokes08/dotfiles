#!/usr/bin/env python3
"""Opera GX a juego con el escritorio, como Firefox (SUPER+A → O).

Opera GX no tiene userChrome.css: se personaliza con "GX Mods" (una extensión con un bloque "mod").
Este script arma un mod con la paleta activa y lo carga al abrir Opera:
    tema       acento y base de la paleta (~/.local/state/tema/colores.css), en HSL como los pide GX
    wallpaper  el mismo fondo del escritorio (~/.local/state/tema/wallpaper) en la página de inicio
    estilos    barras de desplazamiento finas con el acento en todas las webs
    sonidos    ninguno: sin música de fondo ni teclas que suenan

El mod se escribe en ~/.local/share/opera-gx-orion (generado: no editar) y se carga con
--load-extension. Al cambiar de tema se ve la próxima vez que abras Opera (como en Firefox).
    opera-gx.py [direcciones…]    genera el mod y abre Opera GX
    opera-gx.py --solo-generar    solo genera (para pruebas)
"""
import colorsys
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ESTADO = Path.home() / ".local/state/tema"
MOD = Path.home() / ".local/share/opera-gx-orion"
PREFS = Path.home() / ".config/opera-gx/Default/Preferences"

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
                "ui_settings": {"background_blur": 0, "background_opacity": 0, "focus_mode": False,
                                "islands_opacity": 0, "vignette_strength": 0}}
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
    tmp = PREFS.with_name("Preferences.orion-tmp")
    tmp.write_text(json.dumps(prefs, separators=(",", ":")))
    tmp.replace(PREFS)


def abierto():
    return subprocess.run(["pgrep", "-x", "opera"], capture_output=True).returncode == 0


def main(args):
    if "--solo-generar" in args:
        generar()
        return 0
    if not abierto():   # con Opera abierto solo se le pasan las direcciones (no tocar su mod en marcha)
        generar()
        activar()
    os.execvp("opera-gx", ["opera-gx", f"--load-extension={MOD}", "--ozone-platform-hint=auto",
                           "--enable-features=TouchpadOverscrollHistoryNavigation", *args])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
