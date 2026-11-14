#!/usr/bin/env python3
"""Memoria personal: buscar POR SIGNIFICADO en lo tuyo. Todo local (ollama), nada sale del equipo.

Qué recuerda (en trozos, cada uno con su «vector de significado»):
  · documentos   PDF, Word, LibreOffice y apuntes de Documents, Desktop y Downloads (como indice.py)
  · línea        tu línea de tiempo de Brújula, día a día: qué apps, qué títulos y qué archivos
  · web          las páginas que visitaste en Firefox (título y dirección, últimos 90 días)
  (el portapapeles NO: puede tener contraseñas)

La búsqueda mezcla el parecido de significado (embeddings) con las palabras exactas (FTS5), así
encuentra «lo de las redes virtuales» aunque el apunte diga «VLAN», y también «VLAN» a secas.

    memoria.py indexar [--max N]     actualizar (incremental; lo lanza brujula.py cada 30 min)
    memoria.py buscar "pregunta"     JSON: los trozos más parecidos, con su fuente
    memoria.py estado                cuántos trozos hay de cada tipo
    memoria.py resumen               estado + tamaño, última actualización, pausa, exclusiones y lo más guardado
    memoria.py fuentes TIPO [texto]  fuentes guardadas (web | documento | linea), con sus trozos
    memoria.py olvidar CLAVE         borrar una fuente y no volver a guardarla · recordar CLAVE la permite otra vez
    memoria.py excluir dominio|carpeta VALOR · incluir dominio|carpeta VALOR
    memoria.py pausar · reanudar · borrar-todo
Modelo de embeddings: ~/.config/ia/embeddings (de serie: embeddinggemma).
"""
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import time
import urllib.request

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import indice  # noqa: E402

HOME = Path.home()
DB = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "brujula" / "memoria.db"
OLLAMA = "http://127.0.0.1:11434"
TROZO, SOLAPE = 900, 150
DIAS_WEB, DIAS_LINEA = 90, 60
# Lo que la persona decide desde Agente › Memoria: pausa, dominios y carpetas excluidos, fuentes olvidadas
AJUSTES = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "brujula" / "memoria-ajustes.json"


def ajustes():
    try:
        a = json.loads(AJUSTES.read_text())
    except (OSError, ValueError):
        a = {}
    return {"pausada": bool(a.get("pausada")), "dominios": list(a.get("dominios", [])),
            "carpetas": list(a.get("carpetas", [])), "olvidadas": list(a.get("olvidadas", []))}


def guardar_ajustes(a):
    AJUSTES.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = AJUSTES.with_suffix(".tmp")
    tmp.write_text(json.dumps(a, ensure_ascii=False, indent=1))
    os.replace(tmp, AJUSTES)


def dominio(url):
    m = re.match(r"^https?://(?:www\.)?([^/?#:]+)", url or "", re.I)
    return m.group(1).lower() if m else ""


def excluida(clave, a=None):
    """¿La persona pidió no guardar esta fuente (olvidada, de un dominio o de una carpeta excluidos)?"""
    a = a or ajustes()
    if clave in a["olvidadas"]:
        return True
    if clave.startswith("web:"):
        d = dominio(clave[4:])
        return any(d == x or d.endswith("." + x) for x in a["dominios"])
    if clave.startswith("doc:"):
        ruta = clave[4:]
        return any(ruta == c or ruta.startswith(c.rstrip("/") + "/") for c in a["carpetas"])
    return False


def modelo():
    try:
        return (HOME / ".config/ia/embeddings").read_text().strip() or "embeddinggemma"
    except OSError:
        return "embeddinggemma"


