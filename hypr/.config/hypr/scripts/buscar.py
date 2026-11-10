#!/usr/bin/env python3
"""Buscador del lanzador (SUPER+R) para lo que no son apps. Lo llama Lanzador.qml:
    buscar.py <tipo> <texto>   →   JSON: [{ "nombre", "detalle", "glifo", "cmd": [argv…] }, …]
Tipos (prefijo en el lanzador):
    ventanas (v)       ventanas abiertas en cualquier workspace → ir a ella
    notas (n)          líneas de tus notas (~/Documents/**/*.md) → abrir nvim en esa línea
    portapapeles (c)   historial del portapapeles (cliphist) → copiarlo otra vez
    pestanas (t)       pestañas abiertas de Firefox → abrir esa dirección
    claves (p)         gestor de contraseñas (rbw = Bitwarden, o pass) → escribir la clave o el usuario
"""
import json, os, re, subprocess, sys, unicodedata
from pathlib import Path

HOME = Path.home()
S = str(HOME / ".config/hypr/scripts")


def norm(s):
    return "".join(c for c in unicodedata.normalize("NFD", (s or "").lower()) if unicodedata.category(c) != "Mn")


def coincide(q, *textos):
    """Todas las palabras de q aparecen en alguno de los textos."""
    t = norm(" ".join(x or "" for x in textos))
    return all(p in t for p in norm(q).split())


def sh(*a, **k):
    try:
        return subprocess.run(a, capture_output=True, text=True, timeout=k.get("timeout", 4)).stdout
    except Exception:
        return ""


def ventanas(q):
    res = []
    for c in json.loads(sh("hyprctl", "clients", "-j") or "[]"):
        if not c.get("mapped", True) or not coincide(q, c.get("title"), c.get("class")):
            continue
        ws = c.get("workspace", {}).get("name", "?")
        res.append({"nombre": c.get("title") or c.get("class"), "detalle": f"{c.get('class')} · workspace {ws}", "glifo": 0xF05AF,
                    "cmd": ["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{c["address"]}" }})']})
    return res


def notas(q):
    if len(q.strip()) < 2:
        return []
    patron = ".*".join(re.escape(p) for p in q.split())
    out = sh("rg", "-n", "-i", "--no-heading", "--max-count", "8", "-g", "*.md", "-g", "*.txt", "--", patron, str(HOME / "Documents"))
    res = []
    for linea in out.splitlines()[:30]:
        try:
            ruta, n, texto = linea.split(":", 2)
        except ValueError:
            continue
        res.append({"nombre": texto.strip()[:110], "detalle": f"{ruta.replace(str(HOME), '~')} · línea {n}", "glifo": 0xF039A,
                    "cmd": ["kitty", "--class", "scratch-notas", "-e", "nvim", f"+{n}", ruta]})
    return res


def portapapeles(q):
    res = []
    for linea in sh("cliphist", "list").splitlines():
        ident, _, texto = linea.partition("\t")
        if texto.startswith("[[ binary") or not coincide(q, texto):
            continue
        res.append({"nombre": texto.strip()[:110], "detalle": "Enter: copiarlo otra vez", "glifo": 0xF0147,
                    "cmd": ["qs", "ipc", "call", "portapapeles", "copiarId", ident]})
        if len(res) >= 30:
            break
    return res


def pestanas(q):
    try:
        import lz4.block
    except ImportError:
        return [{"nombre": "Falta python-lz4", "detalle": "sudo pacman -S python-lz4", "glifo": 0xF0026, "cmd": []}]
    res, vistos = [], set()
    for perfil in (HOME / ".config/mozilla/firefox").glob("*/sessionstore-backups/recovery.jsonlz4"):
        try:
            datos = json.loads(lz4.block.decompress(perfil.read_bytes()[8:]))   # 8 bytes de cabecera "mozLz40\0"
        except Exception:
            continue
        for v in datos.get("windows", []):
            for tab in v.get("tabs", []):
                e = tab.get("entries") or []
                if not e:
                    continue
                e = e[min(tab.get("index", len(e)), len(e)) - 1]
                url, titulo = e.get("url", ""), e.get("title", "")
                if url in vistos or url.startswith("about:") or not coincide(q, titulo, url):
                    continue
                vistos.add(url)
                res.append({"nombre": titulo or url, "detalle": url[:100], "glifo": 0xF0239, "cmd": ["firefox", url]})
    return res[:30]


def claves(q):
    c = S + "/claves.sh"
    if (HOME / ".config/rbw/config.json").exists():
        if subprocess.run(["rbw", "unlocked"], capture_output=True).returncode != 0:
            return [{"nombre": "Desbloquear Bitwarden", "detalle": "Pide tu contraseña maestra y vuelve a buscar",
                     "glifo": 0xF033E, "cmd": [c, "desbloquear"]}]
        entradas = [l.split("\t") for l in sh("rbw", "list", "--fields", "name,user").splitlines()]
        entradas = [("rbw", e[0], e[1] if len(e) > 1 else "") for e in entradas]
    elif (HOME / ".password-store").is_dir():
        base = HOME / ".password-store"
        entradas = [("pass", str(p.relative_to(base))[:-4], "") for p in sorted(base.rglob("*.gpg"))]
    else:
        return [{"nombre": "Aún no hay gestor de contraseñas configurado", "detalle": "Enter: abre la guía (Bitwarden o pass)",
                 "glifo": 0xF030B, "cmd": ["kitty", "-e", c, "configurar"]}]
    res = []
    for tipo, nombre, usuario in entradas:
        if not coincide(q, nombre, usuario):
            continue
        res.append({"nombre": nombre, "detalle": (usuario + " · " if usuario else "") + "Enter: escribir la contraseña",
                    "glifo": 0xF030B, "cmd": [c, "clave", tipo, nombre, usuario]})
        if usuario:
            res.append({"nombre": nombre, "detalle": "Enter: escribir el usuario (" + usuario + ")",
                        "glifo": 0xF0004, "cmd": [c, "usuario", tipo, nombre, usuario]})
        if len(res) >= 30:
            break
    return res


TIPOS = {"ventanas": ventanas, "notas": notas, "portapapeles": portapapeles, "pestanas": pestanas, "claves": claves}

if __name__ == "__main__":
    tipo = sys.argv[1] if len(sys.argv) > 1 else ""
    q = " ".join(sys.argv[2:])
    try:
        print(json.dumps(TIPOS[tipo](q), ensure_ascii=False))
    except Exception as e:   # nunca dejar el lanzador sin respuesta
        print(json.dumps([{"nombre": "Error al buscar", "detalle": str(e)[:120], "glifo": 0xF0026, "cmd": []}]))
