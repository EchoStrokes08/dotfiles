#!/usr/bin/env python3
"""Sugerencias del día para Brújula (pestaña «Hoy»). Todo local: nada sale del equipo.

Mira tu tiempo de pantalla de ayer y de la semana, tus eventos y recordatorios de hoy, el
próximo paso de tu último proyecto, la línea de tiempo (qué sueles hacer a esta hora) y la
última copia de seguridad, y propone acciones de un clic.
El asistente local (ollama) solo redacta la frase de bienvenida; si no está, hay una frase fija.

    sugerencias.py          JSON con saludo, datos y sugerencias (instantáneo)
    sugerencias.py frase    la frase del asistente (puede tardar; se guarda para todo el día)
"""
import datetime as dt
import json
import os
from pathlib import Path
import sys
import urllib.request

sys.path.insert(0, str(Path(__file__).parent))
import brujula as b  # noqa: E402

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
SCRIPTS = Path(__file__).parent


def duracion(s):
    s = int(s)
    h, m = divmod(s // 60, 60)
    return f"{h} h {m:02d} min" if h else f"{m} min"


def tiempos(dia):
    return b.leer_json(STATE / "tiempo-pantalla" / f"{dia.isoformat()}.json", {})


def eventos_hoy():
    lista = b.leer_json(HOME / ".cache/calendario/eventos.json", [])
    hoy, res = dt.date.today(), []
    for e in lista if isinstance(lista, list) else []:
        try:
            inicio = dt.datetime.fromisoformat(e["inicio"])
        except (KeyError, ValueError, TypeError):
            continue
        if inicio.date() == hoy or (e.get("todoDia") and inicio.date() <= hoy < dt.datetime.fromisoformat(e["fin"]).date()):
            res.append({"titulo": e.get("titulo", ""), "hora": "" if e.get("todoDia") else inicio.strftime("%H:%M"),
                        "pasado": not e.get("todoDia") and inicio.astimezone() < dt.datetime.now().astimezone()})
    return res


def recordatorios_hoy():
    lista = b.leer_json(STATE / "quickshell/recordatorios.json", [])
    manana = dt.datetime.combine(dt.date.today() + dt.timedelta(days=1), dt.time()).timestamp() * 1000
    return [{"texto": r.get("texto", ""), "hora": dt.datetime.fromtimestamp(r["cuando"] / 1000).strftime("%H:%M")}
            for r in lista if isinstance(r, dict) and isinstance(r.get("cuando"), (int, float)) and r["cuando"] < manana]


def proyecto_reciente():
    d = b.leer_json(STATE / "mesa-trabajo/proyectos.json", {})
    p = next((x for x in d.get("proyectos", []) if x.get("id") == d.get("ultimo")), None)
    return p if p and p.get("siguiente") else None


def contexto_habitual(cfg):
    """¿Qué contexto sueles tener a esta hora? (los últimos 7 días, ±45 min)"""
    ahora = dt.datetime.now()
    votos = {}
    for n in range(1, 8):
        dia = ahora.date() - dt.timedelta(days=n)
        centro = dt.datetime.combine(dia, ahora.time()).timestamp()
        vistos = set()
        for r in b.leer_linea(dia):
            if r.get("x") and abs(r["t"] - centro) <= 45 * 60:
                vistos.add(r["x"])
        for x in vistos:
            votos[x] = votos.get(x, 0) + 1
    if not votos:
        return None
    nombre, veces = max(votos.items(), key=lambda x: x[1])
    regla = next((r for r in cfg["reglas"] if r.get("nombre") == nombre), None)
    return (regla, veces) if regla and veces >= 3 else None


DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]


def fecha_larga(d):
    return f"{DIAS[d.weekday()]} {d.day} de {MESES[d.month - 1]}"


def ocupado():
    """Tramos ya comprometidos: eventos con hora (hoy y mañana) y concentraciones programadas."""
    tramos = []
    for e in b.leer_json(HOME / ".cache/calendario/eventos.json", []) or []:
        try:
            if not e.get("todoDia"):
                tramos.append((dt.datetime.fromisoformat(e["inicio"]).timestamp(), dt.datetime.fromisoformat(e["fin"]).timestamp()))
        except (KeyError, ValueError, TypeError, AttributeError):
            pass
    tramos += [(x["inicio"], x["inicio"] + x["minutos"] * 60) for x in b.programados()]
    return tramos


