#!/usr/bin/env python3
"""Brújula: el escritorio que se anticipa. Tres cosas en un solo servicio que escucha a Hyprland:

  1. Contexto automático   reglas en ~/.config/hypr/brujula.json: al usar VS Code → perfil lectura y
                           No molestar; con un juego abierto → modo juego; batería baja → ahorro…
                           Al terminar, todo vuelve a como estaba (salvo lo que cambiaste a mano).
  2. Línea de tiempo       qué app (y qué título) tenías delante y cuándo. Local, en
                           ~/.local/state/brujula/linea/AAAA-MM-DD.jsonl; nada con la privacidad activa.
  3. Sesión que vuelve     cada minuto guarda qué apps hay abiertas y en qué espacio. Al iniciar
                           sesión (tras reiniciar o un cuelgue) ofrece abrirlas otra vez.

Uso
  brujula.py vigilar                    el servicio (lo arranca modulos/autostart.lua)
  brujula.py estado                     JSON: reglas, cuáles están activas, pausa
  brujula.py pausar | reanudar          todo el contexto automático
  brujula.py regla <id> on|off          activar o desactivar una regla
  brujula.py linea [--dia AAAA-MM-DD]   JSON: bloques del día y resumen por app
  brujula.py sesion [restaurar [--solo 0,2] | descartar]
  brujula.py abrir [hoy|linea|contexto|sesion]   panel de Quickshell (SUPER+CTRL+B)
"""
import argparse
import datetime as dt
import fcntl
import fnmatch
import json
import os
from pathlib import Path
import re
import select
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "hypr" / "brujula.json"
ESTADO = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula"
LINEA = ESTADO / "linea"
CAPTURAS = ESTADO / "capturas"
DIAS = ["lun", "mar", "mie", "jue", "vie", "sab", "dom"]
PERFILES = {"cristal", "lectura", "minimo", "rendimiento"}
ENERGIAS = {"power-saver", "balanced", "performance"}
TERMINALES = {"kitty"}
ESTABLE = 4         # s que algo debe seguir igual para contar en la línea (filtra el alt-tab rápido)
CONFIRMAR = 4       # s que una regla debe cumplirse antes de activarse (sin parpadeos)


# ── utilidades ────────────────────────────────────────────────────────────
def ejecutar(args, timeout=4):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def lanzar(args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def atomico(ruta, datos):
    ruta.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=ruta.parent, prefix=".brujula-")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(datos, f, ensure_ascii=False, indent=1)
        os.replace(tmp, ruta)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def leer_json(ruta, defecto):
    try:
        return json.loads(Path(ruta).read_text())
    except (OSError, ValueError):
        return defecto


def config():
    c = leer_json(CONFIG, {})
    if not isinstance(c, dict):
        c = {}
    c.setdefault("reglas", [])
    c["reglas"] = [r for r in c["reglas"] if isinstance(r, dict) and re.fullmatch(r"[\w-]{1,40}", str(r.get("id", "")))]
    for k in ("linea", "sesion", "sugerencias"):
        if not isinstance(c.get(k), dict):
            c[k] = {}
    return c


def preferencias():
    p = leer_json(ESTADO / "preferencias.json", {})
    return {"pausado": bool(p.get("pausado")), "desactivadas": [x for x in p.get("desactivadas", []) if isinstance(x, str)],
            "aviso": p.get("aviso", "")}


def guardar_preferencias(p):
    atomico(ESTADO / "preferencias.json", p)


def coincide(clase, patrones):
    c = (clase or "").lower()
    return any(fnmatch.fnmatchcase(c, str(p).lower()) for p in patrones or [])


def escritorio():
    """El estado que publica modulos/escritorio.lua (perfil, privacidad, juego…)."""
    runtime, firma = os.environ.get("XDG_RUNTIME_DIR", ""), os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not runtime or not re.fullmatch(r"[\w-]+", firma):
        return {}
    try:
        lineas = Path(runtime, f"hypr-escritorio-{firma}.state").read_text().splitlines()
    except OSError:
        return {}
    return dict(l.split("=", 1) for l in lineas if "=" in l)


def despachar(expr):
    return ejecutar(["hyprctl", "dispatch", expr + " or hl.dsp.no_op()"])


def osd(texto, icono="f03d8"):
    lanzar(["qs", "ipc", "call", "osd", "mensaje", texto.replace("'", "’"), icono])


# ── nombres e iconos de las apps (archivos .desktop) ─────────────────────
_ESCRITORIO = None


def apps_instaladas():
    global _ESCRITORIO
    if _ESCRITORIO is not None:
        return _ESCRITORIO
    por_id, por_clase = {}, {}
    carpetas = [HOME / ".local/share/applications", Path("/usr/share/applications"),
                HOME / ".local/share/flatpak/exports/share/applications", Path("/var/lib/flatpak/exports/share/applications")]
    for carpeta in carpetas:
        for f in sorted(carpeta.glob("*.desktop")) if carpeta.is_dir() else []:
            ident = f.name[:-8]
            if ident.lower() in por_id:
                continue
            datos, seccion = {}, ""
            try:
                for linea in f.read_text(errors="replace").splitlines():
                    if linea.startswith("["):
                        seccion = linea.strip()
                        continue
                    if seccion != "[Desktop Entry]" or "=" not in linea:
                        continue
                    k, v = linea.split("=", 1)
                    if k in ("Name", "Name[es]", "Icon", "StartupWMClass", "NoDisplay", "Type"):
                        datos[k] = v.strip()
            except OSError:
                continue
            if datos.get("Type", "Application") != "Application":
                continue
            e = {"id": ident, "nombre": datos.get("Name[es]") or datos.get("Name") or ident, "icono": datos.get("Icon", ""),
                 "oculta": datos.get("NoDisplay") == "true"}
            por_id[ident.lower()] = e
            if datos.get("StartupWMClass"):
                por_clase.setdefault(datos["StartupWMClass"].lower(), e)
    _ESCRITORIO = (por_id, por_clase)
    return _ESCRITORIO


