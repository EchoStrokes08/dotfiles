#!/usr/bin/env python3
"""Escribir en tu Google Calendar / Google Tasks desde el dashboard (Eventos.qml) y el lanzador.

La lectura de eventos sigue siendo eventos.py (dirección iCal secreta); esto solo crea eventos y
tareas, lista las tareas pendientes y las marca como hechas. Solo biblioteca estándar.

Archivos PRIVADOS (no van al repo):
    ~/.config/calendario/cliente.json   credencial OAuth «App de escritorio» de Google Cloud
    ~/.config/calendario/token.json     tu sesión (la crea --conectar)

    gcal.py conectar                               abre el navegador una vez para dar permiso
    gcal.py estado                                 {"cliente": bool, "conectado": bool}
    gcal.py evento "Título" 2026-11-14 [15:00] [60] evento (sin hora = todo el día; duración en min)
    gcal.py tarea "Título" [2026-11-14]            tarea en tu lista principal de Google Tasks
    gcal.py tareas                                 JSON de las tareas pendientes
    gcal.py hecha <id>                             marca una tarea como completada
Todas imprimen JSON; los errores salen como {"ok": false, "error": "…"} (código 1).
"""
import base64
import datetime as dt
import hashlib
import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CONF = os.path.expanduser("~/.config/calendario")
CLIENTE = os.path.join(CONF, "cliente.json")
TOKEN = os.path.join(CONF, "token.json")
# Eventos recién creados: el feed iCal de Google tarda en reflejarlos, así que eventos.py los mezcla
# desde aquí hasta que aparecen en el feed (o terminan).
CREADOS = os.path.expanduser("~/.cache/calendario/creados.json")
SCOPES = "https://www.googleapis.com/auth/calendar.events https://www.googleapis.com/auth/tasks"
CAL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
TASKS = "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks"


class Error(Exception):
    pass


def _leer(ruta, defecto=None):
    try:
        with open(ruta) as f:
            return json.load(f)
    except (OSError, ValueError):
        return defecto


def _guardar(ruta, datos, privado=False):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    tmp = ruta + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600 if privado else 0o644)
    with os.fdopen(fd, "w") as f:
        json.dump(datos, f, ensure_ascii=False)
    os.replace(tmp, ruta)


def cliente():
    c = _leer(CLIENTE)
    c = (c or {}).get("installed") or (c or {}).get("web")
    if not c:
        raise Error(f"Falta la credencial de Google en {CLIENTE}")
    return c


