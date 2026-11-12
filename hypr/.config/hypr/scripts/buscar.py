#!/usr/bin/env python3
"""Buscador del lanzador (SUPER+R) para lo que no son apps. Lo llama Lanzador.qml:
    buscar.py <tipo> <texto>   →   JSON: [{ "nombre", "detalle", "glifo", "cmd": [argv…] }, …]
Tipos (prefijo en el lanzador):
    ventanas (v)       ventanas abiertas en cualquier workspace → ir a ella
    notas (n)          líneas de tus notas (~/Documents/**/*.md) → abrir nvim en esa línea
    portapapeles (c)   historial del portapapeles (cliphist) → copiarlo otra vez
    pestanas (t)       pestañas abiertas de Firefox → abrir esa dirección
    claves (p)         gestor de contraseñas (rbw = Bitwarden, o pass) → escribir la clave o el usuario
    documentos (d)     DENTRO de tus PDF, Word y apuntes (índice de indice.py) → abrirlo
    historial (h)      páginas que visitaste en Firefox → abrirla
    atajos (a)         atajos de teclado del manual de usuario → verlos en la chuleta
    linea (l)          tu línea de tiempo: dónde viste algo y cuándo → abrir ese día en Brújula
    ajustes (s)        cada opción del escritorio (perfiles, tema, energía, reglas, móvil…) → aplicarla ya
    todo (b)           todo lo anterior a la vez (también lo usa el lanzador al escribir 3+ letras)
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


def documentos(q):
    sys.path.insert(0, S)
    try:
        import indice
    except ImportError:
        return []
    res = []
    for ruta, fragmento in indice.buscar(q, 8):
        p = Path(ruta)
        glifo = 0xF0226 if p.suffix.lower() == ".pdf" else 0xF0219 if p.suffix.lower() in (".docx", ".odt") else 0xF0224
        res.append({"nombre": p.name, "detalle": fragmento[:140] or str(p.parent).replace(str(HOME), "~"),
                    "glifo": glifo, "cmd": ["xdg-open", ruta]})
    return res


def historial(q):
    import sqlite3
    if len(q.strip()) < 2:
        return []
    res = []
    for db in (HOME / ".config/mozilla/firefox").glob("*/places.sqlite"):
        try:
            # immutable: leer sin bloquear a Firefox (puede faltar lo de los últimos minutos)
            c = sqlite3.connect(f"file:{db}?immutable=1", uri=True, timeout=1)
            palabras = [f"%{w}%" for w in q.split()[:5]]
            donde = " AND ".join("(coalesce(title,'') || ' ' || url) LIKE ?" for _ in palabras)
            filas = c.execute(f"SELECT url, title FROM moz_places WHERE hidden = 0 AND url LIKE 'http%' AND {donde} "
                              "ORDER BY frecency DESC LIMIT 80", palabras).fetchall()
            c.close()
        except sqlite3.Error:
            continue
        for url, titulo in filas:
            # que coincida en el título o en la dirección sin parámetros (?…), no en un token cualquiera
            if not coincide(q, titulo, url.split("?")[0].split("#")[0]):
                continue
            if len(res) >= 8:
                break
            res.append({"nombre": titulo or url, "detalle": re.sub(r"^https?://(www\.)?", "", url)[:100],
                        "glifo": 0xF02DA, "cmd": ["firefox", url]})
    return res[:8]


def atajos(q):
    if len(q.strip()) < 2:
        return []
    res = []
    try:
        texto = (HOME / "dotfiles/docs/manual.md").read_text()
        texto = texto.split("<!-- atajos:inicio -->", 1)[-1].split("<!-- atajos:fin -->", 1)[0]
    except OSError:
        return []
    for m in re.finditer(r"^\|\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$", texto, re.M):
        tecla, accion = m.group(1), re.sub(r"[*`]", "", m.group(2))
        if not re.search(r"SUPER|CTRL|ALT|SHIFT|PRINT|Bloq|XF86|^F\d", tecla):   # filas de comandos o paquetes
            continue
        if coincide(q, tecla, accion):
            res.append({"nombre": accion[:110], "detalle": tecla, "glifo": 0xF030C,
                        "cmd": ["qs", "ipc", "call", "chuleta", "buscar", q]})
        if len(res) >= 8:
            break
    return res


def linea(q):
    import datetime as dt
    if len(q.strip()) < 3:
        return []
    carpeta = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula/linea"
    res, vistos = [], set()
    for f in sorted(carpeta.glob("*.jsonl"), reverse=True)[:30] if carpeta.is_dir() else []:
        for l in reversed(f.read_text(errors="replace").splitlines()):
            try:
                r = json.loads(l)
            except ValueError:
                continue
            ti = r.get("ti", "")
            if not ti or ti in vistos or not coincide(q, ti):
                continue
            vistos.add(ti)
            cuando = dt.datetime.fromtimestamp(r["t"])
            dias = (dt.date.today() - cuando.date()).days
            dia = "hoy" if dias == 0 else "ayer" if dias == 1 else cuando.strftime("%d/%m")
            res.append({"nombre": ti[:110], "detalle": f"Lo tuviste delante {dia} a las {cuando:%H:%M} · {r.get('c', '')}",
                        "glifo": 0xF0954, "cmd": ["qs", "ipc", "call", "brujula", "dia", f.stem]})
            if len(res) >= 6:
                return res
    return res


def ajustes(q):
    """Cada opción concreta, lista para aplicarse con Enter: «lectura», «tema claro», «desactivar regla programar»…"""
    if len(q.strip()) < 2:
        return []
    esc = S + "/escritorio.py"
    bru = S + "/brujula.py"
    mov = S + "/movil.py"
    hd = lambda e: ["hyprctl", "dispatch", e + " or hl.dsp.no_op()"]
    estado = {}
    try:
        runtime, firma = os.environ.get("XDG_RUNTIME_DIR", ""), os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
        estado = dict(l.split("=", 1) for l in Path(runtime, f"hypr-escritorio-{firma}.state").read_text().splitlines() if "=" in l)
    except OSError:
        pass
    perfil = estado.get("perfil", "")
    A = [  # (nombre, dónde/qué, palabras clave, orden, glifo)
        *[(f"Perfil {n}" + (" · actual" if n == perfil else ""), d, "perfil apariencia efectos transparencia blur " + k, [esc, "perfil", n], 0xF03D8)
          for n, d, k in [("cristal", "Transparencias y desenfoque (el de siempre)", "glass vidrio"),
                          ("lectura", "Opaco y sin desenfoque: para leer y programar", "opaco leer"),
                          ("minimo", "Sin animaciones ni sombras: ahorra batería", "minimo bateria"),
                          ("rendimiento", "Sin efectos ni bordes: máximo rendimiento", "rapido juegos")]],
        ("Privacidad: activar o quitar", "Oculta títulos, línea de tiempo y vistas previas · SUPER+CTRL+P", "privado ocultar reunion", [esc, "privacidad"], 0xF033E),
        ("No molestar: activar o quitar", "Silencia las notificaciones · SUPER+SHIFT+N", "notificaciones silencio dnd", ["qs", "ipc", "call", "notificaciones", "noMolestar"], 0xF009B),
        ("Tema claro", "Variante clara de los colores", "colores claro dia blanco", [S + "/tema.sh", "claro"], 0xF05A8),
        ("Tema oscuro", "Variante oscura de los colores", "colores oscuro noche negro", [S + "/tema.sh", "oscuro"], 0xF0594),
        ("Colores Ayu", "Paleta fija Ayu", "tema paleta ayu", [S + "/tema.sh", "ayu"], 0xF03D8),
        ("Colores del wallpaper", "Los colores salen del fondo (matugen)", "tema paleta fondo matugen", [S + "/tema.sh", "wallpaper"], 0xF0E09),
        ("Tema claro/oscuro automático: activar", "Claro de día y oscuro de noche", "tema horario automatico", [S + "/tema.sh", "auto", "on"], 0xF0594),
        ("Tema claro/oscuro automático: desactivar", "Siempre la variante elegida", "tema horario automatico", [S + "/tema.sh", "auto", "off"], 0xF0594),
        ("Luz nocturna: activar o quitar", "Pantalla cálida · SUPER+ALT+N", "noche calida azul sunset", [S + "/luz-nocturna.sh", "toggle"], 0xF0594),
        ("Wallpaper al azar", "Cambia el fondo ahora", "fondo wallpaper aleatorio", [S + "/wallpaper.sh", "aleatorio"], 0xF0E09),
        ("Widgets de escritorio: mostrar u ocultar", "Reloj, clima y frase con el escritorio vacío", "widgets reloj escritorio", ["qs", "ipc", "call", "escritorio", "toggle"], 0xF0570),
        *[(f"Energía: {n}", d, "energia bateria perfil " + k, ["powerprofilesctl", "set", v], 0xF0425)
          for n, d, v, k in [("ahorro", "Más batería, menos potencia", "power-saver", "ahorro"),
                             ("equilibrado", "Lo normal", "balanced", "normal"),
                             ("rendimiento", "Máxima potencia (con cargador)", "performance", "potencia rapido")]],
        *[(f"Modo juego: {n}", d, "juego gaming " + n, [esc, "juego", v], 0xF0297)
          for n, d, v in [("automático", "Se activa solo con un juego abierto", "automatico"), ("siempre", "Activado ya", "si"), ("nunca", "Desactivado", "no")]],
        *[(f"Replay: {n}", "Últimos 30 s de pantalla en memoria", "replay grabar clip " + k, [esc, "replay", v], 0xF044A)
          for n, v, k in [("automático", "auto", "auto"), ("encender", "start", "on"), ("apagar", "stop", "off")]],
        *[(f"Sonido de las bocinas: {n}", d, "sonido audio ecualizador easyeffects " + k, [S + "/sonido.sh", v], 0xF057E)
          for n, d, v, k in [("música", "Más cuerpo y brillo", "Portatil", "musica"), ("voz", "Clases, vídeos y llamadas", "Voz", "voz"),
                             ("sin efectos", "EasyEffects apagado", "off", "off")]],
        *[(f"Filtro de pantalla: {n}", "Shader de Hyprland · SUPER+ALT+S", "filtro shader " + k, hd(f'shader.poner("{v}")'), 0xF03D8)
          for n, v, k in [("ninguno", "", "quitar normal"), ("grises", "grises", "blanco negro"), ("papel", "papel", "sepia"),
                          ("vivo", "vivo", "saturado"), ("invertido", "invertido", "negativo")]],
        ("Wi-Fi: encender", "Radio Wi-Fi", "wifi red internet", ["nmcli", "radio", "wifi", "on"], 0xF05A9),
        ("Wi-Fi: apagar", "Radio Wi-Fi", "wifi red internet avion", ["nmcli", "radio", "wifi", "off"], 0xF05AA),
        ("Bluetooth: encender", "Adaptador Bluetooth", "bluetooth audifonos", ["bluetoothctl", "power", "on"], 0xF00AF),
        ("Bluetooth: apagar", "Adaptador Bluetooth", "bluetooth audifonos", ["bluetoothctl", "power", "off"], 0xF00B2),
        ("Contexto automático: pausar", "Brújula: nada cambia solo", "brujula contexto reglas automatico pausa", [bru, "pausar"], 0xF0493),
        ("Contexto automático: reanudar", "Brújula: el escritorio se adapta solo", "brujula contexto reglas automatico", [bru, "reanudar"], 0xF0493),
        ("Editar reglas de Brújula", "~/.config/hypr/brujula.json", "brujula contexto reglas linea capturas configuracion",
         ["kitty", "--class", "scratch-notas", "-e", "nvim", str(HOME / ".config/hypr/brujula.json")], 0xF03EB),
    ]
    try:   # las reglas de contexto, una a una
        reglas = json.loads((HOME / ".config/hypr/brujula.json").read_text()).get("reglas", [])
        off = json.loads((Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula/preferencias.json").read_text()).get("desactivadas", [])
    except (OSError, ValueError):
        reglas, off = [], []
    for r in reglas:
        if isinstance(r, dict) and re.fullmatch(r"[\w-]{1,40}", str(r.get("id", ""))):
            apagada = r["id"] in off
            A.append((f"Regla «{r.get('nombre', r['id'])}»: " + ("activar" if apagada else "desactivar"), "Contexto automático de Brújula",
                      "regla contexto brujula " + str(r.get("nombre", "")), [bru, "regla", r["id"], "on" if apagada else "off"], 0xF0493))
    for plugin, nombre, detalle in [("kdeconnect_clipboard", "Portapapeles compartido con el móvil", "portapapeles copiar pegar"),
                                    ("kdeconnect_notifications", "Avisos del móvil en el PC", "notificaciones whatsapp"),
                                    ("kdeconnect_sendnotifications", "Avisos del PC en el móvil", "notificaciones"),
                                    ("kdeconnect_pausemusic", "Pausar la música con las llamadas", "llamada telefono musica")]:
        for v, t in (("on", "activar"), ("off", "desactivar")):
            A.append((f"{nombre}: {t}", "PC + móvil (KDE Connect)", "movil celular telefono kdeconnect " + detalle, [mov, "funcion", plugin, v], 0xF011C))
    res = []
    for nombre, detalle, claves, cmd, glifo in A:
        if coincide(q, nombre, claves):
            res.append({"nombre": nombre, "detalle": detalle + " · Enter: aplicar", "glifo": glifo, "cmd": cmd})
    return res[:12]


GRUPOS = [("ajustes", "Ajustes"), ("ventanas", "Ventanas"), ("documentos", "Documentos"), ("notas", "Notas"), ("historial", "Visitado en Firefox"),
          ("linea", "Línea de tiempo"), ("atajos", "Atajos"), ("portapapeles", "Portapapeles")]


def todo(q):
    """Todas las fuentes en paralelo; lo que tarde más de 1,5 s se queda fuera (el lanzador no espera)."""
    from concurrent.futures import ThreadPoolExecutor, wait
    if len(q.strip()) < 3:
        return []
    funciones = {"ajustes": ajustes, "ventanas": ventanas, "documentos": documentos, "notas": notas, "historial": historial,
                 "linea": linea, "atajos": atajos, "portapapeles": portapapeles}
    ex = ThreadPoolExecutor(len(funciones))
    futuros = {k: ex.submit(f, q) for k, f in funciones.items()}
    wait(futuros.values(), timeout=1.5)
    res = []
    for clave, titulo in GRUPOS:
        f = futuros[clave]
        if not f.done() or f.exception():
            continue
        for x in [x for x in f.result() if x.get("cmd")][:4]:
            x["grupo"] = titulo
            res.append(x)
    ex.shutdown(wait=False, cancel_futures=True)
    return res


TIPOS = {"ventanas": ventanas, "notas": notas, "portapapeles": portapapeles, "pestanas": pestanas, "claves": claves,
         "documentos": documentos, "historial": historial, "atajos": atajos, "linea": linea, "todo": todo, "ajustes": ajustes}

if __name__ == "__main__":
    tipo = sys.argv[1] if len(sys.argv) > 1 else ""
    q = " ".join(sys.argv[2:])
    try:
        print(json.dumps(TIPOS[tipo](q), ensure_ascii=False))
    except Exception as e:   # nunca dejar el lanzador sin respuesta
        print(json.dumps([{"nombre": "Error al buscar", "detalle": str(e)[:120], "glifo": 0xF0026, "cmd": []}]))