def app_de(clase):
    por_id, por_clase = apps_instaladas()
    c = (clase or "").lower()
    e = por_clase.get(c) or por_id.get(c)
    if not e:   # «org.gnome.Nautilus» ↔ «nautilus», «spotify» ↔ «com.spotify.Client»
        e = next((v for k, v in por_id.items() if not v["oculta"] and (k.split(".")[-1] == c or c.split(".")[-1] == k)), None)
    return e


def nombre_de(clase):
    e = app_de(clase)
    if e:
        return e["nombre"]
    # «com-cburch-logisim-Main» → «Logisim»; «org.vinegarhq.Sober» → «Sober»
    ruido = {"com", "org", "io", "dev", "net", "github", "main", "app", "client", "desktop", "gtk", "qt"}
    partes = [x for x in re.split(r"[-._]", clase or "") if x and x.lower() not in ruido and not x.isdigit()]
    limpio = partes[-1] if partes else (clase or "?")
    return limpio[:1].upper() + limpio[1:]


# ── 1. Contexto automático ───────────────────────────────────────────────
def bateria():
    """(porcentaje, cargando) o (None, True) en un equipo sin batería."""
    base = Path("/sys/class/power_supply")
    pct, cargando = None, False
    for d in base.glob("*") if base.is_dir() else []:
        try:
            tipo = (d / "type").read_text().strip()
            if tipo == "Battery" and (d / "capacity").exists():
                pct = int((d / "capacity").read_text())
                cargando = cargando or (d / "status").read_text().strip() in ("Charging", "Full", "Not charging")
            elif tipo == "Mains" and (d / "online").read_text().strip() == "1":
                cargando = True
        except (OSError, ValueError):
            continue
    return pct, (cargando if pct is not None else True)


def en_horario(rango, ahora):
    try:
        a, b = (dt.time.fromisoformat(x) for x in rango)
    except (TypeError, ValueError):
        return False
    t = ahora.time()
    return a <= t < b if a <= b else (t >= a or t < b)


def describir(regla):
    """La condición de una regla en palabras (para el panel)."""
    si, partes = regla.get("si", {}), []
    if si.get("apps"):
        alias = {"steam_app_*": "juegos de Steam", "*.exe": "juegos de Windows", "jetbrains-*": "JetBrains"}
        nombres = [alias.get(a) or (nombre_de(a) if "*" not in a else a.replace("*", "…")) for a in si["apps"][:3]]
        modo = "con" if si.get("modo") == "abierta" else "usando"
        partes.append(f"{modo} {', '.join(nombres)}" + ("…" if len(si["apps"]) > 3 else ""))
    if "bateria_menor" in si:
        partes.append(f"batería < {si['bateria_menor']} %")
    if si.get("cargando") is False:
        partes.append("sin cargador")
    if si.get("pantalla_externa"):
        partes.append("con pantalla externa")
    if si.get("hora"):
        partes.append(f"de {si['hora'][0]} a {si['hora'][1]}")
    if si.get("dias"):
        partes.append(", ".join(si["dias"]))
    ent, efectos = regla.get("entonces", {}), []
    if ent.get("perfil"):
        efectos.append("perfil " + ent["perfil"])
    if ent.get("no_molestar"):
        efectos.append("No molestar")
    if ent.get("energia"):
        efectos.append({"power-saver": "ahorro de energía", "performance": "máximo rendimiento", "balanced": "energía equilibrada"}.get(ent["energia"], ent["energia"]))
    if ent.get("juego"):
        efectos.append("modo juego")
    return {"cuando": " · ".join(partes) or "siempre", "hace": " · ".join(efectos) or "solo lo indica"}


