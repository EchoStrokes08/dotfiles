#!/usr/bin/env python3
"""Eventos de Google Calendar para el dashboard (Eventos.qml lo ejecuta cada 15 min).

Lee la «dirección secreta en formato iCal» de ~/.config/calendario/url (una por línea: puedes poner
varios calendarios). ESE ARCHIVO NO VA AL REPO: con la dirección cualquiera puede leer tu calendario.
Imprime JSON: [{"inicio": ISO, "fin": ISO, "titulo", "lugar", "todoDia": bool}] de hoy a +45 días,
con los eventos repetidos ya expandidos (recurring-ical-events). Sin internet → usa la última copia.

    eventos.py            JSON (lo que lee Quickshell)
    eventos.py --lista    los próximos, legibles
"""
import datetime as dt
import json
import os
import sys
import urllib.request

CONF = os.path.expanduser("~/.config/calendario/url")
CACHE = os.path.expanduser("~/.cache/calendario/eventos.json")
DIAS = 45


def descargar(url):
    req = urllib.request.Request(url, headers={"User-Agent": "eventos.py (dashboard)"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


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
        for ev in recurring_ical_events.of(cal).between(hoy, fin):
            ini, fi = ev.get("DTSTART").dt, (ev.get("DTEND") or ev.get("DTSTART")).dt
            todo_dia = not isinstance(ini, dt.datetime)
            if todo_dia:  # fechas sin hora → medianoche local
                ini = dt.datetime.combine(ini, dt.time()).astimezone()
                fi = dt.datetime.combine(fi, dt.time()).astimezone()
            else:
                ini, fi = ini.astimezone(), fi.astimezone()
            res.append({"inicio": ini.isoformat(), "fin": fi.isoformat(),
                        "titulo": str(ev.get("SUMMARY", "(sin título)")),
                        "lugar": str(ev.get("LOCATION", "")), "todoDia": todo_dia})
    return sorted(res, key=lambda e: e["inicio"])


def main():
    try:
        datos = eventos()
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE + ".tmp", "w") as f:
            json.dump(datos, f, ensure_ascii=False)
        os.replace(CACHE + ".tmp", CACHE)
    except FileNotFoundError:
        datos = []                      # sin ~/.config/calendario/url: nada que mostrar
    except Exception as e:  # noqa: BLE001  sin internet, etc. → la última copia buena
        print(f"eventos.py: {e}", file=sys.stderr)
        try:
            with open(CACHE) as f:
                datos = json.load(f)
        except OSError:
            datos = []
    if "--lista" in sys.argv:
        for e in datos[:20]:
            i = dt.datetime.fromisoformat(e["inicio"])
            print(i.strftime("%a %d %b ") + ("todo el día" if e["todoDia"] else i.strftime("%H:%M")), "·", e["titulo"])
    else:
        print(json.dumps(datos, ensure_ascii=False))


if __name__ == "__main__":
    main()
