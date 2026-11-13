#!/usr/bin/env python3
"""Colores del tema activo para las apps que pueden leer un archivo de fuera de su configuración.

Lo llama tema.sh al cambiar de tema o de wallpaper (no hace falta llamarlo a mano):
    pintar-apps.py
Lee ~/.local/state/tema/colores.css y escribe, en la misma carpeta:
    firefox.css   variables --ayu-* que importa firefox/chrome/userChrome.css (se ve al reiniciar Firefox)
Los nombres --ayu-* se mantienen para no tocar el resto de userChrome.css.
"""
import re
import sys
from pathlib import Path

ESTADO = Path.home() / ".local/state/tema"


def leer_paleta(css):
    return {m[1]: m[2].lower() for m in re.finditer(r"@define-color\s+(\w+)\s+#([0-9a-fA-F]{6})", css)}


def mezclar(a, b, t):
    """Color entre a y b (hex sin #): t = 0 → a, t = 1 → b."""
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def firefox(p):
    claro = sum(int(p["fondo"][i:i + 2], 16) for i in (0, 2, 4)) > 384
    hondo = mezclar(p["fondo"], "ffffff" if claro else "000000", .25)   # fila de pestañas, un poco más honda
    campo = mezclar(p["fondo"], p["texto"], .06)
    return f"""/* Generado por pintar-apps.py con la paleta activa: no editar (se sobrescribe al cambiar de tema).
 * El selector doble gana sobre los valores Ayu de userChrome.css, que quedan de respaldo. */
:root:root, :root:root[lwtheme] {{
  --ayu-fondo:     #{p["fondo"]};
  --ayu-hondo:     #{hondo};
  --ayu-campo:     #{campo};
  --ayu-seleccion: #{p["seleccion"]};
  --ayu-texto:     #{p["texto"]};
  --ayu-gris:      #{p["gris"]};
  --ayu-naranja:   #{p["acento"]};
}}
"""


def main():
    css = ESTADO / "colores.css"
    if not css.exists():
        return 0
    p = leer_paleta(css.read_text())
    if not {"fondo", "texto", "acento", "seleccion", "gris"} <= p.keys():
        print("pintar-apps: a la paleta le faltan colores", file=sys.stderr)
        return 1
    destino = ESTADO / "firefox.css"
    tmp = destino.with_suffix(".tmp")
    tmp.write_text(firefox(p))
    tmp.replace(destino)
    return 0


if __name__ == "__main__":
    sys.exit(main())
