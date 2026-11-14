#!/usr/bin/env python3
"""Almacenamiento del SSD: qué ocupa espacio y cómo recuperarlo sin romper nada.

    almacenamiento.py estado              JSON: disco, categorías con tamaño y su acción, snapshots
    almacenamiento.py grandes [N]         los N archivos más grandes de tu carpeta (≥ 100 MB)
    almacenamiento.py limpiar papelera|cache|firefox
    almacenamiento.py a-papelera RUTA     mover un archivo a la papelera (se puede recuperar)

Reglas:
  · Solo se limpia lo que se regenera solo. Nunca: el navegador del agente (ms-playwright), el modelo
    de dictado (whisper), la memoria del agente (brujula), el portapapeles (cliphist) ni Quickshell.
  · Lo que necesita administrador (paquetes, registro del sistema, snapshots) no se ejecuta aquí:
    se devuelve la orden para abrirla en una terminal, donde la persona ve y confirma.
  · Un archivo grande va a la papelera, no se borra.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
PAPELERA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "Trash"
# Cachés que la propia herramienta vuelve a crear cuando las necesita
CACHE_SEGURA = ["go-build", "yay", "paru", "pip", "thumbnails", "winetricks", "uv", "mesa_shader_cache", "radv_builtin_shaders"]
MINIMO_GRANDE = 100 * 2**20


def tam(ruta, limite=25):
    """Bytes que ocupa una carpeta o archivo (du), 0 si no existe o no se puede leer a tiempo."""
    ruta = Path(ruta)
    if not ruta.exists():
        return 0
    try:
        r = subprocess.run(["du", "-sb", "--", str(ruta)], capture_output=True, text=True, timeout=limite)
        return int(r.stdout.split()[0]) if r.stdout else 0
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        return 0


def corriendo(nombre):
    try:
        return subprocess.run(["pgrep", "-x", nombre], capture_output=True, timeout=3).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def snapshots(config):
    try:
        r = subprocess.run(["snapper", "-c", config, "--jsonout", "list"], capture_output=True, text=True, timeout=8)
        return max(0, len(json.loads(r.stdout).get(config, [])) - 1)   # sin el «current»
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def disco():
    st = os.statvfs("/")
    total, libre = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    modelo = ""
    try:
        r = subprocess.run(["findmnt", "-no", "SOURCE,FSTYPE", "/"], capture_output=True, text=True, timeout=3)
        fuente, fs = (r.stdout.split() + ["", ""])[:2]
        dispositivo = fuente.split("[")[0]
        padre = subprocess.run(["lsblk", "-no", "PKNAME", dispositivo], capture_output=True, text=True, timeout=3).stdout.strip()
        if padre:
            modelo = Path(f"/sys/block/{padre}/device/model").read_text().strip()
    except (OSError, ValueError, subprocess.TimeoutExpired):
        fs = ""
    return {"total": total, "usado": total - libre, "libre": libre, "fs": fs, "modelo": modelo}


def categorias():
    cache_total = tam(CACHE)
    segura = sum(tam(CACHE / n) for n in CACHE_SEGURA)
    firefox = tam(CACHE / "mozilla")
    cats = [
        {"id": "papelera", "nombre": "Papelera", "bytes": tam(PAPELERA), "detalle": "Lo que borraste desde las apps",
         "accion": {"tipo": "limpiar", "orden": "papelera", "etiqueta": "Vaciar", "confirmar": True}},
        {"id": "cache", "nombre": "Cachés de apps", "bytes": cache_total, "limpiable": segura,
         "detalle": "Se regeneran solas: compilación, pip, AUR, miniaturas. No toca el navegador del agente, el dictado ni la memoria",
         "accion": {"tipo": "limpiar", "orden": "cache", "etiqueta": "Limpiar lo seguro"}},
        {"id": "firefox", "nombre": "Caché de Firefox", "bytes": firefox, "detalle": "Páginas guardadas para cargar más rápido",
         "accion": {"tipo": "limpiar", "orden": "firefox", "etiqueta": "Limpiar", "requiere_cerrado": "firefox"}},
        {"id": "paquetes", "nombre": "Paquetes descargados", "bytes": tam("/var/cache/pacman/pkg"),
         "detalle": "Versiones viejas de programas. Se conservan las dos últimas por si hay que volver atrás",
         "accion": {"tipo": "terminal", "etiqueta": "Limpiar (pide contraseña)",
                    "orden": "sudo paccache -rk2 && sudo paccache -ruk0; echo; read -p 'Enter para cerrar' x"}},
        {"id": "registro", "nombre": "Registro del sistema", "bytes": tam("/var/log/journal"), "detalle": "Mensajes de diagnóstico",
         "accion": {"tipo": "terminal", "etiqueta": "Dejar en 200 MB (pide contraseña)",
                    "orden": "sudo journalctl --vacuum-size=200M; echo; read -p 'Enter para cerrar' x"}},
        {"id": "juegos", "nombre": "Juegos de Steam", "bytes": tam(HOME / ".local/share/Steam"), "detalle": "Se desinstalan desde Steam",
         "accion": {"tipo": "app", "orden": "steam", "etiqueta": "Abrir Steam"}},
        {"id": "apps", "nombre": "Datos de apps Flatpak", "bytes": tam(HOME / ".var/app"), "detalle": "Spotify, ZapZap, Sober…",
         "accion": {"tipo": "abrir", "orden": str(HOME / ".var/app"), "etiqueta": "Ver carpeta"}},
        {"id": "descargas", "nombre": "Descargas", "bytes": tam(HOME / "Downloads"), "detalle": "Revisa los archivos grandes de abajo",
         "accion": {"tipo": "abrir", "orden": str(HOME / "Downloads"), "etiqueta": "Abrir"}},
        {"id": "videos", "nombre": "Vídeos y replays", "bytes": tam(HOME / "Videos"), "detalle": "Grabaciones y clips de 30 s",
         "accion": {"tipo": "abrir", "orden": str(HOME / "Videos"), "etiqueta": "Abrir"}},
    ]
    return [c for c in cats if c["bytes"] > 0]


def estado():
    d = disco()
    cats = categorias()
    otros = max(0, d["usado"] - sum(c["bytes"] for c in cats))
    cats.append({"id": "otros", "nombre": "Sistema y resto de tus archivos", "bytes": otros,
                 "detalle": "Programas instalados, documentos, configuración y snapshots compartidos"})
    cats.sort(key=lambda c: (c["id"] == "otros", -c["bytes"]))
    return {"disco": d, "categorias": cats, "snapshots": {"root": snapshots("root"), "home": snapshots("home")},
            "firefox_abierto": corriendo("firefox"), "generado": int(time.time())}


def grandes(n=12):
    """Archivos ≥ 100 MB en tus carpetas visibles (Descargas, Documentos, Vídeos…). [{ruta, bytes, fecha}]
    Las carpetas ocultas (.local, .var, .config…) son de las apps: borrar ahí puede romperlas."""
    res = []
    for raiz, dirs, archivos in os.walk(HOME):
        dirs[:] = [x for x in dirs if not (raiz == str(HOME) and x.startswith(".")) and not os.path.islink(os.path.join(raiz, x))]
        for a in archivos:
            p = os.path.join(raiz, a)
            try:
                st = os.lstat(p)
            except OSError:
                continue
            if st.st_size >= MINIMO_GRANDE and not os.path.islink(p):
                res.append({"ruta": p, "bytes": st.st_size, "fecha": int(st.st_mtime)})
    return sorted(res, key=lambda x: -x["bytes"])[:n]


def vaciar(carpeta, nombres=None):
    """Borra el contenido (no la carpeta). nombres: solo esas subcarpetas. Devuelve bytes liberados."""
    antes = sum(tam(carpeta / n) for n in nombres) if nombres else tam(carpeta)
    objetivos = [carpeta / n for n in nombres] if nombres else list(carpeta.iterdir()) if carpeta.exists() else []
    for o in objetivos:
        if not o.exists() or o.is_symlink() and not o.exists():
            continue
        if o.is_dir() and not o.is_symlink():
            shutil.rmtree(o, ignore_errors=True)
        else:
            o.unlink(missing_ok=True)
    return antes


def limpiar(que):
    if que == "papelera":
        antes = tam(PAPELERA)
        r = subprocess.run(["gio", "trash", "--empty"], capture_output=True, text=True, timeout=120)
        if r.returncode:
            raise OSError(r.stderr.strip() or "No se pudo vaciar la papelera")
        liberado = max(0, antes - tam(PAPELERA))
    elif que == "cache":
        liberado = vaciar(CACHE, CACHE_SEGURA)
    elif que == "firefox":
        if corriendo("firefox"):
            raise OSError("Cierra Firefox antes de limpiar su caché")
        liberado = vaciar(CACHE / "mozilla")
    else:
        raise ValueError("Se limpia: papelera, cache o firefox")
    return {"ok": True, "liberado": liberado, "mensaje": f"Liberados {liberado / 2**20:.0f} MB."}


def a_papelera(ruta):
    p = Path(ruta).expanduser().resolve()
    if not p.is_file() or HOME not in p.parents:
        raise ValueError("Solo se mueven a la papelera archivos de tu carpeta personal")
    r = subprocess.run(["gio", "trash", "--", str(p)], capture_output=True, text=True, timeout=30)
    if r.returncode:
        raise OSError(r.stderr.strip() or "No se pudo mover a la papelera")
    return {"ok": True, "mensaje": f"«{p.name}» está en la papelera: se puede recuperar hasta vaciarla."}


def main(argv):
    orden = argv[0] if argv else "estado"
    try:
        r = (estado() if orden == "estado" else grandes(int(argv[1]) if len(argv) > 1 else 12) if orden == "grandes"
             else limpiar(argv[1]) if orden == "limpiar" and len(argv) > 1
             else a_papelera(argv[1]) if orden == "a-papelera" and len(argv) > 1 else None)
        if r is None:
            print(__doc__)
            return 2
    except (OSError, ValueError, subprocess.TimeoutExpired) as e:
        print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        return 1
    print(json.dumps(r, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
