#!/usr/bin/env python3
"""Tu día: los datos del resumen cinematográfico (TuDia.qml / CapaTuDia.qml lo cuentan en tarjetas).

Todo sale de lo que el equipo ya apunta, en local:
  · la línea de tiempo de Brújula (~/.local/state/brujula/linea/AAAA-MM-DD.jsonl): apps, horas, rachas
  · la música que sonó (~/.local/state/quickshell/musica/AAAA-MM-DD.jsonl, la apunta TuDia.qml cada 30 s)
  · las capturas (~/Imágenes/screenshots) y los archivos abiertos (recently-used.xbel)

Uso
  tudia.py [--dia AAAA-MM-DD]     JSON con todo lo que necesitan las tarjetas
  tudia.py --semana [--dia …]     «Tu semana»: los 7 días que acaban en ese día (hoy si no se dice),
                                  con la misma forma y semanal=true; media = la semana anterior
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
import brujula as b  # noqa: E402

MUSICA = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell/musica"
CAPTURAS = Path.home() / "Imágenes/screenshots"
# lo que mandan los navegadores cuando una pestaña suena sin título de canción: no es música
GENERICOS = ("reproduciendo contenido multimedia", "is playing media", "playing audio")
TOP = 5            # apps con color propio; el resto es «otras»
TITULOS = {        # el contexto que más pesó → cómo se llama el día
    "programar": "Un día de código", "estudiar": "Un día de estudio", "jugar": "Un día de juego",
    "leer": "Un día de lectura", "reunion": "Un día de reuniones", "descansar": "Un día tranquilo",
}


def total_dia(dia):
    return sum(x["fin"] - x["inicio"] for x in b.bloques(dia, vivo=False))


def por_horas(bloques):
    """Segundos activos en cada hora del día (24 valores), repartiendo los bloques que cruzan la hora."""
    horas = [0] * 24
    for x in bloques:
        t = x["inicio"]
        while t < x["fin"]:
            d = dt.datetime.fromtimestamp(t)
            siguiente = int((d.replace(minute=0, second=0, microsecond=0) + dt.timedelta(hours=1)).timestamp())
            corte = min(siguiente, x["fin"])
            horas[d.hour] += corte - t
            t = corte
    return horas


def musica(*dias):
    lineas = []
    for dia in dias:
        try:
            lineas += (MUSICA / f"{dia.isoformat()}.jsonl").read_text().splitlines()
        except OSError:
            pass
    canciones, artistas, total = {}, {}, 0
    for linea in lineas:
        try:
            r = json.loads(linea)
        except ValueError:
            continue
        if not isinstance(r, dict) or not r.get("ti") or any(g in r["ti"].lower() for g in GENERICOS):
            continue
        s = int(r.get("s", 30))
        total += s
        clave = (r["ti"], r.get("ar", ""))
        c = canciones.setdefault(clave, {"titulo": r["ti"], "artista": r.get("ar", ""), "caratula": "", "segundos": 0})
        c["segundos"] += s
        if r.get("art"):
            c["caratula"] = r["art"]
        if r.get("ar"):
            artistas[r["ar"]] = artistas.get(r["ar"], 0) + s
    if not canciones:
        return None
    orden = sorted(canciones.values(), key=lambda c: -c["segundos"])
    artista = max(artistas.items(), key=lambda a: a[1])[0] if artistas else ""
    return {"cancion": orden[0], "otras": orden[1:4], "segundos": total, "canciones": len(canciones), "artista": artista}


def capturas(*dias):
    if not CAPTURAS.is_dir():
        return 0
    n = 0
    for f in CAPTURAS.iterdir():
        try:
            if f.is_file() and dt.date.fromtimestamp(f.stat().st_mtime) in dias:
                n += 1
        except OSError:
            pass
    return n


def titulo(contextos, total):
    if total < 3600:
        return "Un día ligero"
    if contextos:
        return TITULOS.get(contextos[0]["nombre"].lower(), f"Un día de {contextos[0]['nombre'].lower()}")
    return "Tu día, en cifras"


def datos(dia):
    bloques = b.bloques(dia)
    total = sum(x["fin"] - x["inicio"] for x in bloques)
    apps = {}
    for x in bloques:
        a = apps.setdefault(x["clase"], {"clase": x["clase"], "nombre": x["nombre"], "segundos": 0})
        a["segundos"] += x["fin"] - x["inicio"]
    top = sorted(apps.values(), key=lambda a: -a["segundos"])
    indice = {a["clase"]: i for i, a in enumerate(top[:TOP])}

    # La racha: el bloque más largo seguido en una misma app
    racha = max(bloques, key=lambda x: x["fin"] - x["inicio"], default=None)
    contextos = {}
    for x in bloques:
        if x["contexto"]:
            contextos[x["contexto"]] = contextos.get(x["contexto"], 0) + x["fin"] - x["inicio"]

    # La semana: los 7 días anteriores (los que tienen línea) para comparar
    semana = []
    for i in range(7, 0, -1):
        d = dia - dt.timedelta(days=i)
        semana.append({"dia": d.isoformat(), "letra": b.DIAS[d.weekday()][0].upper(), "segundos": total_dia(d)})
    con_datos = [s["segundos"] for s in semana if s["segundos"] > 0]
    media = round(sum(con_datos) / len(con_datos)) if con_datos else 0

    horas = por_horas(bloques)
    # Lo de antes de las 5:00 es la noche anterior: cuenta como trasnoche, no como el inicio del día
    madrugada = sum(horas[:5])
    despierto = next((x for x in bloques if dt.datetime.fromtimestamp(x["inicio"]).hour >= 5), None)
    # La forma del día para el anillo final: tramos con el índice de su app (-1 = otras), sin migajas
    tramos = []
    for x in bloques:
        i = indice.get(x["clase"], -1)
        if tramos and tramos[-1]["app"] == i and x["inicio"] - tramos[-1]["fin"] <= 60:
            tramos[-1]["fin"] = x["fin"]
        elif x["fin"] - x["inicio"] >= 60:
            tramos.append({"inicio": x["inicio"], "fin": x["fin"], "app": i})
    orden_ctx = [{"nombre": k, "segundos": v} for k, v in sorted(contextos.items(), key=lambda c: -c[1])]
    return {
        "dia": dia.isoformat(),
        "hoy": dia == dt.date.today(),
        "titulo": titulo(orden_ctx, total),
        "total": total,
        "media": media,
        "semana": semana,
        "inicio": (despierto or bloques[0])["inicio"] if bloques else 0,
        "madrugada": madrugada,
        "fin": bloques[-1]["fin"] if bloques else 0,
        "apps": [dict(a, porcentaje=round(100 * a["segundos"] / total) if total else 0) for a in top[:TOP]],
        "otras": sum(a["segundos"] for a in top[TOP:]),
        "numeroApps": len(top),
        "horas": horas,
        "horaPico": max(range(24), key=lambda h: horas[h]) if total else -1,
        "racha": {"clase": racha["clase"], "nombre": racha["nombre"], "inicio": racha["inicio"],
                  "segundos": racha["fin"] - racha["inicio"]} if racha else None,
        "saltos": max(0, len(bloques) - 1),
        "contextos": orden_ctx[:4],
        "tramos": tramos[-400:],
        "musica": musica(dia),
        "capturas": capturas(dia),
        "archivos": len(b.archivos_del_dia(dia)),
    }


SEMANAS = {       # el contexto que más pesó → cómo se llama la semana
    "programar": "Una semana de código", "estudiar": "Una semana de estudio", "jugar": "Una semana de juego",
    "leer": "Una semana de lectura", "reunion": "Una semana de reuniones", "descansar": "Una semana tranquila",
}


def hora_tipica(marcas):
    """La hora del día (segundos desde las 0:00) que hace de mediana entre varios días."""
    if not marcas:
        return None
    s = sorted(marcas)
    return s[len(s) // 2]


def semana(fin):
    """«Tu semana»: los 7 días que acaban en `fin`, con la misma forma que datos() para las tarjetas."""
    dias = [fin - dt.timedelta(days=i) for i in range(6, -1, -1)]
    por_dia = [datos(d) for d in dias]
    total = sum(d["total"] for d in por_dia)
    anterior = sum(total_dia(fin - dt.timedelta(days=i)) for i in range(13, 6, -1))

    apps = {}
    for d in por_dia:
        for a in d["apps"]:
            x = apps.setdefault(a["clase"], {"clase": a["clase"], "nombre": a["nombre"], "segundos": 0})
            x["segundos"] += a["segundos"]
    top = sorted(apps.values(), key=lambda a: -a["segundos"])
    nombres_apps = set()
    for dia in dias:
        nombres_apps.update(x["clase"] for x in b.bloques(dia, vivo=dia == dt.date.today()))
    contextos = {}
    for d in por_dia:
        for c in d["contextos"]:
            contextos[c["nombre"]] = contextos.get(c["nombre"], 0) + c["segundos"]
    orden_ctx = [{"nombre": k, "segundos": v} for k, v in sorted(contextos.items(), key=lambda c: -c[1])]
    horas = [sum(d["horas"][h] for d in por_dia) for h in range(24)]

    mejor = max(range(7), key=lambda i: por_dia[i]["total"]) if total else -1
    barras = [{"dia": d["dia"], "letra": b.DIAS[dia.weekday()].capitalize(), "segundos": d["total"], "hoy": i == mejor}
              for i, (d, dia) in enumerate(zip(por_dia, dias))]

    # Inicio y final típicos (mediana de los días con algo), como hora de hoy para que la capa la formatee
    def de_hoy(segundos):
        return int(dt.datetime.combine(dt.date.today(), dt.time()).timestamp()) + segundos if segundos is not None else 0
    def seg(ts):
        f = dt.datetime.fromtimestamp(ts)
        return f.hour * 3600 + f.minute * 60
    activos = [d for d in por_dia if d["total"] >= 600]
    rachas = [dict(d["racha"], dia=d["dia"]) for d in por_dia if d["racha"]]
    racha = max(rachas, key=lambda r: r["segundos"], default=None)
    if racha:
        racha["diaNombre"] = b.DIAS[dt.date.fromisoformat(racha["dia"]).weekday()]
    tramos = [x for d in por_dia for x in d["tramos"]]
    # en el anillo, cada tramo con el índice de su app en el top de la SEMANA
    indice = {a["clase"]: i for i, a in enumerate(top[:TOP])}
    for d in por_dia:
        locales = [a["clase"] for a in d["apps"]]
        for x in d["tramos"]:
            x["app"] = indice.get(locales[x["app"]], -1) if 0 <= x["app"] < len(locales) else -1

    return {
        "semanal": True,
        "dia": fin.isoformat(),
        "desde": dias[0].isoformat(),
        "hoy": False,
        "titulo": ("Una semana ligera" if total < 5 * 3600 else
                   SEMANAS.get(orden_ctx[0]["nombre"].lower(), f"Una semana de {orden_ctx[0]['nombre'].lower()}")
                   if orden_ctx else "Tu semana, en cifras"),
        "total": total,
        "media": anterior,
        "diasActivos": len(activos),
        "semana": barras,
        "mejorDia": barras[mejor]["dia"] if mejor >= 0 else "",
        "inicio": de_hoy(hora_tipica([seg(d["inicio"]) for d in activos if d["inicio"]])),
        "madrugada": sum(d["madrugada"] for d in por_dia),
        "fin": de_hoy(hora_tipica([seg(d["fin"]) for d in activos if d["fin"]])),
        "apps": [dict(a, porcentaje=round(100 * a["segundos"] / total) if total else 0) for a in top[:TOP]],
        "otras": sum(a["segundos"] for a in top[TOP:]),
        "numeroApps": len(nombres_apps),
        "horas": horas,
        "horaPico": max(range(24), key=lambda h: horas[h]) if total else -1,
        "racha": racha,
        "saltos": sum(d["saltos"] for d in por_dia),
        "contextos": orden_ctx[:4],
        "tramos": tramos[-600:],
        "musica": musica(*dias),
        "capturas": capturas(*dias),
        "archivos": sum(d["archivos"] for d in por_dia),
    }


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dia", type=dt.date.fromisoformat, default=None)
    p.add_argument("--semana", action="store_true", help="los 7 días que acaban en --dia (o hoy)")
    a = p.parse_args()
    dia = a.dia or dt.date.today()
    print(json.dumps(semana(dia) if a.semana else datos(dia), ensure_ascii=False))


if __name__ == "__main__":
    main()
