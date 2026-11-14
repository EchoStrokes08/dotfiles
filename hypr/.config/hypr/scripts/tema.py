#!/usr/bin/env python3
"""Tema transaccional: preparar, validar y publicar una generación completa.

Matugen extrae acentos; los roles de superficie son neutros. La rotación reutiliza caché,
no recarga Hyprland y descarta peticiones que hayan quedado atrás.
"""
import fcntl
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
DIR = HOME / ".config/tema"
OUT = HOME / ".local/state/tema"
CACHE = OUT / "generaciones"
PATRON = re.compile(r"{{colors\.(\w+)\.default\.(hex|hex_stripped)}}")


def leer(nombre, defecto=""):
    try:
        return (OUT / nombre).read_text().strip()
    except OSError:
        return defecto


def atomico(ruta, texto):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=ruta.parent, delete=False) as f:
        f.write(texto)
    os.replace(f.name, ruta)


@contextmanager
def registro():
    # Registrar una petición y publicar su resultado usan el mismo cerrojo breve.
    with (OUT / "peticiones.lock").open("w") as archivo:
        fcntl.flock(archivo, fcntl.LOCK_EX)
        yield


def comando(args):
    return subprocess.run(args, capture_output=True, text=True, timeout=30, check=True).stdout.strip()


def luminancia(c):
    cs = [int(c.lstrip("#")[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return sum(w * (v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4)
               for v, w in zip(cs, (.2126, .7152, .0722)))


def contraste(a, b):
    x, y = sorted((luminancia(a), luminancia(b)))
    return (y + .05) / (x + .05)


def mezcla(a, b, t):
    return "#" + "".join(f"{round(int(a[i:i+2],16)*(1-t)+int(b[i:i+2],16)*t):02x}" for i in (1,3,5))


def ajustar(c, fondo, minimo=4.5):
    destino = "#000000" if luminancia(fondo) > .5 else "#ffffff"
    for i in range(101):
        candidato = mezcla(c, destino, i/100)
        if contraste(candidato, fondo) >= minimo:
            return candidato
    return destino


def paleta(modo, variante, imagen, fijo=None):
    claro = variante == "claro"
    base = DIR / ("ayu-claro" if claro else "ayu") / "colores.css"
    p = dict(re.findall(r"@define-color\s+(\w+)\s+(#[\da-fA-F]{6})", base.read_text()))
    p.update(fondo="#f5f6f8" if claro else "#121519", texto="#262c35" if claro else "#edf0f5",
             seleccion="#dce1e8" if claro else "#2b323c", gris="#586271" if claro else "#aab3c0")
    if modo == "wallpaper" and not fijo:
        datos = json.loads(comando(["matugen", "--dry-run", "--json", "hex", "--prefer", "saturation", "-m",
                                    "light" if claro else "dark", "image", str(imagen)]))["colors"]
        p["acento"] = datos["primary"]["default"]["color"]
        p["acento2"] = datos["tertiary"]["default"]["color"]
    if fijo:
        p.update(fijo)
    for nombre in ("acento", "acento2", "exito", "aviso", "peligro"):
        p[nombre] = ajustar(p[nombre], p["fondo"])
    p["sobreAcento"] = "#000000" if contraste(p["acento"], "#000000") >= contraste(p["acento"], "#ffffff") else "#ffffff"
    return p


def renderizar(p, variante):
    claro = variante == "claro"
    roles = {"surface": p["fondo"], "on_surface": p["texto"], "outline": p["gris"],
             "surface_container_lowest": "#ffffff" if claro else "#0d1014",
             "surface_container": "#eceff3" if claro else "#1a1e24",
             "surface_container_highest": p["seleccion"], "primary": p["acento"],
             "tertiary": p["acento2"], "secondary": p["acento2"], "secondary_fixed_dim": p["acento2"],
             "tertiary_fixed_dim": p["acento2"], "error": p["peligro"], "on_primary": p["sobreAcento"]}
    archivos = {}
    for plantilla in (DIR / "plantillas").iterdir():
        if not plantilla.is_file():
            continue
        def reemplazar(m):
            color = roles[m[1]]
            return color[1:] if m[2] == "hex_stripped" else color
        contenido = PATRON.sub(reemplazar, plantilla.read_text())
        if "{{" in contenido:
            raise ValueError(f"Plantilla no resuelta: {plantilla.name}")
        archivos[plantilla.name] = contenido
    archivos["colores.css"] = "/* Generación ORION: superficies neutras, acento adaptable. */\n" + "".join(
        f"@define-color {n} {c};\n" for n, c in p.items())
    archivos["hyprland.lua"] = "return {\n" + "".join(f'    {n} = "{c[1:]}",\n' for n, c in p.items()) + "}\n"
    # Los estados y ANSI de la variante clara deben ser legibles sobre superficies claras.
    if claro:
        kitty = archivos["kitty.conf"]
        ansi = "\n".join(l for l in (DIR / "ayu-claro/kitty.conf").read_text().splitlines() if re.match(r"color\d+\s", l))
        archivos["kitty.conf"] = re.sub(r"^color\d+ .*$", "", kitty, flags=re.M) + "\n" + ansi + "\n"
    # Colores de estados fijos, adaptados a su superficie y a su texto.
    for nombre in ("gtk3.css", "gtk4.css"):
        t = archivos[nombre]
        t = t.replace("#b8cc52", p["exito"]).replace("#e6c446", p["aviso"])
        for rol in ("accent", "destructive", "success", "warning", "error"):
            color = p[{"accent":"acento", "destructive":"peligro", "success":"exito", "warning":"aviso", "error":"peligro"}[rol]]
            encima = "#000000" if contraste(color,"#000000") >= contraste(color,"#ffffff") else "#ffffff"
            t = re.sub(rf"(@define-color {rol}_fg_color\s+)[^;]+", lambda m:m[1]+encima, t)
            t = re.sub(rf"(--{rol}-fg-color:\s*)[^;]+", lambda m:m[1]+encima, t)
        archivos[nombre] = t
    # Generar Firefox y el bloqueo antes de publicar, sin procesos durante la rotación.
    import importlib.util
    spec = importlib.util.spec_from_file_location("pintar_apps", Path(__file__).with_name("pintar-apps.py"))
    modulo = importlib.util.module_from_spec(spec); spec.loader.exec_module(modulo)
    archivos["firefox.css"] = modulo.firefox({n:c[1:] for n,c in p.items()})
    bloqueo = HOME / ".config/hypr/hyprlock.conf"
    if bloqueo.exists():
        t = bloqueo.read_text()
        for viejo, nombre in {"f19618":"acento","36a3d9":"acento2","e5e1cf":"texto","c2d94c":"exito","e6c446":"aviso","ff3333":"peligro","f07178":"peligro","5c6773":"gris","0b0e14":"fondo"}.items():
            t = t.replace(viejo,p[nombre][1:])
        archivos["hyprlock.conf"] = t
    return archivos


def publicar(carpeta):
    """Un único cambio de enlace publica todas las salidas. El marcador avisa a FileView."""
    enlace = OUT / "actual"
    if not enlace.exists():
        anterior = OUT / "generacion-inicial"
        anterior.mkdir(exist_ok=True)
        for p in OUT.iterdir():
            if p.is_file() and p.suffix in (".css", ".lua", ".ini", ".theme", ".conf"):
                shutil.copyfile(p, anterior / p.name)
        enlace.symlink_to(anterior, target_is_directory=True)
    for p in carpeta.iterdir():
        destino = OUT / p.name
        temporal = OUT / (p.name + ".enlace")
        temporal.unlink(missing_ok=True)
        temporal.symlink_to(Path("actual") / p.name)
        os.replace(temporal, destino)
    temporal = OUT / "actual.nuevo"
    temporal.unlink(missing_ok=True)
    temporal.symlink_to(carpeta, target_is_directory=True)
    os.replace(temporal, enlace)
    atomico(OUT / "version", str(time.time_ns()))


def generar(modo, variante, imagen, peticion):
    fijo = json.loads(leer("acento-fijo.json", "null"))
    fuente = Path(imagen) if imagen else OUT / "wallpaper"
    identidad = (str(fuente.resolve()), fuente.stat().st_mtime_ns, fuente.stat().st_size) if modo == "wallpaper" and not fijo else None
    plantillas = "".join(p.read_text() for p in sorted((DIR/"plantillas").iterdir()) if p.is_file())
    base = (DIR / ("ayu-claro" if variante == "claro" else "ayu") / "colores.css").read_text()
    clave = hashlib.sha256(repr((modo,variante,identidad,fijo,plantillas,base,Path(__file__).read_text())).encode()).hexdigest()
    carpeta = CACHE / clave
    if not (carpeta / "colores.css").exists():
        p = paleta(modo,variante,fuente,fijo)
        archivos = renderizar(p,variante)
        CACHE.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(dir=CACHE) as tmp:
            for nombre, texto in archivos.items():
                (Path(tmp)/nombre).write_text(texto)
            shutil.copytree(tmp,carpeta,dirs_exist_ok=True)
    with registro():
        if leer("peticion") != peticion:
            return False
        publicar(carpeta)
        atomico(OUT/"modo",modo); atomico(OUT/"variante",variante)
        preferencias()
    return True


def preferencias():
    atomico(OUT/"preferencias.json",json.dumps({"modo":leer("modo","ayu"),"variante":leer("variante","oscuro"),
        "fijado":(OUT/"acento-fijo.json").exists(), "reducirMovimiento":leer("movimiento_reducido","off")=="on"}))


def notificar(texto):
    subprocess.run(["notify-send","-a","Tema",texto],timeout=3,check=False)


def recargar(variante, anterior):
    # Las apps leen una generación coherente; no se reinician reglas ni temporizadores del compositor.
    for args in (["hyprctl","dispatch","colores_tema and colores_tema() or hl.dsp.no_op()"],
                 ["pkill","-SIGUSR1","-x","kitty"]):
        try: subprocess.run(args,timeout=5,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        except (OSError,subprocess.TimeoutExpired): pass
    if variante != anterior:
        for clave, valor in (("color-scheme","prefer-light" if variante=="claro" else "prefer-dark"),
                             ("gtk-theme","adw-gtk3" if variante=="claro" else "adw-gtk3-dark")):
            subprocess.run(["gsettings","set","org.gnome.desktop.interface",clave,valor],timeout=5,check=False)


def main(args=None):
    args = sys.argv[1:] if args is None else args
    accion = args[0] if args else "estado"
    OUT.mkdir(parents=True,exist_ok=True)
    if accion in ("estado","modo"):
        print(leer("modo","ayu") + (" " + leer("variante","oscuro") + " " + ("auto" if leer("auto")=="on" else "manual") if accion=="estado" else "")); return 0
    if accion == "auto":
        if len(args)>1 and args[1] in ("on","off"):
            atomico(OUT/"auto",args[1]); (OUT/"ultimo_auto").unlink(missing_ok=True)
        else: print(leer("auto","off"))
        return 0
    if accion == "movimiento":
        atomico(OUT/"movimiento_reducido","on" if len(args)>1 and args[1]=="reducir" else "off"); preferencias(); return 0
    validas=("ayu","wallpaper","alternar","claro","oscuro","variante","automatico","aplicar","rotar","fijar","seguir")
    if accion not in validas:
        print("Acción de tema desconocida",file=sys.stderr); return 2
    peticion=str(time.time_ns())
    with registro():
        atomico(OUT/"peticion",peticion)
    with (OUT/"lock").open("w") as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if leer("peticion") != peticion: return 0
        modo=leer("modo","ayu"); variante=leer("variante","oscuro"); anterior=variante
        if accion=="rotar" and (modo!="wallpaper" or (OUT/"acento-fijo.json").exists()): return 0
        if accion=="automatico":
            atomico(OUT/"ultimo_auto",args[1])
            if leer("auto")!="on" or args[1]==variante: return 0
            variante=args[1]
        if accion in ("ayu","wallpaper"): modo=accion; (OUT/"acento-fijo.json").unlink(missing_ok=True)
        if accion=="alternar": modo="ayu" if modo=="wallpaper" else "wallpaper"; (OUT/"acento-fijo.json").unlink(missing_ok=True)
        if accion in ("claro","oscuro"): variante=accion
        if accion=="variante": variante="claro" if variante=="oscuro" else "oscuro"
        if accion=="fijar":
            p=dict(re.findall(r"@define-color\s+(\w+)\s+(#[\da-fA-F]{6})",leer("colores.css")))
            atomico(OUT/"acento-fijo.json",json.dumps({n:p[n] for n in ("acento","acento2")}))
        if accion=="seguir": (OUT/"acento-fijo.json").unlink(missing_ok=True); modo="wallpaper"
        try:
            if generar(modo,variante,args[1] if accion in ("aplicar","rotar") and len(args)>1 else None,peticion): recargar(variante,anterior)
        except (OSError,ValueError,KeyError,subprocess.SubprocessError) as e:
            print(f"No se pudo generar el tema: {type(e).__name__}",file=sys.stderr)
            if leer("error-tema")!="fallo":
                notificar("No se pudo actualizar el color. Se conserva la última paleta válida.")
            atomico(OUT/"error-tema","fallo"); return 1
        else: (OUT/"error-tema").unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
