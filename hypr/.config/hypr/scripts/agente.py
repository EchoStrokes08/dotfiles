#!/usr/bin/env python3
"""Agente del escritorio (SUPER+O): le hablas en lenguaje natural y usa todo el sistema. 100 % local (ollama).

Consulta y abre sin preguntar; lo que CAMBIA algo (concentración, ajustes, recordatorios, responder en el
móvil, bloquear, actualizar…) lo PROPONE y solo se hace si dices que sí en el panel (Agente.qml).

    agente.py turno "texto"          un mensaje tuyo → eventos JSON, uno por línea (el panel los pinta en vivo)
    agente.py confirmar si|no        respuesta a la acción propuesta → sigue la conversación
    agente.py nueva                  empezar de cero
    agente.py precalentar            carga el modelo y sus instrucciones (el panel lo hace al abrirse)
Eventos: {"t":"herramienta","nombre","resumen"} · {"t":"confirmar","descripcion"} · {"t":"texto","d"}
         {"t":"fuentes","lista"} · {"t":"error","mensaje"} · {"t":"fin"}
Modelo: ~/.config/ia/agente (de serie qwen3:4b-instruct: necesita «tools» y NO la variante que razona).
"""
import datetime as dt
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import urllib.request

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import brujula as b  # noqa: E402

HOME = Path.home()
OLLAMA = "http://127.0.0.1:11434/api/chat"
CONV = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "brujula-agente" / "conversacion.json"
MAX_PASOS = 6
DIAS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]


def modelo():
    try:
        return (HOME / ".config/ia/agente").read_text().strip() or "qwen3:4b-instruct"
    except OSError:
        return "qwen3:4b-instruct"


def emitir(**ev):
    print(json.dumps(ev, ensure_ascii=False), flush=True)