def vectores(textos, consulta=False):
    """Embeddings normalizados (float32). embeddinggemma rinde mejor con estos prefijos."""
    if not textos:
        return np.zeros((0, 0), dtype=np.float32)
    pref = "task: search result | query: " if consulta else "title: none | text: "
    salida = []
    for i in range(0, len(textos), 24):
        cuerpo = json.dumps({"model": modelo(), "input": [pref + t[:2000] for t in textos[i:i + 24]],
                             "keep_alive": "5m", "truncate": True}).encode()
        req = urllib.request.Request(OLLAMA + "/api/embed", cuerpo, {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=300) as r:
            salida += json.loads(r.read())["embeddings"]
    m = np.asarray(salida, dtype=np.float32)
    return m / np.maximum(np.linalg.norm(m, axis=1, keepdims=True), 1e-9)


def conectar(solo_leer=False):
    if solo_leer:
        return sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)
    DB.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    c = sqlite3.connect(DB, timeout=10)
    c.executescript("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS fuentes(clave TEXT PRIMARY KEY, firma TEXT);
        CREATE TABLE IF NOT EXISTS trozos(id INTEGER PRIMARY KEY, clave TEXT, tipo TEXT, titulo TEXT,
                                          ref TEXT, fecha INTEGER, texto TEXT, emb BLOB);
        CREATE INDEX IF NOT EXISTS trozos_clave ON trozos(clave);
        CREATE VIRTUAL TABLE IF NOT EXISTS trozos_fts USING fts5(titulo, texto, content='trozos', content_rowid='id',
                                                                  tokenize='unicode61 remove_diacritics 2');
        CREATE TRIGGER IF NOT EXISTS t_ai AFTER INSERT ON trozos BEGIN
            INSERT INTO trozos_fts(rowid, titulo, texto) VALUES (new.id, new.titulo, new.texto); END;
        CREATE TRIGGER IF NOT EXISTS t_ad AFTER DELETE ON trozos BEGIN
            INSERT INTO trozos_fts(trozos_fts, rowid, titulo, texto) VALUES ('delete', old.id, old.titulo, old.texto); END;
    """)
    return c


def trocear(texto):
    """Trozos de ~900 caracteres que respetan párrafos, con un poco de solape para no cortar ideas."""
    texto = re.sub(r"[ \t]+", " ", texto)
    texto = re.sub(r"\n{3,}", "\n\n", texto).strip()
    res, i = [], 0
    while i < len(texto) and len(res) < 300:
        fin = min(len(texto), i + TROZO)
        if fin < len(texto):
            corte = max(texto.rfind("\n", i + TROZO // 2, fin), texto.rfind(". ", i + TROZO // 2, fin))
            fin = corte + 1 if corte > i else fin
        trozo = texto[i:fin].strip()
        if len(trozo) > 40:
            res.append(trozo)
        i = max(fin - SOLAPE, i + 1) if fin < len(texto) else fin
    return res


# ── fuentes ──────────────────────────────────────────────────────────────
def fuente_documentos():
    for p in indice.archivos():
        try:
            st = p.stat()
        except OSError:
            continue
        if st.st_size > indice.MAX_BYTES:
            continue
        yield (f"doc:{p}", f"{st.st_mtime}:{st.st_size}",
               lambda p=p, st=st: [("documento", p.name, str(p), int(st.st_mtime), t) for t in trocear(indice.extraer(p))])


def fuente_linea():
    import brujula
    hoy = dt.date.today()
    for n in range(DIAS_LINEA):
        dia = hoy - dt.timedelta(days=n)
        f = brujula.LINEA / f"{dia.isoformat()}.jsonl"
        if not f.exists():
            continue
        st = f.stat()

        def leer(dia=dia):
            nombre = f"{brujula.DIAS[dia.weekday()]} {dia:%d/%m/%Y}"
            lineas = []
            for b in brujula.bloques(dia, vivo=False):
                if b["fin"] - b["inicio"] < 60:
                    continue
                h = lambda t: dt.datetime.fromtimestamp(t).strftime("%H:%M")
                titulos = "; ".join(b["titulos"][-4:]) if b["titulos"] else ("(privado)" if b["privado"] else "")
                lineas.append(f"{h(b['inicio'])}–{h(b['fin'])} {b['nombre']}" + (f" [{b['contexto']}]" if b["contexto"] else "")
                              + (f": {titulos}" if titulos else ""))
            for a in brujula.archivos_del_dia(dia):
                lineas.append(f"{dt.datetime.fromtimestamp(a['t']):%H:%M} abrió el archivo {a['nombre']} ({a['ruta']})")
            texto = "\n".join(sorted(lineas))
            t0 = int(dt.datetime.combine(dia, dt.time(12)).timestamp())
            return [("linea", f"Línea de tiempo del {nombre}", dia.isoformat(), t0, f"Actividad del {nombre}:\n{t}")
                    for t in trocear(texto)]
        yield (f"linea:{dia.isoformat()}", f"{st.st_mtime}:{st.st_size}", leer)


# Páginas que no se guardan: resultados de buscadores (ruido), cuentas y contraseñas, bandejas de correo
# (el título de la pestaña es el asunto del mensaje), chats temporales o de incógnito y cualquier dirección
# que lleve un correo electrónico.
NO_WEB_URL = re.compile(r"(login|signin|sign-in|log-in|password|contrasen|contraseñ|recuperar|reset|token=|auth|oauth|/checkout"
                        r"|incognito|temporary-chat|private=|privado"     # chats temporales: la intención era no dejar rastro
                        r"|@|%40|^https?://(accounts|login|auth|id|myaccount)\.|^https?://mail\.|^https?://outlook\.(live|office)"
                        r"|^https?://(www\.)?(google\.[a-z.]+/search|bing\.com/search|duckduckgo\.com/\?|search\.brave\.com|youtube\.com/results))", re.I)
NO_WEB_TITULO = re.compile(r"(iniciar sesi[oó]n|sign ?in|log ?in|inbox|bandeja de entrada|recuperar contrase|reset password"
                           r"|[\w.+-]+@[\w-]+\.[\w.]+)", re.I)


def web_util(url, titulo):
    """¿Vale la pena recordar esta página? Nunca cuentas, correo ni resultados de búsqueda."""
    return not NO_WEB_URL.search(url) and not NO_WEB_TITULO.search(titulo or "")


def fuente_web():
    desde = (time.time() - DIAS_WEB * 86400) * 1_000_000
    for db in (HOME / ".config/mozilla/firefox").glob("*/places.sqlite"):
        try:
            c = sqlite3.connect(f"file:{db}?immutable=1", uri=True, timeout=2)
            filas = c.execute("SELECT url, title, last_visit_date FROM moz_places WHERE hidden = 0 AND title IS NOT NULL "
                              "AND title != '' AND url LIKE 'http%' AND last_visit_date > ? ORDER BY frecency DESC LIMIT 3000",
                              (desde,)).fetchall()
            c.close()
        except sqlite3.Error:
            continue
        for url, titulo, visita in filas:
            if not web_util(url, titulo):
                continue
            limpia = url.split("#")[0]
            yield (f"web:{limpia}", titulo,
                   lambda u=limpia, t=titulo, v=visita: [("web", t, u, int(v / 1_000_000),
                                                         f"Página visitada en Firefox: {t} — {re.sub(r'^https?://(www[.])?', '', u)[:160]}")])


FUENTES = {"documentos": fuente_documentos, "linea": fuente_linea, "web": fuente_web}


def indexar(maximo=None):
    """Incremental: solo trocea y vectoriza lo que cambió. Devuelve un resumen."""
    DB.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with open(DB.parent / "memoria.lock", "w") as cerrojo:
        try:
            fcntl.flock(cerrojo, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return {"mensaje": "Ya se está indexando."}
        a = ajustes()
        if a["pausada"]:
            return {"mensaje": "La memoria está en pausa."}
        c = conectar()
        firmas = dict(c.execute("SELECT clave, firma FROM fuentes"))
        vistas, nuevos, hechos = set(), 0, 0
        pendientes = []
        for fuente in FUENTES.values():
            for clave, firma, leer in fuente():
                if excluida(clave, a):
                    continue        # no se guarda; si ya estaba, se borra abajo («borradas»)
                vistas.add(clave)
                if firmas.get(clave) != firma:
                    pendientes.append((clave, firma, leer))
        # por lotes: muchas fuentes pequeñas (páginas web) se vectorizan juntas, que es mucho más rápido
        lote = []

        def volcar():
            nonlocal nuevos, hechos
            textos = [f"{t}\n{x}" for _, _, filas in lote for _, t, _, _, x in filas]
            embs = vectores(textos) if textos else []
            i = 0
            with c:
                for clave, firma, filas in lote:
                    c.execute("DELETE FROM trozos WHERE clave = ?", (clave,))
                    for tipo, titulo, ref, fecha, texto in filas:
                        c.execute("INSERT INTO trozos(clave, tipo, titulo, ref, fecha, texto, emb) VALUES (?,?,?,?,?,?,?)",
                                  (clave, tipo, titulo, ref, fecha, texto, np.asarray(embs[i], dtype=np.float32).tobytes()))
                        i += 1
                    c.execute("INSERT OR REPLACE INTO fuentes VALUES (?, ?)", (clave, firma))
                    nuevos += len(filas)
                    hechos += 1
            lote.clear()

        try:
            for clave, firma, leer in pendientes[:maximo] if maximo else pendientes:
                try:
                    lote.append((clave, firma, leer()))
                except (OSError, ValueError, KeyError):
                    continue
                if sum(len(x[2]) for x in lote) >= 48:
                    volcar()
            volcar()
        except OSError as e:
            if "refused" in str(e).lower():
                return {"mensaje": "ollama no responde: no se pudo indexar."}
            raise
        borradas = [k for k in firmas if k not in vistas]
        with c:
            for k in borradas:
                c.execute("DELETE FROM trozos WHERE clave = ?", (k,))
                c.execute("DELETE FROM fuentes WHERE clave = ?", (k,))
        c.close()
    return {"fuentes_actualizadas": hechos, "trozos_nuevos": nuevos, "borradas": len(borradas),
            "pendientes": max(0, len(pendientes) - hechos)}


def buscar(pregunta, k=8, tipos=None):
    """Mezcla significado y palabras (fusión por rango recíproco). [{tipo, titulo, ref, fecha, texto, puntos}]"""
    if not DB.exists() or not pregunta.strip():
        return []
    c = conectar(solo_leer=True)
    filtro = f" WHERE tipo IN ({','.join('?' * len(tipos))})" if tipos else ""
    filas = c.execute("SELECT id, tipo, titulo, ref, fecha, texto, emb FROM trozos" + filtro, tipos or []).fetchall()
    if not filas:
        return []
    puntos = {}
    try:
        q = vectores([pregunta], consulta=True)[0]
        matriz = np.frombuffer(b"".join(f[6] for f in filas), dtype=np.float32).reshape(len(filas), -1)
        sim = matriz @ q
        for rango, i in enumerate(np.argsort(-sim)[:40]):
            puntos[filas[i][0]] = puntos.get(filas[i][0], 0) + 1 / (60 + rango) + float(sim[i]) * 0.02
    except (OSError, ValueError):
        pass   # sin ollama: solo palabras
    palabras = [w for w in re.findall(r"\w+", pregunta) if len(w) > 2][:10]
    if palabras:
        consulta = " OR ".join('"' + w.replace('"', "") + '"*' for w in palabras)
        try:
            for rango, (i,) in enumerate(c.execute("SELECT rowid FROM trozos_fts WHERE trozos_fts MATCH ? ORDER BY rank LIMIT 40", (consulta,))):
                puntos[i] = puntos.get(i, 0) + 1 / (60 + rango)
        except sqlite3.Error:
            pass
    c.close()
    por_id = {f[0]: f for f in filas}
    mejores = sorted((i for i in puntos if i in por_id), key=lambda i: -puntos[i])
    res, vistos = [], set()
    for i in mejores:
        f = por_id[i]
        if (f[3], f[5][:80]) in vistos:
            continue
        vistos.add((f[3], f[5][:80]))
        res.append({"tipo": f[1], "titulo": f[2], "ref": f[3], "fecha": f[4], "texto": f[5], "puntos": round(puntos[i], 4)})
        if len(res) >= k:
            break
    return res


def _borrar(c, condicion, args):
    claves = [k for (k,) in c.execute("SELECT DISTINCT clave FROM trozos WHERE " + condicion, args)]
    with c:
        for k in claves:
            c.execute("DELETE FROM trozos WHERE clave = ?", (k,))
            c.execute("DELETE FROM fuentes WHERE clave = ?", (k,))
    return len(claves)


def resumen():
    r = estado()
    a = ajustes()
    tam = sum(f.stat().st_size for f in DB.parent.glob(DB.name + "*")) if DB.exists() else 0
    r.update({"bytes": tam, "actualizado": int(DB.stat().st_mtime) if DB.exists() else 0, "pausada": a["pausada"],
              "dominios": a["dominios"], "carpetas": a["carpetas"], "olvidadas": len(a["olvidadas"]),
              "dias_web": DIAS_WEB, "dias_linea": DIAS_LINEA, "top": {"web": [], "documento": []}})
    if DB.exists():
        c = conectar(solo_leer=True)
        cuenta = {}
        for (ref,) in c.execute("SELECT ref FROM trozos WHERE tipo = 'web'"):
            d = dominio(ref)
            cuenta[d] = cuenta.get(d, 0) + 1
        r["top"]["web"] = [{"nombre": d, "trozos": n} for d, n in sorted(cuenta.items(), key=lambda x: -x[1])[:8]]
        cuenta = {}
        for (ref,) in c.execute("SELECT ref FROM trozos WHERE tipo = 'documento'"):
            carpeta = str(Path(ref).parent)
            cuenta[carpeta] = cuenta.get(carpeta, 0) + 1
        r["top"]["documento"] = [{"nombre": d.replace(str(HOME), "~", 1), "ruta": d, "trozos": n}
                                 for d, n in sorted(cuenta.items(), key=lambda x: -x[1])[:8]]
        c.close()
    return r


def fuentes(tipo, texto="", limite=60):
    """Fuentes guardadas de un tipo, las más recientes primero: [{clave, titulo, ref, fecha, trozos}]."""
    if not DB.exists():
        return []
    c = conectar(solo_leer=True)
    filtro, args = "tipo = ?", [tipo]
    if texto.strip():
        filtro += " AND (titulo LIKE ? OR ref LIKE ?)"
        args += [f"%{texto.strip()}%"] * 2
    filas = c.execute("SELECT clave, max(titulo), max(ref), max(fecha), count(*) FROM trozos WHERE " + filtro +
                      " GROUP BY clave ORDER BY max(fecha) DESC LIMIT ?", args + [limite]).fetchall()
    c.close()
    return [{"clave": k, "titulo": t, "ref": r, "fecha": f, "trozos": n, "dominio": dominio(r) if tipo == "web" else ""}
            for k, t, r, f, n in filas]


def olvidar(clave):
    a = ajustes()
    if clave not in a["olvidadas"]:
        a["olvidadas"].append(clave)
        guardar_ajustes(a)
    n = _borrar(conectar(), "clave = ?", [clave]) if DB.exists() else 0
    return {"ok": True, "mensaje": "Olvidada: no se volverá a guardar.", "borradas": n, "deshacer": clave}


def recordar(clave):
    a = ajustes()
    a["olvidadas"] = [k for k in a["olvidadas"] if k != clave]
    guardar_ajustes(a)
    return {"ok": True, "mensaje": "Se volverá a guardar en la próxima actualización."}


def excluir(clase, valor, quitar=False):
    if clase not in ("dominio", "carpeta"):
        raise ValueError("Se excluye un dominio o una carpeta")
    valor = valor.strip()
    if clase == "dominio":
        valor = dominio(valor) if "://" in valor else valor.lower().removeprefix("www.")
    else:
        valor = str(Path(os.path.expanduser(valor)).resolve())
    if not valor:
        raise ValueError("Falta el dominio o la carpeta")
    a = ajustes()
    lista = a["dominios" if clase == "dominio" else "carpetas"]
    if quitar:
        lista[:] = [x for x in lista if x != valor]
        guardar_ajustes(a)
        return {"ok": True, "mensaje": f"«{valor}» se volverá a guardar en la próxima actualización."}
    if valor not in lista:
        lista.append(valor)
    guardar_ajustes(a)
    n = 0
    if DB.exists():
        c = conectar()
        claves = [k for (k,) in c.execute("SELECT DISTINCT clave FROM trozos")]
        borrar = [k for k in claves if excluida(k, a)]
        with c:
            for k in borrar:
                c.execute("DELETE FROM trozos WHERE clave = ?", (k,))
                c.execute("DELETE FROM fuentes WHERE clave = ?", (k,))
        n = len(borrar)
    return {"ok": True, "mensaje": f"«{valor}» excluido: {n} fuentes borradas y no se volverán a guardar.", "borradas": n}


def pausar(si=True):
    a = ajustes()
    a["pausada"] = si
    guardar_ajustes(a)
    return {"ok": True, "mensaje": "Memoria en pausa: no guarda nada nuevo." if si else "Memoria activa otra vez."}


def borrar_todo():
    for f in DB.parent.glob(DB.name + "*"):
        f.unlink()
    return {"ok": True, "mensaje": "Memoria borrada. Se reconstruirá en la próxima actualización si no está en pausa."}


def estado():
    if not DB.exists():
        return {"trozos": 0, "por_tipo": {}}
    c = conectar(solo_leer=True)
    por = dict(c.execute("SELECT tipo, count(*) FROM trozos GROUP BY tipo"))
    c.close()
    return {"trozos": sum(por.values()), "por_tipo": por, "modelo": modelo(), "base": str(DB)}


if __name__ == "__main__":
    orden = sys.argv[1] if len(sys.argv) > 1 else "estado"
    if orden == "indexar":
        maximo = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[2] == "--max" else None
        inicio = time.time()
        r = indexar(maximo)
        r["segundos"] = round(time.time() - inicio, 1)
        print(json.dumps(r, ensure_ascii=False))
    elif orden == "buscar":
        print(json.dumps(buscar(" ".join(sys.argv[2:])), ensure_ascii=False))
    elif orden in ("resumen", "fuentes", "olvidar", "recordar", "excluir", "incluir", "pausar", "reanudar", "borrar-todo"):
        a = sys.argv[2:]
        try:
            r = (resumen() if orden == "resumen" else fuentes(a[0], " ".join(a[1:])) if orden == "fuentes"
                 else olvidar(a[0]) if orden == "olvidar" else recordar(a[0]) if orden == "recordar"
                 else excluir(a[0], " ".join(a[1:]), quitar=orden == "incluir") if orden in ("excluir", "incluir")
                 else pausar(orden == "pausar") if orden in ("pausar", "reanudar") else borrar_todo())
        except (IndexError, ValueError, OSError, sqlite3.Error) as e:
            r = {"ok": False, "error": str(e) or "Faltan datos"}
        print(json.dumps(r, ensure_ascii=False))
        sys.exit(0 if not isinstance(r, dict) or r.get("ok", True) else 1)
    else:
        print(json.dumps(estado(), ensure_ascii=False))