def hueco_libre(minutos=90, ahora=None, tramos=None):
    """El próximo bloque libre: en punto o y media, entre las 7:00 y las 22:30; si hoy ya no cabe, mañana a las 9:00."""
    ahora = ahora or dt.datetime.now()
    tramos = ocupado() if tramos is None else tramos
    inicio = ahora + dt.timedelta(minutes=10)
    inicio = inicio.replace(second=0, microsecond=0) + dt.timedelta(minutes=(30 - inicio.minute % 30) % 30)
    for _ in range(20):
        if inicio.hour < 7:
            inicio = inicio.replace(hour=9, minute=0)
        fin = inicio + dt.timedelta(minutes=minutos)
        if fin > inicio.replace(hour=22, minute=30):
            inicio = (inicio + dt.timedelta(days=1)).replace(hour=9, minute=0)
            continue
        choque = [f for i, f in tramos if i < fin.timestamp() and inicio.timestamp() < f]
        if not choque:
            return inicio
        t = dt.datetime.fromtimestamp(max(choque))
        inicio = t.replace(second=0, microsecond=0) + dt.timedelta(minutes=(30 - t.minute % 30) % 30 or 0)
    return None


def calcular():
    cfg = b.config()
    scfg = cfg["sugerencias"]
    hoy = dt.date.today()
    ayer = tiempos(hoy - dt.timedelta(days=1))
    semana = [tiempos(hoy - dt.timedelta(days=n)) for n in range(1, 8)]
    distrae = scfg.get("distracciones", [])
    sug = []

    # 1. Distracciones de ayer → concentración ahora
    dist = sorted(((c, s) for c, s in ayer.items() if b.coincide(c, distrae)), key=lambda x: -x[1])
    total_dist = sum(s for _, s in dist)
    pendientes = [x for x in b.programados() if x["inicio"] + x["minutos"] * 60 > dt.datetime.now().timestamp()]
    if total_dist >= 90 * 60 and not pendientes:
        principal = b.nombre_de(dist[0][0])
        minutos = int(scfg.get("bloque_min", 90))
        hueco = hueco_libre(minutos)
        idea = {"id": "concentracion", "icono": "f04fe", "tono": "naranja",
                "titulo": f"Ayer: {duracion(total_dist)} en distracciones",
                "detalle": f"Sobre todo {principal} ({duracion(dist[0][1])}). ¿Empiezas con un bloque de concentración?",
                "boton": "Ahora 50 min", "cmd": ["qs", "ipc", "call", "concentracion", "empezar", "50"]}
        if hueco:
            fin = hueco + dt.timedelta(minutes=minutos)
            cuando = ("mañana " if hueco.date() > dt.date.today() else "") + f"de {hueco:%H:%M} a {fin:%H:%M}"
            idea.update({"detalle": f"Sobre todo {principal} ({duracion(dist[0][1])}). ¿Reservo concentración {cuando}? Hay hueco en tu agenda.",
                         "boton": f"Programar {hueco:%H:%M}",
                         "cmd": [str(SCRIPTS / "brujula.py"), "programar", "--inicio", hueco.strftime("%Y-%m-%dT%H:%M"), "--minutos", str(minutos)],
                         "boton2": "Ahora 50 min", "cmd2": ["qs", "ipc", "call", "concentracion", "empezar", "50"]})
        sug.append(idea)

    # 2. Retomar el último proyecto con su próximo paso
    p = proyecto_reciente()
    if p:
        sug.append({"id": "proyecto", "icono": "f00d6", "tono": "azul",
                    "titulo": f"Sigue con «{p['nombre'][:40]}»",
                    "detalle": "Próximo paso: " + p["siguiente"][:140],
                    "boton": "Retomar", "cmd": [str(SCRIPTS / "flujo.py"), "proyecto", "retomar", "--id=" + p["id"]]})

    # 3. Lo que sueles hacer a esta hora → abrir esa sesión
    habitual = contexto_habitual(cfg)
    if habitual:
        regla, veces = habitual
        sesion = regla.get("entonces", {}).get("sesion")
        if sesion and str(sesion).isidentifier():
            sug.append({"id": "habitual", "icono": str(regla.get("icono", "f0e1b")), "tono": "verde",
                        "titulo": f"Sueles {regla['nombre'].lower()} a esta hora",
                        "detalle": f"Lo hiciste {veces} de los últimos 7 días. Abro tus apps en sus espacios.",
                        "boton": "Abrir sesión", "cmd": ["hyprctl", "dispatch", f'sesion.abrir("{sesion}") or hl.dsp.no_op()']})

    # 4. Eventos de hoy que aún no han pasado
    evs = [e for e in eventos_hoy() if not e["pasado"]]
    if evs:
        e = next((x for x in evs if x["hora"]), evs[0])
        resto = len(evs) - 1
        sug.append({"id": "evento", "icono": "f00ed", "tono": "amarillo",
                    "titulo": (f"A las {e['hora']}: " if e["hora"] else "Hoy: ") + e["titulo"][:60],
                    "detalle": f"Y {resto} {'evento' if resto == 1 else 'eventos'} más hoy." if resto else "Te aviso 10 minutos antes.",
                    "boton": "Ver agenda", "cmd": ["qs", "ipc", "call", "dashboard", "abrir"]})

    # 5. Copia de seguridad atrasada
    try:
        ultima = int(Path("/var/lib/respaldo/ultima").read_text().strip() or 0)
    except (OSError, ValueError):
        ultima = 0
    if ultima and (dt.datetime.now().timestamp() - ultima) > 5 * 86400:
        dias = int((dt.datetime.now().timestamp() - ultima) // 86400)
        sug.append({"id": "respaldo", "icono": "f0e26", "tono": "rojo",
                    "titulo": f"Tu última copia es de hace {dias} días",
                    "detalle": "Conecta el disco TOSHIBA: la copia empieza sola en cuanto lo detecta.",
                    "boton": "Copiar ahora", "cmd": ["kitty", "-e", "sh", "-c", "respaldo ahora; read -p 'Enter para cerrar' x"]})

    # 6. Una jornada de pantalla muy larga ayer → pausas
    total_ayer = sum(ayer.values())
    if total_ayer >= 9 * 3600:
        sug.append({"id": "pausas", "icono": "f0954", "tono": "morado",
                    "titulo": f"Ayer: {duracion(total_ayer)} de pantalla",
                    "detalle": "Hoy las pausas te avisarán a su hora. Mirar lejos 20 s cada 20 min ayuda a la vista.",
                    "boton": "Entendido", "cmd": []})

    # Resumen numérico para la cabecera
    medias = [sum(d.values()) for d in semana if d]
    hora = dt.datetime.now().hour
    return {
        "saludo": "Buenos días" if 5 <= hora < 12 else "Buenas tardes" if hora < 19 else "Buenas noches",
        "fecha": fecha_larga(dt.date.today()),
        "datos": {
            "ayer": duracion(total_ayer) if total_ayer else "—",
            "media": duracion(sum(medias) / len(medias)) if medias else "—",
            "top_ayer": [{"nombre": b.nombre_de(c), "tiempo": duracion(s)} for c, s in sorted(ayer.items(), key=lambda x: -x[1])[:3]],
            "eventos": len(evs), "recordatorios": len(recordatorios_hoy()),
        },
        "recordatorios": recordatorios_hoy()[:4],
        "programados": [{"id": x["id"], "inicio": x["inicio"], "minutos": x["minutos"],
                         "texto": ("Mañana " if dt.date.fromtimestamp(x["inicio"]) > hoy else "")
                                  + dt.datetime.fromtimestamp(x["inicio"]).strftime("%H:%M") + "–"
                                  + dt.datetime.fromtimestamp(x["inicio"] + x["minutos"] * 60).strftime("%H:%M")} for x in pendientes],
        "sugerencias": sug[:5],
    }


def frase():
    """Una o dos frases cálidas del asistente local con lo esencial del día. Se guarda por día."""
    cache = b.ESTADO / f"frase-{dt.date.today().isoformat()}.txt"
    try:
        return cache.read_text()
    except OSError:
        pass
    d = calcular()
    fija = (f"{d['saludo']}. " + (f"Hoy tienes {d['datos']['eventos']} {'evento' if d['datos']['eventos'] == 1 else 'eventos'} en la agenda. "
                                  if d['datos']['eventos'] else "Hoy tienes la agenda libre. ")
            + ("Empieza por lo que más te acerque a tu objetivo." if d["sugerencias"] else "Que sea un buen día."))
    if not b.config()["sugerencias"].get("ia", True):
        return fija
    datos = {"pantalla_ayer": d["datos"]["ayer"], "media_semana": d["datos"]["media"],
             "apps_ayer": d["datos"]["top_ayer"], "eventos_hoy": [e["titulo"] for e in eventos_hoy()][:4],
             "recordatorios": [r["texto"] for r in d["recordatorios"]], "ideas": [s["titulo"] for s in d["sugerencias"]]}
    try:
        modelo = (HOME / ".config/ia/modelo").read_text().strip() or "gemma3:4b"
    except OSError:
        modelo = "gemma3:4b"
    pedido = ("Con estos datos de mi día escribe UNA o DOS frases (máximo 45 palabras) en español, cálidas y concretas, "
              "como un buen compañero: menciona lo más importante de hoy y una recomendación. Sin saludo inicial, sin listas, "
              "sin emojis, sin inventar datos.\n\n" + json.dumps(datos, ensure_ascii=False))
    cuerpo = json.dumps({"model": modelo, "stream": False, "keep_alive": "5m", "options": {"num_predict": 90, "temperature": 0.6},
                         "messages": [{"role": "user", "content": pedido}]}).encode()
    try:
        req = urllib.request.Request("http://127.0.0.1:11434/api/chat", cuerpo, {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=90) as r:
            texto = json.loads(r.read()).get("message", {}).get("content", "").strip().strip('"')
    except (OSError, ValueError):
        return fija
    if not texto:
        return fija
    b.ESTADO.mkdir(mode=0o700, parents=True, exist_ok=True)
    cache.write_text(texto)
    for viejo in b.ESTADO.glob("frase-*.txt"):
        if viejo != cache:
            viejo.unlink(missing_ok=True)
    return texto


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "frase":
        print(json.dumps({"frase": frase()}, ensure_ascii=False))
    else:
        print(json.dumps(calcular(), ensure_ascii=False))