def sh(args, timeout=10):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def lanzar(args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def fecha_de(texto):
    t = (texto or "hoy").strip().lower()
    hoy = dt.date.today()
    if t in ("hoy", ""):
        return hoy
    if t in ("mañana", "manana"):
        return hoy + dt.timedelta(days=1)
    if t == "ayer":
        return hoy - dt.timedelta(days=1)
    if t in DIAS:   # el próximo (o hoy) con ese nombre
        return hoy + dt.timedelta(days=(DIAS.index(t) - hoy.weekday()) % 7)
    if t.startswith("hace ") and t.split()[1].isdigit():
        return hoy - dt.timedelta(days=int(t.split()[1]))
    return dt.date.fromisoformat(t[:10])


# ══ herramientas de CONSULTA (se ejecutan sin preguntar) ═════════════════
FUENTES = []   # lo citado en este turno: [n] → fuente


def t_buscar_memoria(pregunta, tipo=None):
    import memoria
    tipos = [tipo] if tipo in ("documento", "linea", "web") else None
    res = memoria.buscar(pregunta, k=4, tipos=tipos)
    salida = []
    for r in res:
        FUENTES.append({"tipo": r["tipo"], "titulo": r["titulo"], "ref": r["ref"], "fecha": r["fecha"]})
        n = len(FUENTES)
        cuando = dt.datetime.fromtimestamp(r["fecha"]).strftime("%d/%m/%Y")
        salida.append(f"[{n}] ({r['tipo']}, {cuando}) {r['titulo']}\n{r['texto'][:450]}")
    if FUENTES:
        emitir(t="fuentes", lista=FUENTES)
    return "\n\n".join(salida) or "No encontré nada sobre eso en tu memoria (documentos, línea de tiempo e historial)."


def t_agenda(dia="hoy"):
    d = fecha_de(dia)
    evs = []
    for e in b.leer_json(HOME / ".cache/calendario/eventos.json", []) or []:
        try:
            ini = dt.datetime.fromisoformat(e["inicio"])
            fin = dt.datetime.fromisoformat(e["fin"])
        except (KeyError, ValueError, TypeError):
            continue
        if ini.date() == d or (e.get("todoDia") and ini.date() <= d < fin.date()):
            evs.append(("todo el día" if e.get("todoDia") else f"{ini:%H:%M}–{fin:%H:%M}") + f" {e.get('titulo', '')}"
                       + (f" ({e['lugar']})" if e.get("lugar") else ""))
    recs = [f"{dt.datetime.fromtimestamp(r['cuando'] / 1000):%H:%M} recordatorio: {r.get('texto', '')}"
            for r in b.leer_json(Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "quickshell/recordatorios.json", [])
            if isinstance(r, dict) and isinstance(r.get("cuando"), (int, float)) and dt.date.fromtimestamp(r["cuando"] / 1000) == d]
    prog = [f"{dt.datetime.fromtimestamp(x['inicio']):%H:%M} concentración de {x['minutos']} min"
            for x in b.programados() if dt.date.fromtimestamp(x["inicio"]) == d]
    todo = evs + recs + prog
    return f"{DIAS[d.weekday()]} {d:%d/%m/%Y}: " + ("; ".join(todo) if todo else "nada en la agenda.")


def t_estado_equipo():
    pct, cargando = b.bateria()
    e = b.escritorio()
    activo = b.leer_json(b.ESTADO / "activo.json", {})
    nombres = {r["id"]: r.get("nombre", r["id"]) for r in b.config()["reglas"]}
    partes = [f"Hora: {dt.datetime.now():%H:%M}",
              f"Batería: {pct} %" + (" (cargando)" if cargando else "") if pct is not None else "Sin batería",
              f"Perfil: {e.get('perfil', '?')}",
              "Privacidad activa" if e.get("privacidad_activa") == "true" else "Privacidad: no",
              "No molestar: " + sh(["qs", "ipc", "call", "notificaciones", "estado"], 3),
              "Contexto activo: " + (", ".join(nombres.get(a["id"], a["id"]) for a in activo.get("activas", [])) or "ninguno")]
    musica = sh(["playerctl", "metadata", "--format", "{{status}}: {{artist}} — {{title}}"], 3)
    if musica:
        partes.append("Música en el PC: " + musica)
    try:
        import salud
        partes.append("Salud: " + salud.resumen(salud.todo()))
    except Exception:
        pass
    try:
        import movil
        m = movil.estado()
        partes.append(f"Móvil: {m['nombre']}, batería {m['bateria']} %, {len(m['notificaciones'])} avisos" if m.get("conectado") else "Móvil: no conectado")
    except Exception:
        pass
    return ". ".join(partes) + "."


def t_linea_de_tiempo(dia="hoy"):
    d = fecha_de(dia)
    if b.escritorio().get("privacidad_activa") == "true":
        return "La línea de tiempo está oculta porque la privacidad está activa."
    r = b.resumen_linea(d)
    if not r["bloques"]:
        return f"No hay actividad registrada el {d:%d/%m}."
    dur = lambda s: f"{int(s // 3600)} h {int(s % 3600 // 60)} min" if s >= 3600 else f"{int(s // 60)} min"
    apps = ", ".join(f"{x['nombre']} {dur(x['segundos'])}" for x in r["resumen"])
    h = lambda t: dt.datetime.fromtimestamp(t).strftime("%H:%M")
    largos = sorted([x for x in r["bloques"] if x["fin"] - x["inicio"] >= 120], key=lambda x: x["inicio"])[-25:]
    bloques = "\n".join(f"{h(x['inicio'])}–{h(x['fin'])} {x['nombre']}: {'; '.join(x['titulos'][-2:])[:160]}" for x in largos)
    archivos = ", ".join(f"{a['nombre']} ({h(a['t'])})" for a in r.get("archivos", [])[-10:])
    return f"{d:%d/%m}: total {dur(r['total'])}. Por app: {apps}.\n{bloques}" + (f"\nArchivos abiertos: {archivos}" if archivos else "")


def t_buscar_archivos(texto):
    import indice
    res = [r for r, _ in indice.buscar(texto, 6)]
    for l in sh(["fd", "-i", "--max-results", "10", "--exclude", ".cache", "--", texto, str(HOME)], 8).splitlines():
        if l not in res:
            res.append(l)
    return "\n".join(res[:12]) or "No encontré archivos con eso."


def t_avisos_movil():
    import movil
    m = movil.estado()
    if not m.get("conectado"):
        return "El móvil no está conectado."
    avs = m.get("notificaciones", [])
    return "\n".join(f"- {a['app']}: {a['titulo']} — {a['texto'][:140]}" + (" (se puede responder)" if a["responder"] else "")
                     for a in avs) or "No hay avisos en el móvil."


PANELES = {"brujula": ["brujula", "abrir", "hoy"], "salud": ["brujula", "abrir", "salud"], "linea": ["brujula", "abrir", "linea"],
           "contexto": ["brujula", "abrir", "contexto"], "sesion": ["brujula", "abrir", "sesion"], "movil": ["movil", "abrir"],
           "dashboard": ["dashboard", "abrir"], "notificaciones": ["notificaciones", "toggle"], "wallpapers": ["wallpapers", "toggle"],
           "portapapeles": ["portapapeles", "toggle"], "atajos": ["chuleta", "toggle"], "wifi": ["conexiones", "wifi"],
           "bluetooth": ["conexiones", "bluetooth"]}


def t_abrir(que):
    q = (que or "").strip()
    llano = q.lower().replace("ú", "u").replace("ó", "o").replace("í", "i").replace("á", "a").replace("é", "e")
    if re.match(r"https?://", q):
        lanzar(["xdg-open", q])
        return f"Abierta la página {q}."
    p = Path(q).expanduser()
    if q and (q.startswith(("/", "~"))) and p.exists():
        lanzar(["xdg-open", str(p)])
        return f"Abierto {p}."
    for nombre, ipc in PANELES.items():
        if llano == nombre or llano.startswith(nombre):
            lanzar(["qs", "ipc", "call", *ipc])
            return f"Abierto el panel {nombre}."
    por_id, _ = b.apps_instaladas()
    candidatos = [e for e in por_id.values() if not e["oculta"] and (llano in e["nombre"].lower() or llano in e["id"].lower())]
    if candidatos:
        e = min(candidatos, key=lambda e: len(e["nombre"]))
        lanzar(["gtk-launch", e["id"]])
        return f"Abierta la app {e['nombre']}."
    return f"No sé abrir «{q}». Puedo abrir apps por su nombre, archivos (ruta), páginas (URL) o paneles: {', '.join(PANELES)}."


# ══ herramientas que CAMBIAN algo: preparar (describir) → confirmar → hacer ══
def sesiones():
    texto = (HOME / ".config/hypr/modulos/sesiones.lua").read_text(errors="replace") if (HOME / ".config/hypr/modulos/sesiones.lua").exists() else ""
    return dict(re.findall(r'id\s*=\s*"([\w-]+)",\s*nombre\s*=\s*"([^"]+)"', texto))


def p_concentracion(minutos=50, inicio=None):
    m = max(5, min(240, int(minutos)))
    if inicio:
        t = dt.datetime.combine(dt.date.today(), dt.time.fromisoformat(inicio))
        if t < dt.datetime.now():
            t += dt.timedelta(days=1)
        return f"Programar concentración de {m} min a las {t:%H:%M}" + (" de mañana" if t.date() > dt.date.today() else ""), \
            lambda: b.programar(int(t.timestamp()), m)["mensaje"]
    return f"Empezar ahora una concentración de {m} min (No molestar y apps que distraen escondidas)", \
        lambda: (sh(["qs", "ipc", "call", "concentracion", "empezar", str(m)]), f"Concentración de {m} min en marcha.")[1]


def p_abrir_sesion(nombre):
    s = sesiones()
    clave = next((k for k, v in s.items() if nombre.lower() in (k.lower(), v.lower())), None)
    if not clave:
        raise ValueError(f"No existe la sesión «{nombre}». Hay: {', '.join(s.values())}")
    return f"Abrir la sesión «{s[clave]}» (sus apps en sus espacios)", \
        lambda: (sh(["hyprctl", "dispatch", f'sesion.abrir("{clave}") or hl.dsp.no_op()']), f"Sesión {s[clave]} abierta.")[1]


def p_ajuste(nombre):
    import buscar
    res = buscar.ajustes(nombre)
    if not res:
        raise ValueError(f"No encontré un ajuste «{nombre}». Ejemplos: perfil lectura, tema claro, no molestar, bluetooth: apagar.")
    a = res[0]
    return f"Aplicar el ajuste «{a['nombre']}»", lambda: (sh(a["cmd"], 15), f"Ajuste aplicado: {a['nombre']}.")[1]


def p_recordatorio(cuando, texto):
    linea = f"{cuando} {texto}".strip()
    return f"Crear el recordatorio «{texto}» para {cuando}", \
        lambda: sh(["qs", "ipc", "call", "recordatorios", "agregar", linea]) or "Recordatorio creado."


def p_responder_movil(destinatario, mensaje):
    import movil
    m = movil.estado()
    if not m.get("conectado"):
        raise ValueError("El móvil no está conectado.")
    llano = destinatario.lower()
    candidatos = [a for a in m["notificaciones"] if a["responder"] and (llano in a["titulo"].lower() or llano in a["app"].lower())]
    if not candidatos:
        raise ValueError(f"No hay ningún aviso de «{destinatario}» que se pueda responder en el móvil.")
    a = candidatos[0]
    return f"Responder a «{a['titulo']}» ({a['app']}) desde el móvil: «{mensaje}»", \
        lambda: (sh([str(SCRIPTS / "movil.py"), "responder", a["id"], mensaje]), "Respuesta enviada.")[1]


def p_enviar_al_movil(texto):
    return f"Enviar al móvil: «{texto[:120]}»", \
        lambda: (subprocess.run(["kdeconnect-cli", "-d", sh(["kdeconnect-cli", "-a", "--id-only"]).split("\n")[0], "--share-text", texto],
                                capture_output=True, timeout=15), "Enviado al móvil.")[1]


SISTEMA = {
    "bloquear": ("Bloquear la pantalla", ["loginctl", "lock-session"]),
    "suspender": ("Suspender el equipo", ["systemctl", "suspend"]),
    "actualizar": ("Abrir la actualización segura del sistema (te mostrará todo antes de instalar)", [str(SCRIPTS / "actualizaciones.sh"), "instalar"]),
    "deshacer_actualizacion": ("Abrir «deshacer la última actualización» (pedirá confirmación y contraseña)", [str(SCRIPTS / "actualizaciones.sh"), "deshacer"]),
    "reabrir_ventana": ("Reabrir la última ventana cerrada", [str(SCRIPTS / "brujula.py"), "reabrir"]),
    "cerrar_dia": ("Cerrar el día (guardar sesión, No molestar, luz cálida, brillo bajo)", [str(SCRIPTS / "brujula.py"), "jornada", "cerrar"]),
}


def p_sistema(accion):
    if accion not in SISTEMA:
        raise ValueError("Acción no válida: " + ", ".join(SISTEMA))
    texto, cmd = SISTEMA[accion]
    return texto, lambda: (lanzar(cmd), f"Hecho: {texto.lower()}.")[1]


CONSULTAS = {"buscar_memoria": t_buscar_memoria, "agenda": t_agenda, "estado_equipo": t_estado_equipo,
             "linea_de_tiempo": t_linea_de_tiempo, "buscar_archivos": t_buscar_archivos, "avisos_movil": t_avisos_movil, "abrir": t_abrir}
ACCIONES = {"concentracion": p_concentracion, "abrir_sesion": p_abrir_sesion, "ajuste": p_ajuste, "recordatorio": p_recordatorio,
            "responder_movil": p_responder_movil, "enviar_al_movil": p_enviar_al_movil, "sistema": p_sistema}


def f(nombre, descripcion, props=None, requeridos=None):
    return {"type": "function", "function": {"name": nombre, "description": descripcion,
            "parameters": {"type": "object", "properties": props or {}, "required": requeridos or []}}}


S = {"type": "string"}
HERRAMIENTAS = [
    f("buscar_memoria", "Busca por significado en lo que el usuario leyó, escribió o hizo: sus documentos y apuntes, su línea de tiempo y su historial web. Úsala para «qué leí/hice/vi sobre…».",
      {"pregunta": S, "tipo": {"type": "string", "enum": ["documento", "linea", "web"]}}, ["pregunta"]),
    f("agenda", "Eventos, recordatorios y concentraciones de un día.", {"dia": {"type": "string", "description": "hoy, mañana, ayer, un día de la semana o AAAA-MM-DD"}}),
    f("estado_equipo", "Batería, perfil, No molestar, contexto activo, música, salud del sistema y móvil."),
    f("linea_de_tiempo", "Qué apps y ventanas usó el usuario un día, con horas y archivos abiertos.", {"dia": S}),
    f("buscar_archivos", "Busca archivos por nombre y dentro de documentos. Devuelve rutas.", {"texto": S}, ["texto"]),
    f("avisos_movil", "Notificaciones pendientes del móvil (WhatsApp, SMS…)."),
    f("abrir", "Abre una app por su nombre, un archivo (ruta), una URL o un panel (brujula, salud, linea, movil, dashboard, wifi…).", {"que": S}, ["que"]),
    f("concentracion", "Bloque de concentración ahora o a una hora.", {"minutos": {"type": "integer"}, "inicio": {"type": "string", "description": "HH:MM, opcional"}}, ["minutos"]),
    f("abrir_sesion", "Abre una sesión de trabajo con sus apps: " + ", ".join(sesiones().values() or ["universidad", "programar", "descanso"]) + ".", {"nombre": S}, ["nombre"]),
    f("ajuste", "Cambia un ajuste: perfil cristal/lectura/minimo/rendimiento, tema claro/oscuro, no molestar, privacidad, luz nocturna, energía, wifi, bluetooth, modo juego…", {"nombre": S}, ["nombre"]),
    f("recordatorio", "Crea un recordatorio.", {"cuando": {"type": "string", "description": "20m, 18:30 o mañana 7:00"}, "texto": S}, ["cuando", "texto"]),
    f("responder_movil", "Responde un aviso del móvil (WhatsApp, SMS…) de una persona o app.", {"destinatario": S, "mensaje": S}, ["destinatario", "mensaje"]),
    f("enviar_al_movil", "Manda un texto o enlace al móvil.", {"texto": S}, ["texto"]),
    f("sistema", "Acciones del sistema.", {"accion": {"type": "string", "enum": list(SISTEMA)}}, ["accion"]),
]


def instrucciones():
    # FIJAS a propósito (sin la hora): así ollama reutiliza su caché y no relee todo en cada pregunta.
    # La fecha y la hora van en cada mensaje del usuario.
    return ("Eres el asistente del escritorio Linux (Arch + Hyprland) del usuario. "
            "Respondes SIEMPRE en español y hablas al usuario de tú («leíste», «tienes»). Sé breve: 2-4 frases o una "
            "lista corta, salvo que pida detalle. Cada mensaje del usuario empieza con la fecha y hora actuales.\n"
            "- Usa las herramientas para cualquier dato real (agenda, batería, archivos, lo que leyó o hizo). Nunca inventes datos.\n"
            "- Si te piden hacer algo, llama a la herramienta directamente: el sistema le pedirá confirmación al usuario, "
            "tú no preguntes antes. Si una acción se cancela, acéptalo sin insistir.\n"
            "- Para «prepárame para…» combina varias herramientas (sesión, concentración, buscar_memoria).\n"
            "- Para preguntas sobre lo que el usuario leyó, vio, escribió o hizo, usa buscar_memoria y responde con lo que encuentre.\n"
            "- Cita con [1], [2]… SOLO los resultados numerados de buscar_memoria; si no la usaste, no pongas corchetes.\n"
            "- Si no hay nada, dilo. No muestres JSON ni nombres de herramientas.")


# ══ conversación ═════════════════════════════════════════════════════════
def cargar():
    d = b.leer_json(CONV, {})
    return d if isinstance(d.get("mensajes"), list) else {"mensajes": [], "pendiente": None}


def guardar(d):
    CONV.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    d["mensajes"] = d["mensajes"][-24:]
    while d["mensajes"] and d["mensajes"][0].get("role") == "tool":   # no empezar a medias
        d["mensajes"].pop(0)
    b.atomico(CONV, d)


def chat(mensajes, emitir_texto=True, predecir=None):
    cuerpo = {"model": modelo(), "stream": True, "think": False, "keep_alive": "20m",
              "messages": [{"role": "system", "content": instrucciones()}] + mensajes, "tools": HERRAMIENTAS,
              "options": {"num_ctx": 8192, "temperature": 0.3, **({"num_predict": predecir} if predecir else {})}}
    req = urllib.request.Request(OLLAMA, json.dumps(cuerpo).encode(), {"Content-Type": "application/json"})
    texto, llamadas = "", []
    with urllib.request.urlopen(req, timeout=600) as r:
        for linea in r:
            m = json.loads(linea).get("message", {})
            if m.get("content"):
                texto += m["content"]
                if emitir_texto:
                    emitir(t="texto", d=m["content"])
            llamadas += m.get("tool_calls") or []
    return texto, llamadas


def resumen_llamada(nombre, args):
    return {"buscar_memoria": "Buscando en tu memoria", "agenda": "Mirando la agenda", "estado_equipo": "Revisando el equipo",
            "linea_de_tiempo": "Repasando tu línea de tiempo", "buscar_archivos": "Buscando archivos",
            "avisos_movil": "Mirando el móvil", "abrir": "Abriendo"}.get(nombre, nombre) + \
        (f": {next(iter(args.values()))}" if args and isinstance(next(iter(args.values())), str) else "")


def avanzar(d):
    """Bucle del agente: modelo → herramientas → modelo… hasta responder o necesitar confirmación."""
    for _ in range(MAX_PASOS):
        texto, llamadas = chat(d["mensajes"])
        d["mensajes"].append({"role": "assistant", "content": texto, **({"tool_calls": llamadas} if llamadas else {})})
        if not llamadas:
            guardar(d)
            return
        for i, ll in enumerate(llamadas):
            fn = ll.get("function", {})
            nombre, args = fn.get("name", ""), fn.get("arguments") or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except ValueError:
                    args = {}
            if nombre in CONSULTAS:
                emitir(t="herramienta", nombre=nombre, resumen=resumen_llamada(nombre, args))
                try:
                    resultado = CONSULTAS[nombre](**args)
                except (TypeError, ValueError, OSError, KeyError) as e:
                    resultado = f"Error: {e}"
                d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": str(resultado)[:6000]})
            elif nombre in ACCIONES:
                try:
                    descripcion, _ = ACCIONES[nombre](**args)
                except (TypeError, ValueError, OSError, KeyError) as e:
                    d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": f"No se puede: {e}"})
                    continue
                # parar aquí: el resto de llamadas de este paso se hará después de la respuesta del usuario
                d["pendiente"] = {"nombre": nombre, "args": args, "descripcion": descripcion, "resto": llamadas[i + 1:]}
                guardar(d)
                emitir(t="confirmar", descripcion=descripcion)
                return
            else:
                d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": "Herramienta desconocida."})
    guardar(d)


# Preguntas que son claramente sobre tu memoria: se busca SIEMPRE antes de que el modelo responda
# (un modelo pequeño a veces contesta «no hay nada» sin buscar).
MEMORIA = re.compile(r"\b(le[ií]|leyendo|le[ií]do|vi|viendo|visto|estuve|estaba|escrib[ií]|apunt|anot|busqu[eé]|guard[eé]|"
                     r"d[oó]nde (vi|le[ií]|puse|guard|estaba)|qu[eé] (hice|hac[ií]a|hicimos)|record(ar|ás|as)|"
                     r"mis (notas|apuntes|documentos|archivos)|sobre qu[eé])\b", re.I)


def turno(texto):
    d = cargar()
    if d.get("pendiente"):   # escribir algo nuevo = no a lo pendiente
        d["mensajes"].append({"role": "tool", "tool_name": d["pendiente"]["nombre"], "content": "El usuario no lo confirmó."})
        d["pendiente"] = None
    ahora = dt.datetime.now()
    d["mensajes"].append({"role": "user", "content": f"[{DIAS[ahora.weekday()]} {ahora:%d/%m/%Y %H:%M}] {texto[:4000]}"})
    if MEMORIA.search(texto):
        emitir(t="herramienta", nombre="buscar_memoria", resumen=resumen_llamada("buscar_memoria", {"pregunta": texto}))
        llamada = {"function": {"name": "buscar_memoria", "arguments": {"pregunta": texto}}}
        d["mensajes"].append({"role": "assistant", "content": "", "tool_calls": [llamada]})
        d["mensajes"].append({"role": "tool", "tool_name": "buscar_memoria", "content": t_buscar_memoria(texto)[:6000]})
    avanzar(d)


def confirmar(si):
    d = cargar()
    p = d.get("pendiente")
    if not p:
        emitir(t="error", mensaje="No hay nada pendiente de confirmar.")
        return
    d["pendiente"] = None
    if si:
        try:
            _, hacer = ACCIONES[p["nombre"]](**p["args"])
            resultado = hacer()
            emitir(t="herramienta", nombre=p["nombre"], resumen="✓ " + p["descripcion"])
        except (TypeError, ValueError, OSError, KeyError) as e:
            resultado = f"Falló: {e}"
            emitir(t="error", mensaje=resultado)
    else:
        resultado = "El usuario dijo que no. No se hizo."
    d["mensajes"].append({"role": "tool", "tool_name": p["nombre"], "content": str(resultado)})
    # las llamadas que venían detrás: consultas se hacen; la siguiente acción se vuelve a proponer
    for ll in p.get("resto") or []:
        fn = ll.get("function", {})
        nombre, args = fn.get("name", ""), fn.get("arguments") or {}
        if nombre in ACCIONES:
            try:
                descripcion, _ = ACCIONES[nombre](**args)
            except (TypeError, ValueError, OSError, KeyError) as e:
                d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": f"No se puede: {e}"})
                continue
            d["pendiente"] = {"nombre": nombre, "args": args, "descripcion": descripcion,
                              "resto": p["resto"][p["resto"].index(ll) + 1:]}
            guardar(d)
            emitir(t="confirmar", descripcion=descripcion)
            return
        if nombre in CONSULTAS:
            try:
                d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": str(CONSULTAS[nombre](**args))[:6000]})
            except (TypeError, ValueError, OSError, KeyError) as e:
                d["mensajes"].append({"role": "tool", "tool_name": nombre, "content": f"Error: {e}"})
    avanzar(d)


def main():
    orden = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if orden == "turno":
            turno(" ".join(sys.argv[2:]))
        elif orden == "confirmar":
            confirmar(len(sys.argv) > 2 and sys.argv[2] == "si")
        elif orden == "nueva":
            CONV.unlink(missing_ok=True)
        elif orden == "precalentar":
            chat([{"role": "user", "content": "hola"}], emitir_texto=False, predecir=1)
        else:
            sys.exit(__doc__)
    except OSError as e:
        emitir(t="error", mensaje=f"No pude hablar con ollama ({e}). ¿Está activo y descargado el modelo «{modelo()}»?")
    emitir(t="fin")


if __name__ == "__main__":
    main()