class Contexto:
    """Decide qué reglas están activas y aplica/deshace sus efectos sin pisar los cambios manuales."""

    def __init__(self):
        self.foco_visto = {}     # id de regla → última vez que su app tuvo el foco
        self.cumple_desde = {}   # id → desde cuándo se cumple (para CONFIRMAR)
        self.activas = []        # ids, en el orden del archivo
        self.desde = {}
        self.ruta = ESTADO / "aplicado.json"
        guardado = leer_json(self.ruta, {})
        # Lo que dejó aplicado una ejecución anterior (si el servicio se reinició, sigue sabiendo qué deshacer)
        self.aplicado = guardado.get("aplicado", {}) if guardado.get("instancia") == os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") else {}

    def evaluar(self, reglas, foco, clases, monitores, ahora):
        pct, cargando = bateria()
        hoy = DIAS[ahora.weekday()]
        cumplen = []
        for r in reglas:
            si = r.get("si", {})
            ok = True
            if si.get("apps"):
                if si.get("modo") == "abierta":
                    ok = any(coincide(c, si["apps"]) for c in clases)
                else:
                    delante = coincide(foco, si["apps"])
                    if delante:
                        self.foco_visto[r["id"]] = time.time()
                    gracia = float(si.get("gracia", 3)) * 60
                    # delante ahora, o hace menos de «gracia» minutos y sigue abierta
                    ok = delante or (time.time() - self.foco_visto.get(r["id"], 0) <= gracia
                                     and any(coincide(c, si["apps"]) for c in clases))
            if ok and "bateria_menor" in si:
                ok = pct is not None and pct < float(si["bateria_menor"])
            if ok and "cargando" in si:
                ok = cargando == bool(si["cargando"])
            if ok and "pantalla_externa" in si:
                ok = (monitores > 1) == bool(si["pantalla_externa"])
            if ok and si.get("hora"):
                ok = en_horario(si["hora"], ahora)
            if ok and si.get("dias"):
                ok = hoy in si["dias"]
            if ok:
                self.cumple_desde.setdefault(r["id"], time.time())
                # entrar exige unos segundos; si ya estaba activa, sigue sin esperar
                if r["id"] in self.activas or time.time() - self.cumple_desde[r["id"]] >= CONFIRMAR:
                    cumplen.append(r)
            else:
                self.cumple_desde.pop(r["id"], None)
        return cumplen

    def aplicar(self, cumplen):
        nuevas = [r["id"] for r in cumplen]
        entran = [r for r in cumplen if r["id"] not in self.activas]
        for r in entran:
            self.desde[r["id"]] = time.time()
        for ident in self.activas:
            if ident not in nuevas:
                self.desde.pop(ident, None)
        self.activas = nuevas

        quiere = {}   # efecto → valor (gana la regla de más arriba)
        for r in cumplen:
            ent = r.get("entonces", {})
            if ent.get("perfil") in PERFILES:
                quiere.setdefault("perfil", ent["perfil"])
            if ent.get("energia") in ENERGIAS:
                quiere.setdefault("energia", ent["energia"])
            if ent.get("no_molestar") is True:
                quiere.setdefault("no_molestar", True)
            if ent.get("juego") is True:
                quiere.setdefault("juego", "si")

        e = escritorio()
        actual = {"perfil": e.get("perfil"), "juego": e.get("juego"), "no_molestar": self.aplicado.get("no_molestar", {}).get("puesto"),
                  "energia": ejecutar(["powerprofilesctl", "get"], 2) if ("energia" in quiere or "energia" in self.aplicado) else None}
        cambio = False
        for efecto in ("perfil", "energia", "juego", "no_molestar"):
            antes = self.aplicado.get(efecto)
            if efecto in quiere:
                valor = quiere[efecto]
                if antes is None:
                    self.aplicado[efecto] = {"previo": actual[efecto], "puesto": valor}
                elif antes["puesto"] == valor:
                    continue
                else:
                    antes["puesto"] = valor
                self.poner(efecto, valor)
                cambio = True
            elif antes is not None:
                # Deshacer solo si nadie lo cambió a mano mientras tanto
                if efecto == "no_molestar" or actual[efecto] == antes["puesto"]:
                    self.poner(efecto, antes["previo"], deshacer=True)
                del self.aplicado[efecto]
                cambio = True
        if entran:   # después de los efectos: el OSD del perfil no lo tapa
            if cambio:
                time.sleep(0.6)
            osd("Contexto: " + str(entran[0].get("nombre", entran[0]["id"])), str(entran[0].get("icono", "f03d8")))
        if cambio:
            atomico(self.ruta, {"instancia": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"), "aplicado": self.aplicado})

    @staticmethod
    def poner(efecto, valor, deshacer=False):
        if efecto == "perfil" and valor in PERFILES:
            despachar(f'escritorio.perfil("{valor}")')
        elif efecto == "energia" and valor in ENERGIAS:
            ejecutar(["powerprofilesctl", "set", valor])
        elif efecto == "juego":
            despachar(f'escritorio.juego("{valor if valor in ("si", "no", "automatico") else "automatico"}")')
        elif efecto == "no_molestar":
            lanzar(["qs", "ipc", "call", "notificaciones", "motivo", "contexto", "false" if deshacer else "true"])

    def soltar_todo(self):
        self.activas, self.cumple_desde = [], {}
        self.aplicar([])


# ── 2. Línea de tiempo ───────────────────────────────────────────────────
class Linea:
    def __init__(self):
        self.actual = None        # (clase, título) delante ahora
        self.actual_desde = 0
        self.escrito = None
        self.pausa = False
        self.ultima_captura = 0

    def ver(self, clase, titulo):
        if (clase, titulo) != self.actual:
            self.actual, self.actual_desde = (clase, titulo), time.time()

    def escribir(self, registro):
        LINEA.mkdir(mode=0o700, parents=True, exist_ok=True)
        dia = dt.date.fromtimestamp(registro["t"]).isoformat()
        with open(LINEA / f"{dia}.jsonl", "a") as f:
            f.write(json.dumps(registro, ensure_ascii=False) + "\n")

    def tick(self, cfg, bloqueado, privado, contexto):
        if not cfg.get("guardar", True):
            return
        if bloqueado:
            if not self.pausa:
                self.escribir({"t": int(time.time()), "e": "pausa"})
                self.pausa, self.escrito = True, None
            return
        if self.actual is None or self.actual == self.escrito or time.time() - self.actual_desde < ESTABLE:
            return
        clase, titulo = self.actual
        if not clase:
            return
        r = {"t": int(self.actual_desde), "c": clase}
        privada = re.search(r"(Private Browsing|Navegación privada|Incognito|Incógnito)", titulo or "", re.I)
        if privado or privada or coincide(clase, cfg.get("sin_titulo", [])):
            r["p"] = 1
        elif cfg.get("titulos", True) and titulo:
            r["ti"] = titulo[:200]
        if contexto:
            r["x"] = contexto
        self.escribir(r)
        self.escrito, self.pausa = self.actual, False

    def capturar(self, cfg, bloqueado, privado):
        if not cfg.get("capturas") or bloqueado or privado or not shutil.which("grim") or not shutil.which("openssl"):
            return
        cada = max(1, float(cfg.get("capturas_cada_min", 10))) * 60
        if time.time() - self.ultima_captura < cada:
            return
        self.ultima_captura = time.time()
        threading.Thread(target=captura_cifrada, daemon=True).start()

    @staticmethod
    def limpiar(cfg):
        hoy = dt.date.today()
        for f in LINEA.glob("*.jsonl") if LINEA.is_dir() else []:
            try:
                if (hoy - dt.date.fromisoformat(f.stem)).days > int(cfg.get("dias", 30)):
                    f.unlink()
            except ValueError:
                pass
        shutil.rmtree(visor(), ignore_errors=True)
        for d in CAPTURAS.iterdir() if CAPTURAS.is_dir() else []:
            try:
                if (hoy - dt.date.fromisoformat(d.name)).days > int(cfg.get("capturas_dias", 7)):
                    shutil.rmtree(d)
            except ValueError:
                pass


# ── capturas: CIFRADAS en disco (AES-256 con una clave guardada en el anillo de claves de la sesión) ──
# Sin el anillo desbloqueado (tu contraseña de inicio de sesión) nadie puede verlas, ni con el disco en la mano.
# Para mirarlas se descifran en $XDG_RUNTIME_DIR (memoria, se borra al cerrar sesión) y se borran al cerrar el panel.
ATRIBUTOS = ["app", "brujula", "tipo", "capturas"]


def clave_capturas(crear=True):
    clave = ejecutar(["secret-tool", "lookup", *ATRIBUTOS], 5)
    if clave or not crear:
        return clave
    import secrets
    nueva = secrets.token_hex(32)
    try:
        subprocess.run(["secret-tool", "store", "--label=Brújula: clave de las capturas", *ATRIBUTOS],
                       input=nueva, text=True, capture_output=True, timeout=10, check=True)
    except (OSError, subprocess.SubprocessError):
        return ""
    return ejecutar(["secret-tool", "lookup", *ATRIBUTOS], 5)   # solo vale si de verdad quedó guardada


def openssl(modo, clave, entrada, salida):
    args = ["openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "20000", "-pass", "env:BRUJULA_CLAVE"]
    if modo == "descifrar":
        args.append("-d")
    return subprocess.run(args + ["-out", str(salida)], input=entrada, capture_output=True, timeout=30,
                          env=dict(os.environ, BRUJULA_CLAVE=clave)).returncode == 0


def captura_cifrada():
    """Nunca toca el disco sin cifrar: grim escribe a la tubería y openssl cifra."""
    clave = clave_capturas()
    if not clave:
        return   # sin anillo de claves no hay capturas (mejor ninguna que en claro)
    ahora = dt.datetime.now()
    carpeta = CAPTURAS / ahora.date().isoformat()
    carpeta.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        imagen = subprocess.run(["grim", "-t", "jpeg", "-q", "55", "-s", "0.4", "-"], capture_output=True, timeout=15).stdout
    except (OSError, subprocess.SubprocessError):
        return
    if imagen:
        destino = carpeta / ahora.strftime("%H%M%S.jpg.enc")
        if openssl("cifrar", clave, imagen, destino):
            os.chmod(destino, 0o600)
        else:
            destino.unlink(missing_ok=True)


def visor():
    runtime = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    return Path(runtime) / "brujula-capturas"


def capturas_del_dia(dia):
    """Descifra las capturas del día a memoria (solo para mirarlas) y devuelve sus rutas."""
    origen = CAPTURAS / dia.isoformat()
    cifradas = sorted(origen.glob("*.jpg.enc")) if origen.is_dir() else []
    if not cifradas:
        return []
    clave = clave_capturas(crear=False)
    if not clave:
        return []
    destino = visor() / dia.isoformat()
    destino.mkdir(mode=0o700, parents=True, exist_ok=True)
    res = []
    for f in cifradas[-48:]:
        claro = destino / f.name[:-4]
        if claro.exists() or openssl("descifrar", clave, f.read_bytes(), claro):
            res.append(str(claro))
    return res


# ── archivos abiertos (los apunta GTK/Qt en recently-used.xbel: qué app y cuándo) ──
def archivos_del_dia(dia):
    import xml.etree.ElementTree as ET
    from urllib.parse import unquote, urlparse
    try:
        raiz = ET.parse(HOME / ".local/share/recently-used.xbel").getroot()
    except (OSError, ET.ParseError):
        return []
    ns = {"bookmark": "http://www.freedesktop.org/standards/desktop-bookmarks"}
    res = []
    for b in raiz.iter("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"):
            continue
        ruta = unquote(urlparse(href).path)
        for app in b.iterfind(".//bookmark:application", ns):
            try:
                t = dt.datetime.fromisoformat(app.get("modified", "").replace("Z", "+00:00")).astimezone()
            except ValueError:
                continue
            if t.date() == dia:
                res.append({"t": int(t.timestamp()), "ruta": ruta, "nombre": os.path.basename(ruta),
                            "app": app.get("name", ""), "existe": os.path.exists(ruta)})
    return sorted(res, key=lambda x: x["t"])[-60:]


def leer_linea(dia):
    try:
        lineas = (LINEA / f"{dia.isoformat()}.jsonl").read_text().splitlines()
    except OSError:
        return []
    res = []
    for l in lineas:
        try:
            r = json.loads(l)
            if isinstance(r, dict) and isinstance(r.get("t"), int):
                res.append(r)
        except ValueError:
            pass
    return sorted(res, key=lambda r: r["t"])


def bloques(dia, vivo=True):
    """Agrupa los registros del día en bloques continuos de la misma app."""
    regs = leer_linea(dia)
    fin_dia = int(dt.datetime.combine(dia + dt.timedelta(days=1), dt.time()).timestamp())
    ahora = int(time.time())
    res = []
    for i, r in enumerate(regs):
        if r.get("e") == "pausa" or not r.get("c"):
            continue
        siguiente = regs[i + 1]["t"] if i + 1 < len(regs) else None
        if siguiente is None:
            # el último: si es hoy y el servicio vive, sigue en curso; si no, como mucho 15 min
            siguiente = min(ahora, fin_dia) if (vivo and dia == dt.date.today()) else min(r["t"] + 900, fin_dia)
        if siguiente <= r["t"]:
            continue
        titulo = "" if r.get("p") else r.get("ti", "")
        b = res[-1] if res else None
        if b and b["clase"] == r["c"] and r["t"] - b["fin"] <= 5:
            b["fin"] = siguiente
            if titulo and titulo not in b["titulos"]:
                b["titulos"].append(titulo)
            if r.get("x") and not b["contexto"]:
                b["contexto"] = r["x"]
        else:
            res.append({"inicio": r["t"], "fin": siguiente, "clase": r["c"], "titulos": [titulo] if titulo else [],
                        "privado": bool(r.get("p")), "contexto": r.get("x", "")})
    for b in res:
        b["nombre"] = nombre_de(b["clase"])
        b["icono"] = (app_de(b["clase"]) or {}).get("icono", "")
        b["titulos"] = b["titulos"][-6:]
    return res


def resumen_linea(dia):
    bs = bloques(dia)
    total = {}
    for b in bs:
        total[b["clase"]] = total.get(b["clase"], 0) + b["fin"] - b["inicio"]
    orden = sorted(total.items(), key=lambda x: -x[1])
    capturas = capturas_del_dia(dia)
    dias = sorted((f.stem for f in LINEA.glob("*.jsonl")), reverse=True) if LINEA.is_dir() else []
    return {"dia": dia.isoformat(), "bloques": bs, "capturas": capturas, "dias": dias[:30], "archivos": archivos_del_dia(dia),
            "resumen": [{"clase": c, "nombre": nombre_de(c), "segundos": s} for c, s in orden[:8]],
            "total": sum(total.values())}


# ── 3. Sesión que vuelve ─────────────────────────────────────────────────
def hijos(pid):
    try:
        return [int(x) for x in Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]
    except (OSError, ValueError):
        return []


def comando_de(w):
    """Cómo volver a abrir esta ventana: flatpak, terminal en su carpeta, su .desktop o su línea de órdenes."""
    pid, clase = w.get("pid", 0), w.get("class", "")
    try:
        cgroup = Path(f"/proc/{pid}/cgroup").read_text()
        m = re.search(r"app-flatpak-([A-Za-z0-9_.-]+?)-\d+\.scope", cgroup)
        if m:
            return ["flatpak", "run", m.group(1)]
        argv = [a for a in Path(f"/proc/{pid}/cmdline").read_text().split("\0") if a]
        exe = os.path.basename(os.readlink(f"/proc/{pid}/exe"))
    except OSError:
        return None
    if exe in TERMINALES or clase.lower() in TERMINALES:
        # la carpeta del shell que corre dentro (no la de kitty, que suele ser ~)
        carpeta = None
        for h in hijos(pid):
            try:
                carpeta = os.readlink(f"/proc/{h}/cwd")
                break
            except OSError:
                pass
        argv = argv or [exe]
        if carpeta and carpeta != str(HOME) and not any(a in ("-d", "--directory") or a.startswith("--directory=") for a in argv):
            argv = argv[:1] + ["--directory", carpeta] + argv[1:]
        return argv
    e = app_de(clase)
    if e and not e["oculta"] and shutil.which("gtk-launch"):
        return ["gtk-launch", e["id"]]
    if argv and (os.path.isabs(argv[0]) or shutil.which(argv[0])):
        return argv
    return None


def foto_sesion(cfg):
    try:
        ventanas = json.loads(ejecutar(["hyprctl", "-j", "clients"]) or "[]")
    except ValueError:
        return None
    try:
        pantallas = {m["id"]: m for m in json.loads(ejecutar(["hyprctl", "-j", "monitors"]) or "[]")}
    except (ValueError, KeyError, TypeError):
        pantallas = {}
    apps, por_clase = [], {}
    for w in sorted(ventanas, key=lambda w: (w.get("workspace", {}).get("id", 0), w.get("at", [0, 0]))):
        ws = w.get("workspace", {}).get("id", 0)
        clase = w.get("class", "")
        if not clase or not w.get("mapped", True) or not 1 <= ws <= 10 or coincide(clase, cfg.get("ignorar", [])):
            continue
        es_terminal = clase.lower() in TERMINALES or clase.startswith(("sesion-", "continuidad-"))
        if not es_terminal and clase in por_clase:   # una por app: abrirla dos veces suele duplicar
            continue
        argv = comando_de(w)
        if not argv:
            continue
        por_clase[clase] = True
        geo = None
        if w.get("floating"):   # las flotantes recuerdan tamaño y posición (relativa a su pantalla)
            m = pantallas.get(w.get("monitor"), {"x": 0, "y": 0})
            geo = {"x": int(w["at"][0] - m["x"]), "y": int(w["at"][1] - m["y"]), "w": int(w["size"][0]), "h": int(w["size"][1])}
        apps.append({"clase": clase, "nombre": nombre_de(clase), "icono": (app_de(clase) or {}).get("icono", ""),
                     "ws": ws, "argv": argv, "flotante": bool(w.get("floating")), "geo": geo,
                     "completa": bool(w.get("fullscreen")),
                     "titulo": "" if escritorio().get("privacidad_activa") == "true" else (w.get("title") or "")[:80]})
    return {"version": 1, "instancia": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""), "fecha": int(time.time()), "apps": apps[:40]}


def sesion_anterior():
    d = leer_json(ESTADO / "sesion-anterior.json", {})
    return d if d.get("version") == 1 and isinstance(d.get("apps"), list) else None


def reglas_ventana(a):
    """Reglas Lua para la ventana restaurada: su espacio y, si flotaba, su tamaño y posición.
    Solo números validados: nada del archivo llega a Lua como texto."""
    reglas = [f'workspace="{int(a["ws"])}"']
    g = a.get("geo")
    if a.get("flotante") and isinstance(g, dict) and all(type(g.get(k)) is int for k in ("x", "y", "w", "h")) \
            and 50 <= g["w"] <= 10000 and 50 <= g["h"] <= 10000 and -10000 <= g["x"] <= 10000 and -10000 <= g["y"] <= 10000:
        reglas += ["float=true", f'size="{g["w"]} {g["h"]}"', f'move="{g["x"]} {g["y"]}"']
    elif a.get("flotante"):
        reglas.append("float=true")
    if a.get("completa") is True:
        reglas.append("fullscreen=true")
    return "{" + ", ".join(reglas) + "}"


def restaurar(solo=None):
    d = sesion_anterior()
    if not d:
        return {"mensaje": "No hay una sesión anterior que restaurar."}
    try:
        abiertas = [w.get("class", "") for w in json.loads(ejecutar(["hyprctl", "-j", "clients"]) or "[]")]
    except ValueError:
        abiertas = []
    cuenta = {}
    for c in abiertas:
        cuenta[c] = cuenta.get(c, 0) + 1
    lanzadas = 0
    for i, a in enumerate(d["apps"]):
        if solo is not None and i not in solo:
            continue
        argv, ws, clase = a.get("argv"), a.get("ws"), a.get("clase", "")
        if not (isinstance(argv, list) and argv and all(isinstance(x, str) for x in argv)) or type(ws) is not int or not 1 <= ws <= 10:
            continue
        if cuenta.get(clase, 0) > 0:     # ya está abierta (p. ej. la terminal y Firefox del inicio)
            cuenta[clase] -= 1
            continue
        if not shutil.which(argv[0]):
            continue
        comando = json.dumps(shlex.join(argv), ensure_ascii=False)
        despachar(f"hl.dsp.exec_cmd({comando}, {reglas_ventana(a)})")
        lanzadas += 1
        time.sleep(0.15)
    if solo is None:
        (ESTADO / "sesion-anterior.json").unlink(missing_ok=True)
    return {"mensaje": f"Sesión restaurada: {lanzadas} apps abiertas en sus espacios." if lanzadas else "Todo lo de la sesión anterior ya estaba abierto."}


def ofrecer_sesion():
    d = sesion_anterior()
    if not d or not d["apps"]:
        return
    espacios = len({a["ws"] for a in d["apps"]})
    nombres = ", ".join(dict.fromkeys(a["nombre"] for a in d["apps"]))[:120]
    r = ejecutar(["notify-send", "-a", "Brújula", "-i", "view-refresh", "-A", "restaurar=Restaurar todo", "-A", "elegir=Elegir…",
                  f"¿Seguimos donde lo dejaste?", f"{len(d['apps'])} apps en {espacios} espacios: {nombres}"], timeout=3600)
    if r == "restaurar":
        osd(restaurar()["mensaje"], "f0e1b")
    elif r == "elegir":
        lanzar(["qs", "ipc", "call", "brujula", "abrir", "sesion"])


# ── concentración programada («de 9:00 a 10:30») ─────────────────────────
def programados():
    lista = leer_json(ESTADO / "programados.json", [])
    return [x for x in lista if isinstance(x, dict) and type(x.get("inicio")) is int and type(x.get("minutos")) is int]


def programar(inicio, minutos):
    if not 5 <= minutos <= 240:
        raise ValueError("La concentración dura entre 5 y 240 minutos")
    if inicio < time.time() - 60:
        raise ValueError("Esa hora ya pasó")
    fin = inicio + minutos * 60
    lista = [x for x in programados() if x["inicio"] + x["minutos"] * 60 > time.time()]
    if any(x["inicio"] < fin and inicio < x["inicio"] + x["minutos"] * 60 for x in lista):
        raise ValueError("Ya hay una concentración programada a esa hora")
    import secrets
    lista.append({"id": secrets.token_hex(4), "inicio": int(inicio), "minutos": int(minutos), "avisado": False})
    atomico(ESTADO / "programados.json", sorted(lista, key=lambda x: x["inicio"]))
    h = lambda t: dt.datetime.fromtimestamp(t).strftime("%H:%M")
    dia = "mañana " if dt.date.fromtimestamp(inicio) > dt.date.today() else ""
    texto = f"Concentración programada {dia}de {h(inicio)} a {h(fin)}"
    osd(texto, "f04fe")
    return {"mensaje": texto + ". Te aviso 5 min antes."}


def cancelar_programado(ident):
    lista = programados()
    nueva = [x for x in lista if x["id"] != ident]
    if len(nueva) == len(lista):
        raise ValueError("No existe esa concentración programada")
    atomico(ESTADO / "programados.json", nueva)
    return {"mensaje": "Concentración programada cancelada."}


def revisar_programados():
    """La llama el servicio en cada vuelta: avisa 5 min antes y empieza a su hora."""
    lista, cambio, ahora = programados(), False, time.time()
    for x in list(lista):
        if x["inicio"] - 300 <= ahora < x["inicio"] and not x.get("avisado"):
            x["avisado"], cambio = True, True
            lanzar(["notify-send", "-a", "Brújula", "-i", "appointment-soon", "En 5 minutos: concentración",
                    f"{x['minutos']} min sin distracciones. Ve cerrando lo que tengas a medias."])
        elif x["inicio"] <= ahora:
            lista.remove(x)
            cambio = True
            if ahora - x["inicio"] < 600:   # si el equipo estaba apagado a esa hora, no empezar tarde
                restante = max(5, x["minutos"] - int((ahora - x["inicio"]) // 60))
                lanzar(["qs", "ipc", "call", "concentracion", "empezar", str(restante)])
    if cambio:
        atomico(ESTADO / "programados.json", lista)


# ── el servicio ──────────────────────────────────────────────────────────
def bloqueado():
    r = ejecutar(["qs", "ipc", "call", "bloqueo", "estado"], 2)
    if r in ("bloqueado", "bloqueando"):
        return True
    return bool(ejecutar(["pgrep", "-x", "hyprlock"], 2))


def socket_eventos():
    runtime, firma = os.environ.get("XDG_RUNTIME_DIR", ""), os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(f"{runtime}/hypr/{firma}/.socket2.sock")
    return s


def publicar(ctx, reglas, prefs):
    """Lo que ve el panel: qué reglas hay y cuáles están activas ahora."""
    atomico(ESTADO / "activo.json", {
        "pausado": prefs["pausado"], "fecha": int(time.time()),
        "activas": [{"id": i, "desde": int(ctx.desde.get(i, time.time()))} for i in ctx.activas],
    })


def vigilar():
    ESTADO.mkdir(mode=0o700, parents=True, exist_ok=True)
    cerrojo = open(ESTADO / "servicio.lock", "w")
    try:
        fcntl.flock(cerrojo, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit("Brújula ya está en marcha.")
    firma = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")

    # La foto de la sesión que dejó otro arranque se convierte en «sesión anterior»
    foto = leer_json(ESTADO / "sesion.json", {})
    if foto.get("instancia") and foto.get("instancia") != firma and foto.get("apps") and time.time() - foto.get("fecha", 0) < 7 * 86400:
        os.replace(ESTADO / "sesion.json", ESTADO / "sesion-anterior.json")
        if config()["sesion"].get("ofrecer_al_iniciar", True):
            threading.Timer(10, ofrecer_sesion).start()

    ctx, linea = Contexto(), Linea()
    foco = ""
    clases, monitores = [], 1
    proxima_foto, proximo_bloqueo, proximo_indice, proxima_limpieza = time.time() + 20, 0, time.time() + 90, 0
    bloq = priv = False
    ultimo_publicado = None
    s, buf = None, b""
    ultimo_dia = dt.date.today()

    def refrescar_ventanas():
        nonlocal clases, monitores
        try:
            clases = [w.get("class", "") for w in json.loads(ejecutar(["hyprctl", "-j", "clients"]) or "[]") if w.get("mapped", True)]
            monitores = len(json.loads(ejecutar(["hyprctl", "-j", "monitors"]) or "[]")) or 1
        except ValueError:
            pass

    def foco_actual():
        nonlocal foco
        try:
            w = json.loads(ejecutar(["hyprctl", "-j", "activewindow"]) or "{}")
        except ValueError:
            w = {}
        foco = w.get("class", "")
        linea.ver(foco, w.get("title", ""))

    refrescar_ventanas()
    foco_actual()
    while True:
        if s is None:
            try:
                s, buf = socket_eventos(), b""
            except OSError:
                time.sleep(3)
                continue
        listos, _, _ = select.select([s], [], [], 2)
        if listos:
            datos = s.recv(65536)
            if not datos:   # Hyprland se fue (cierre de sesión): guardar la última foto y salir
                foto = foto_sesion(config()["sesion"])
                if foto and foto["apps"]:
                    atomico(ESTADO / "sesion.json", foto)
                return
            buf += datos
            *lineas, buf = buf.split(b"\n")
            for l in lineas:
                ev, _, val = l.decode(errors="replace").partition(">>")
                if ev == "activewindow":
                    clase, _, titulo = val.partition(",")
                    foco = clase
                    linea.ver(clase, titulo)
                elif ev in ("openwindow", "closewindow", "movewindowv2", "monitoradded", "monitorremoved"):
                    refrescar_ventanas()
                    proxima_foto = min(proxima_foto, time.time() + 5)
                elif ev == "windowtitle":
                    foco_actual()

        cfg = config()
        ahora = time.time()
        if ahora >= proximo_bloqueo:
            antes = bloq
            bloq, priv = bloqueado(), escritorio().get("privacidad_activa") == "true"
            proximo_bloqueo = ahora + 10
            if antes and not bloq:
                foco_actual()
                linea.escrito = None
        prefs = preferencias()
        reglas = [r for r in cfg["reglas"] if r["id"] not in prefs["desactivadas"]]
        if prefs["pausado"]:
            if ctx.activas or ctx.aplicado:
                ctx.soltar_todo()
        else:
            ctx.aplicar(ctx.evaluar(reglas, foco, clases, monitores, dt.datetime.now()))
        clave = (prefs["pausado"], tuple(ctx.activas))
        if clave != ultimo_publicado:
            publicar(ctx, reglas, prefs)
            ultimo_publicado = clave

        nombres = [str(r.get("nombre", r["id"])) for r in cfg["reglas"] if r["id"] in ctx.activas]
        linea.tick(cfg["linea"], bloq, priv, nombres[0] if nombres else "")
        linea.capturar(cfg["linea"], bloq, priv)

        revisar_programados()
        if ahora >= proxima_foto:
            foto = foto_sesion(cfg["sesion"])
            if foto and foto["apps"]:
                atomico(ESTADO / "sesion.json", foto)
            proxima_foto = ahora + 60
        if ahora >= proximo_indice:   # índice de documentos para la búsqueda universal (muy baja prioridad)
            indice = Path(__file__).with_name("indice.py")
            if indice.exists():
                lanzar(["nice", "-n", "19", "ionice", "-c", "3", sys.executable, "-I", str(indice)])
            proximo_indice = ahora + 1800
        if ahora >= proxima_limpieza:
            Linea.limpiar(cfg["linea"])
            proxima_limpieza = ahora + 6 * 3600
        # Sugerencias del día: un aviso amable la primera vez que usas el equipo cada mañana
        hoy = dt.date.today()
        if hoy != ultimo_dia or prefs["aviso"] != hoy.isoformat():
            ultimo_dia = hoy
            if (not bloq and dt.datetime.now().hour >= 6 and cfg["sugerencias"].get("aviso_matutino", True)
                    and prefs["aviso"] != hoy.isoformat() and escritorio().get("juego_activo") != "true"):
                prefs["aviso"] = hoy.isoformat()
                guardar_preferencias(prefs)
                threading.Thread(target=aviso_del_dia, daemon=True).start()


def aviso_del_dia():
    time.sleep(25)
    try:
        sys.path.insert(0, str(Path(__file__).parent))
        import sugerencias
        n = len(sugerencias.calcular()["sugerencias"])
    except Exception:
        n = 0
    if not n:
        return
    hora = dt.datetime.now().hour
    saludo = "Buenos días" if hora < 12 else "Buenas tardes" if hora < 19 else "Buenas noches"
    r = ejecutar(["notify-send", "-a", "Brújula", "-i", "compass", "-A", "ver=Ver mi día",
                  saludo, f"Tengo {n} {'idea' if n == 1 else 'ideas'} para hoy."], timeout=3600)
    if r == "ver":
        lanzar(["qs", "ipc", "call", "brujula", "abrir", "hoy"])


# ── órdenes para el panel ────────────────────────────────────────────────
def estado_json():
    cfg, prefs = config(), preferencias()
    activo = leer_json(ESTADO / "activo.json", {})
    desde = {a["id"]: a["desde"] for a in activo.get("activas", []) if isinstance(a, dict)}
    vivo = False
    if (ESTADO / "servicio.lock").exists():
        with open(ESTADO / "servicio.lock", "a") as f:
            try:
                fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                vivo = True   # el servicio lo tiene cogido
    reglas = []
    for r in cfg["reglas"]:
        d = describir(r)
        reglas.append({"id": r["id"], "nombre": str(r.get("nombre", r["id"])), "icono": str(r.get("icono", "f03d8")),
                       "cuando": d["cuando"], "hace": d["hace"], "activa": r["id"] in desde and not prefs["pausado"],
                       "desde": desde.get(r["id"], 0), "desactivada": r["id"] in prefs["desactivadas"]})
    return {"servicio": vivo, "pausado": prefs["pausado"], "reglas": reglas, "config": str(CONFIG),
            "linea": {"guardar": cfg["linea"].get("guardar", True), "titulos": cfg["linea"].get("titulos", True),
                      "capturas": bool(cfg["linea"].get("capturas")), "dias": cfg["linea"].get("dias", 30)}}


def sesion_json():
    d = sesion_anterior()
    actual = leer_json(ESTADO / "sesion.json", {})
    try:
        abiertas = {w.get("class", "") for w in json.loads(ejecutar(["hyprctl", "-j", "clients"]) or "[]")}
    except ValueError:
        abiertas = set()
    if d:
        for a in d["apps"]:
            a["abierta"] = a.get("clase") in abiertas
            a.pop("argv", None)
    return {"anterior": d, "foto": {"fecha": actual.get("fecha", 0), "apps": len(actual.get("apps", []))}}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="orden", required=True)
    sub.add_parser("vigilar")
    sub.add_parser("estado")
    sub.add_parser("pausar")
    sub.add_parser("reanudar")
    r = sub.add_parser("regla")
    r.add_argument("id")
    r.add_argument("valor", choices=["on", "off"])
    l = sub.add_parser("linea")
    l.add_argument("--dia", default="")
    s = sub.add_parser("sesion")
    s.add_argument("accion", nargs="?", default="ver", choices=["ver", "restaurar", "descartar"])
    s.add_argument("--solo", default="")
    pr = sub.add_parser("programar")
    pr.add_argument("--inicio", required=True, help="AAAA-MM-DDTHH:MM o HH:MM (hoy)")
    pr.add_argument("--minutos", type=int, default=90)
    sub.add_parser("programados")
    cp = sub.add_parser("cancelar")
    cp.add_argument("id")
    cap = sub.add_parser("capturas")
    cap.add_argument("accion", choices=["limpiar"])
    a = sub.add_parser("abrir")
    a.add_argument("pagina", nargs="?", default="hoy", choices=["hoy", "linea", "contexto", "sesion"])
    a = p.parse_args()

    if a.orden == "vigilar":
        vigilar()
    elif a.orden == "estado":
        print(json.dumps(estado_json(), ensure_ascii=False))
    elif a.orden in ("pausar", "reanudar"):
        prefs = preferencias()
        prefs["pausado"] = a.orden == "pausar"
        guardar_preferencias(prefs)
        print(json.dumps({"mensaje": "Contexto automático en pausa: nada cambiará solo." if prefs["pausado"] else "Contexto automático activo."}, ensure_ascii=False))
    elif a.orden == "regla":
        if not any(r["id"] == a.id for r in config()["reglas"]):
            raise ValueError("No existe esa regla")
        prefs = preferencias()
        prefs["desactivadas"] = [x for x in prefs["desactivadas"] if x != a.id] + ([a.id] if a.valor == "off" else [])
        guardar_preferencias(prefs)
        print(json.dumps({"mensaje": "Regla " + ("activada" if a.valor == "on" else "desactivada")}, ensure_ascii=False))
    elif a.orden == "linea":
        dia = dt.date.fromisoformat(a.dia) if a.dia else dt.date.today()
        if escritorio().get("privacidad_activa") == "true":
            print(json.dumps({"dia": dia.isoformat(), "privado": True, "bloques": [], "resumen": [], "capturas": [], "dias": [], "total": 0}))
        else:
            print(json.dumps(resumen_linea(dia), ensure_ascii=False))
    elif a.orden == "sesion":
        if a.accion == "ver":
            print(json.dumps(sesion_json(), ensure_ascii=False))
        elif a.accion == "descartar":
            (ESTADO / "sesion-anterior.json").unlink(missing_ok=True)
            print(json.dumps({"mensaje": "Sesión anterior descartada."}, ensure_ascii=False))
        else:
            solo = {int(x) for x in a.solo.split(",") if x.strip().isdigit()} if a.solo else None
            print(json.dumps(restaurar(solo), ensure_ascii=False))
    elif a.orden == "programar":
        texto = a.inicio if "T" in a.inicio else dt.date.today().isoformat() + "T" + a.inicio
        print(json.dumps(programar(int(dt.datetime.fromisoformat(texto).timestamp()), a.minutos), ensure_ascii=False))
    elif a.orden == "programados":
        print(json.dumps(programados(), ensure_ascii=False))
    elif a.orden == "cancelar":
        print(json.dumps(cancelar_programado(a.id), ensure_ascii=False))
    elif a.orden == "capturas":
        shutil.rmtree(visor(), ignore_errors=True)
        print(json.dumps({"mensaje": ""}))
    elif a.orden == "abrir":
        lanzar(["qs", "ipc", "call", "brujula", "abrir", a.pagina])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
