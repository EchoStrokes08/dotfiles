#!/usr/bin/env python3
"""Eventos de Google Calendar para el dashboard (Eventos.qml lo ejecuta cada 15 min).

Lee la «dirección secreta en formato iCal» de ~/.config/calendario/url (una por línea: puedes poner
varios calendarios). ESE ARCHIVO NO VA AL REPO: con la dirección cualquiera puede leer tu calendario.
Imprime JSON: [{"inicio": ISO, "fin": ISO, "titulo", "lugar", "todoDia": bool}] de hoy a +45 días,
con los eventos repetidos ya expandidos (recurring-ical-events). Sin internet → usa la última copia.

    eventos.py            JSON (lo que lee Quickshell)
    eventos.py --lista    los próximos, legibles
    eventos.py --estado   JSON con datos, frescura y última sincronización (Quickshell)
"""
import datetime as dt
import hashlib
import json
import os
import sys
import urllib.request

CONF = os.path.expanduser("~/.config/calendario/url")
CACHE = os.path.expanduser("~/.cache/calendario/eventos.json")
CREADOS = os.path.expanduser("~/.cache/calendario/creados.json")   # los escribe gcal.py
DIAS = 45


def descargar(url):
    req = urllib.request.Request(url, headers={"User-Agent": "eventos.py (dashboard)"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def repeticion(regla):
    """Describir solo una regla conocida; nunca inferir recurrencia por el título."""
    partes=dict(p.split("=",1) for p in regla.upper().split(";") if "=" in p)
    if partes.get("INTERVAL","1") != "1": return "se repite"
    if partes.get("FREQ")=="DAILY" and "BYDAY" not in partes: return "diario"
    if partes.get("FREQ")=="WEEKLY":
        dias={"MO":"lun","TU":"mar","WE":"mié","TH":"jue","FR":"vie","SA":"sáb","SU":"dom"}
        return "semanal"+(" · "+", ".join(dias.get(d,d) for d in partes["BYDAY"].split(",")) if "BYDAY" in partes else "")
    if partes.get("FREQ")=="MONTHLY": return "mensual"
    return "se repite" if regla else ""


def eventos():
    import icalendar
    import recurring_ical_events
    hoy = dt.datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
    fin = hoy + dt.timedelta(days=DIAS)
    res = []
    with open(CONF) as f:
        urls = [l.strip() for l in f if l.strip() and not l.startswith("#")]
    for url in urls:
        cal = icalendar.Calendar.from_ical(descargar(url))
        calendario = hashlib.sha256(url.encode()).hexdigest()[:16]
        maestros = {str(e.get("UID","")):e for e in cal.walk("VEVENT") if not e.get("RECURRENCE-ID")}

        for ev in recurring_ical_events.of(cal).between(hoy, fin):
            ini, fi = ev.get("DTSTART").dt, (ev.get("DTEND") or ev.get("DTSTART")).dt
            todo_dia = not isinstance(ini, dt.datetime)
            if todo_dia:  # fechas sin hora → medianoche local
                ini = dt.datetime.combine(ini, dt.time()).astimezone()
                fi = dt.datetime.combine(fi, dt.time()).astimezone()
            else:
                ini, fi = ini.astimezone(), fi.astimezone()
            uid = str(ev.get("UID",""))
            maestro = maestros.get(uid,ev)
            regla = maestro.get("RRULE")
            regla = regla.to_ical().decode() if regla else ""
            recurrencia = ev.get("RECURRENCE-ID")
            ocurrencia = str(recurrencia.dt) if recurrencia else ini.isoformat()
            excepcion = bool(recurrencia and (recurrencia.dt != ev.get("DTSTART").dt))
            res.append({"calendario":calendario, "serie":calendario+":"+uid if regla and uid else "",
                        "ocurrencia":ocurrencia,"regla":regla,"repeticion":repeticion(regla),"excepcion":excepcion,
                        "inicio": ini.isoformat(), "fin": fi.isoformat(),
                        "titulo": str(ev.get("SUMMARY", "(sin título)")),
                        "lugar": str(ev.get("LOCATION", "")), "todoDia": todo_dia,
                        "uid": str(ev.get("UID", ""))})
    return sorted(res, key=lambda e: e["inicio"])


def mezclar_creados(datos, ruta=None):
    """Añade los eventos creados con gcal.py que el feed iCal todavía no trae (Google tarda en
    actualizarlo). Se descartan solos cuando aparecen en el feed o cuando ya terminaron."""
    ruta = CREADOS if ruta is None else ruta
    try:
        with open(ruta) as f:
            creados = json.load(f)
    except (OSError, ValueError):
        return datos
    ahora = dt.datetime.now().astimezone()
    vistos = {e.get("uid") for e in datos}
    extra = [c for c in creados if c.get("uid") not in vistos and dt.datetime.fromisoformat(c["fin"]) > ahora]
    if not extra:
        return datos
    return sorted(datos + [{k: c[k] for k in ("inicio", "fin", "titulo", "lugar", "todoDia", "uid")} for c in extra],
                  key=lambda e: dt.datetime.fromisoformat(e["inicio"]))


def validar(datos):
    """Una caché rota no debe reemplazar los datos buenos que conserva la interfaz."""
    if not isinstance(datos, list):
        raise ValueError("La agenda no contiene una lista")
    for evento in datos:
        for campo in ("inicio", "fin"):
            dt.datetime.fromisoformat(evento[campo])
        if not isinstance(evento["titulo"], str):
            raise ValueError("Evento sin título válido")
    return datos


def leer_resultado():
    if not os.path.isfile(CONF):
        return {"eventos": mezclar_creados([]), "estado": "sin_configurar", "actualizado": None,
                "error": "Configura el calendario para sincronizar tu agenda."}
    try:
        datos = validar(mezclar_creados(eventos()))
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE + ".tmp", "w") as f:
            json.dump(datos, f, ensure_ascii=False)
        os.replace(CACHE + ".tmp", CACHE)
        return {"eventos": datos, "estado": "actualizado", "actualizado": os.path.getmtime(CACHE), "error": ""}
    except Exception as e:  # noqa: BLE001  sin internet, etc. → la última copia buena
        # Una excepción de red puede incluir la URL privada del calendario. No publicarla en avisos/logs.
        print(f"eventos.py: no se pudo sincronizar ({type(e).__name__})", file=sys.stderr)
        try:
            with open(CACHE) as f:
                datos = validar(json.load(f))
            return {"eventos": mezclar_creados(datos), "estado": "desactualizado", "actualizado": os.path.getmtime(CACHE),
                    "error": "No se pudo sincronizar. Se muestra la última copia guardada."}
        except (OSError, ValueError, TypeError, KeyError):
            return {"eventos": mezclar_creados([]), "estado": "error", "actualizado": None,
                    "error": "No se pudo sincronizar y no hay una copia válida. Comprueba la conexión y el calendario."}


def main():
    resultado = leer_resultado()
    datos = resultado["eventos"]
    if "--estado" in sys.argv:
        print(json.dumps(resultado, ensure_ascii=False))
        return
    if "--lista" in sys.argv:
        for e in datos[:20]:
            i = dt.datetime.fromisoformat(e["inicio"])
            print(i.strftime("%a %d %b ") + ("todo el día" if e["todoDia"] else i.strftime("%H:%M")), "·", e["titulo"])
    else:
        print(json.dumps(datos, ensure_ascii=False))


if __name__ == "__main__":
    main()
