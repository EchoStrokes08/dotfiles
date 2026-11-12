#!/usr/bin/env python3
"""Índice del CONTENIDO de tus documentos para la búsqueda universal del lanzador (SUPER+R).

Lee PDF (pdftotext), Word/LibreOffice/PowerPoint (docx, odt, pptx, odp) y texto (md, txt, tex…) de
~/Documents, ~/Desktop y ~/Downloads, y lo guarda en una base SQLite FTS5 en ~/.cache/brujula/.
Es incremental: solo relee lo que cambió. Lo lanza brujula.py cada 30 min con prioridad mínima.

    indice.py               actualizar
    indice.py --buscar …    probar una búsqueda (JSON)
    indice.py --estado      cuántos documentos hay
"""
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time
import zipfile

HOME = Path.home()
DB = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "brujula" / "documentos.db"
RAICES = [HOME / "Documents", HOME / "Documentos", HOME / "Desktop", HOME / "Escritorio", HOME / "Downloads", HOME / "Descargas"]
TEXTO = {".md", ".txt", ".org", ".tex", ".rst", ".markdown", ".csv"}
OFIMATICA = {".docx": r"word/document\.xml", ".odt": r"content\.xml", ".pptx": r"ppt/slides/slide\d+\.xml",
             ".odp": r"content\.xml", ".ods": r"content\.xml"}
EXTENSIONES = TEXTO | set(OFIMATICA) | {".pdf"}
SALTAR = {"node_modules", ".git", "__pycache__", ".venv", "venv", ".cache", "target", "build"}
MAX_BYTES = 40 * 1024 * 1024
MAX_TEXTO = 400_000


def conectar():
    DB.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    c = sqlite3.connect(DB, timeout=5)
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("CREATE TABLE IF NOT EXISTS docs(ruta TEXT PRIMARY KEY, mtime REAL, tamano INTEGER)")
    c.execute("CREATE VIRTUAL TABLE IF NOT EXISTS contenido USING fts5(ruta UNINDEXED, nombre, texto, "
              "tokenize='unicode61 remove_diacritics 2')")
    return c


def extraer(ruta):
    ext = ruta.suffix.lower()
    if ext in TEXTO:
        return ruta.read_text(errors="replace")[:MAX_TEXTO]
    if ext == ".pdf":
        try:
            r = subprocess.run(["pdftotext", "-q", "-l", "80", "-enc", "UTF-8", str(ruta), "-"],
                               capture_output=True, text=True, timeout=30)
            return r.stdout[:MAX_TEXTO]
        except (OSError, subprocess.SubprocessError):
            return ""
    if ext in OFIMATICA:
        partes = []
        try:
            with zipfile.ZipFile(ruta) as z:
                for nombre in sorted(z.namelist()):
                    if re.fullmatch(OFIMATICA[ext], nombre):
                        xml = z.read(nombre).decode(errors="replace")
                        xml = re.sub(r"</(w:p|text:p|a:p|text:h)>", "\n", xml)
                        partes.append(re.sub(r"<[^>]+>", " ", xml))
        except (OSError, zipfile.BadZipFile, KeyError):
            return ""
        return re.sub(r"[ \t]+", " ", "\n".join(partes))[:MAX_TEXTO]
    return ""


def archivos():
    vistos = set()
    for raiz in RAICES:
        if not raiz.is_dir() or raiz.resolve() in vistos:
            continue
        vistos.add(raiz.resolve())
        for carpeta, dirs, nombres in os.walk(raiz):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in SALTAR]
            for n in nombres:
                p = Path(carpeta, n)
                if not n.startswith(".") and p.suffix.lower() in EXTENSIONES:
                    yield p


def actualizar():
    c = conectar()
    conocidos = dict(c.execute("SELECT ruta, mtime FROM docs"))
    presentes, nuevos = set(), 0
    for p in archivos():
        try:
            st = p.stat()
        except OSError:
            continue
        ruta = str(p)
        presentes.add(ruta)
        if st.st_size > MAX_BYTES or conocidos.get(ruta) == st.st_mtime:
            continue
        texto = extraer(p)
        with c:
            c.execute("DELETE FROM contenido WHERE ruta = ?", (ruta,))
            c.execute("INSERT INTO contenido(ruta, nombre, texto) VALUES (?, ?, ?)", (ruta, p.stem, texto))
            c.execute("INSERT OR REPLACE INTO docs VALUES (?, ?, ?)", (ruta, st.st_mtime, st.st_size))
        nuevos += 1
    borrados = [r for r in conocidos if r not in presentes]
    with c:
        for r in borrados:
            c.execute("DELETE FROM contenido WHERE ruta = ?", (r,))
            c.execute("DELETE FROM docs WHERE ruta = ?", (r,))
    c.close()
    return {"indexados": nuevos, "borrados": len(borrados), "total": len(presentes)}


def buscar(q, limite=8):
    """[(ruta, fragmento)] — cada palabra como prefijo: «simpl metod» encuentra «método simplex»."""
    palabras = [w for w in re.findall(r"\w+", q, re.UNICODE) if len(w) >= 2][:8]
    if not palabras or not DB.exists():
        return []
    consulta = " ".join('"' + w.replace('"', "") + '"*' for w in palabras)
    try:
        c = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=1)
        filas = c.execute("SELECT ruta, snippet(contenido, 2, '«', '»', '…', 10), "
                          "highlight(contenido, 1, '«', '»') FROM contenido WHERE contenido MATCH ? "
                          "ORDER BY bm25(contenido, 0, 6.0, 1.0) LIMIT ?", (consulta, limite)).fetchall()
        c.close()
    except sqlite3.Error:
        return []
    return [(r, re.sub(r"\s+", " ", s or "").strip()) for r, s, _ in filas]


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--buscar":
        print(json.dumps(buscar(" ".join(sys.argv[2:])), ensure_ascii=False, indent=1))
    elif len(sys.argv) > 1 and sys.argv[1] == "--estado":
        n = conectar().execute("SELECT count(*) FROM docs").fetchone()[0] if DB.exists() else 0
        print(json.dumps({"documentos": n, "base": str(DB)}))
    else:
        inicio = time.time()
        r = actualizar()
        r["segundos"] = round(time.time() - inicio, 1)
        print(json.dumps(r))