def _post_form(url, datos):
    req = urllib.request.Request(url, data=urllib.parse.urlencode(datos).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise Error(f"Google rechazó el inicio de sesión: {e.read().decode(errors='replace')[:200]}") from e


# ── Iniciar sesión (OAuth para apps de escritorio: loopback + PKCE) ────────────────────────────────
def conectar(abrir=True):
    c = cliente()
    verificador = secrets.token_urlsafe(64)
    reto = base64.urlsafe_b64encode(hashlib.sha256(verificador.encode()).digest()).rstrip(b"=").decode()
    estado = secrets.token_urlsafe(16)
    recibido = {}

    class Manejador(http.server.BaseHTTPRequestHandler):
        def do_GET(self):  # noqa: N802
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" not in q and "error" not in q:
                self.send_response(404); self.end_headers(); return
            recibido.update({k: v[0] for k, v in q.items()})
            ok = "code" in q and q.get("state", [""])[0] == estado
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(("<h2>Listo, ya puedes cerrar esta pestaña.</h2>" if ok else
                              "<h2>No se pudo conectar. Vuelve a intentarlo.</h2>").encode())

        def log_message(self, *a):
            pass

    srv = http.server.HTTPServer(("127.0.0.1", 0), Manejador)
    redirect = f"http://127.0.0.1:{srv.server_port}"
    url = c["auth_uri"] + "?" + urllib.parse.urlencode({
        "client_id": c["client_id"], "redirect_uri": redirect, "response_type": "code", "scope": SCOPES,
        "code_challenge": reto, "code_challenge_method": "S256", "state": estado,
        "access_type": "offline", "prompt": "consent"})
    print("Abre esta dirección si el navegador no se abre solo:\n" + url, file=sys.stderr)
    if abrir:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    srv.timeout = 300
    fin = time.time() + 300
    while not recibido and time.time() < fin:
        srv.handle_request()
    srv.server_close()
    if recibido.get("state") != estado or "code" not in recibido:
        raise Error("No se completó el permiso: " + recibido.get("error", "se acabó el tiempo"))
    t = _post_form(c["token_uri"], {
        "client_id": c["client_id"], "client_secret": c["client_secret"], "code": recibido["code"],
        "code_verifier": verificador, "grant_type": "authorization_code", "redirect_uri": redirect})
    t["expira"] = time.time() + t.get("expires_in", 3600) - 60
    _guardar(TOKEN, t, privado=True)
    return {"ok": True}


def acceso():
    t = _leer(TOKEN)
    if not t or "refresh_token" not in t:
        raise Error("No has conectado tu cuenta de Google: ejecuta gcal.py conectar")
    if t.get("expira", 0) > time.time():
        return t["access_token"]
    c = cliente()
    try:
        n = _post_form(c["token_uri"], {"client_id": c["client_id"], "client_secret": c["client_secret"],
                                        "refresh_token": t["refresh_token"], "grant_type": "refresh_token"})
    except Error as e:
        raise Error("La sesión de Google caducó: vuelve a ejecutar gcal.py conectar") from e
    t.update(n)
    t["expira"] = time.time() + n.get("expires_in", 3600) - 60
    _guardar(TOKEN, t, privado=True)
    return t["access_token"]


def api(metodo, url, cuerpo=None):
    req = urllib.request.Request(url, method=metodo, data=json.dumps(cuerpo).encode() if cuerpo is not None else None,
                                 headers={"Authorization": "Bearer " + acceso(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            datos = r.read()
            return json.loads(datos) if datos else {}
    except urllib.error.HTTPError as e:
        detalle = e.read().decode(errors="replace")
        try:
            detalle = json.loads(detalle)["error"]["message"]
        except (ValueError, KeyError, TypeError):
            pass
        raise Error(f"Google respondió {e.code}: {str(detalle)[:200]}") from e
    except urllib.error.URLError as e:
        raise Error(f"Sin conexión con Google ({e.reason})") from e


# ── Eventos ────────────────────────────────────────────────────────────────────────────────────────
def cuerpo_evento(titulo, fecha, hora=None, minutos=60):
    """fecha 'YYYY-MM-DD', hora 'HH:MM' o None (todo el día) → (cuerpo para la API, inicio, fin)."""
    titulo = titulo.strip()
    if not titulo:
        raise Error("El evento necesita un título")
    d = dt.date.fromisoformat(fecha)
    if not hora:
        ini = dt.datetime.combine(d, dt.time()).astimezone()
        fin = ini + dt.timedelta(days=1)
        return ({"summary": titulo, "start": {"date": d.isoformat()},
                 "end": {"date": (d + dt.timedelta(days=1)).isoformat()}}, ini, fin, True)
    h, m = (int(x) for x in hora.split(":"))
    ini = dt.datetime.combine(d, dt.time(h, m)).astimezone()
    fin = ini + dt.timedelta(minutes=max(int(minutos), 5))
    return ({"summary": titulo, "start": {"dateTime": ini.isoformat()}, "end": {"dateTime": fin.isoformat()}},
            ini, fin, False)


def crear_evento(titulo, fecha, hora=None, minutos=60):
    cuerpo, ini, fin, todo_dia = cuerpo_evento(titulo, fecha, hora, minutos)
    ev = api("POST", CAL, cuerpo)
    creados = [c for c in _leer(CREADOS, []) or [] if dt.datetime.fromisoformat(c["fin"]) > dt.datetime.now().astimezone()]
    creados.append({"uid": ev.get("iCalUID", ev.get("id", "") + "@google.com"), "inicio": ini.isoformat(),
                    "fin": fin.isoformat(), "titulo": cuerpo["summary"], "lugar": "", "todoDia": todo_dia})
    _guardar(CREADOS, creados)
    return {"ok": True, "id": ev.get("id"), "enlace": ev.get("htmlLink", "")}


# ── Tareas ─────────────────────────────────────────────────────────────────────────────────────────
def crear_tarea(titulo, fecha=None):
    titulo = titulo.strip()
    if not titulo:
        raise Error("La tarea necesita un título")
    cuerpo = {"title": titulo}
    if fecha:  # Google Tasks solo guarda el día: la hora se ignora
        cuerpo["due"] = dt.date.fromisoformat(fecha).isoformat() + "T00:00:00.000Z"
    t = api("POST", TASKS, cuerpo)
    return {"ok": True, "id": t.get("id")}


def tareas():
    """Pendientes, ordenadas por fecha (las que no tienen fecha, al final)."""
    res, pagina = [], None
    while True:
        q = {"showCompleted": "false", "showHidden": "false", "maxResults": "100"}
        if pagina:
            q["pageToken"] = pagina
        r = api("GET", TASKS + "?" + urllib.parse.urlencode(q))
        for t in r.get("items", []):
            if t.get("status") == "completed" or not t.get("title", "").strip():
                continue
            res.append({"id": t["id"], "titulo": t["title"], "fecha": (t.get("due") or "")[:10]})
        pagina = r.get("nextPageToken")
        if not pagina:
            break
    return sorted(res, key=lambda t: t["fecha"] or "9999")


def hecha(id_):
    api("PATCH", f"{TASKS}/{urllib.parse.quote(id_)}", {"status": "completed"})
    return {"ok": True}


def estado():
    t = _leer(TOKEN) or {}
    return {"cliente": os.path.exists(CLIENTE), "conectado": "refresh_token" in t}


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    orden, args = argv[0], argv[1:]
    try:
        if orden == "conectar":
            res = conectar()
        elif orden == "estado":
            res = estado()
        elif orden == "evento" and len(args) >= 2:
            res = crear_evento(args[0], args[1], args[2] if len(args) > 2 and args[2] else None,
                               int(args[3]) if len(args) > 3 and args[3] else 60)
        elif orden == "tarea" and args:
            res = crear_tarea(args[0], args[1] if len(args) > 1 and args[1] else None)
        elif orden == "tareas":
            res = tareas()
        elif orden == "hecha" and args:
            res = hecha(args[0])
        else:
            print(__doc__)
            return 2
    except (Error, ValueError) as e:
        print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        return 1
    print(json.dumps(res, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
