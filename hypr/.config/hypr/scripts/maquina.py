#!/usr/bin/env python3
"""Máquina del tiempo: los momentos de un día para viajar por ellos (Maquina.qml / CapaMaquina.qml).

Un momento es un rato seguido en una app (≥ 2 min; las interrupciones cortas de otra app no lo cortan),
con los títulos que tuvo la ventana, el contexto de Brújula, los archivos que abriste mientras tanto y,
si las capturas cifradas de Brújula están activas, la captura más cercana a su mitad (descifrada en
$XDG_RUNTIME_DIR; `brujula.py capturas limpiar` la borra al cerrar). Todo local.

Uso
  maquina.py [--dia AAAA-MM-DD]     JSON: {dia, dias, momentos (del más reciente al más antiguo), apps}
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).parent))
import brujula as b  # noqa: E402

MINIMO = 120        # s para que un rato cuente como momento
HUECO = 120         # s de otra app que no cortan un momento
MAXIMO = 150        # momentos por día (los más recientes)


def momentos(bloques):
    res = []
    for x in bloques:
        if res and res[-1]["clase"] != x["clase"] and res[-1]["activo"] < MINIMO:
            res.pop()       # un vistazo a otra app: no es momento y no corta el de antes
        ultimo = res[-1] if res else None
        if ultimo and ultimo["clase"] == x["clase"] and x["inicio"] - ultimo["fin"] <= HUECO:
            ultimo["fin"] = x["fin"]
            ultimo["activo"] += x["fin"] - x["inicio"]
            for t in x["titulos"]:
                if t not in ultimo["titulos"]:
                    ultimo["titulos"].append(t)
            ultimo["contexto"] = ultimo["contexto"] or x["contexto"]
            continue
        res.append({"inicio": x["inicio"], "fin": x["fin"], "activo": x["fin"] - x["inicio"], "clase": x["clase"],
                    "nombre": x["nombre"], "titulos": list(x["titulos"]), "contexto": x["contexto"], "privado": x["privado"]})
    if res and res[-1]["activo"] < MINIMO:
        res.pop()
    return res


def hora_de_captura(ruta, dia):
    try:
        h = Path(ruta).name.split(".")[0]
        return int(dt.datetime.combine(dia, dt.time(int(h[:2]), int(h[2:4]), int(h[4:6]))).timestamp())
    except (ValueError, IndexError):
        return None


def datos(dia):
    ms = momentos(b.bloques(dia))
    archivos = b.archivos_del_dia(dia)
    capturas = [(hora_de_captura(r, dia), r) for r in b.capturas_del_dia(dia)]
    capturas = [c for c in capturas if c[0]]
    for m in ms:
        m["archivos"] = [{"ruta": a["ruta"], "nombre": a["nombre"]} for a in archivos
                         if m["inicio"] <= a["t"] <= m["fin"] and a["existe"]][-4:]
        mitad = (m["inicio"] + m["fin"]) / 2
        dentro = [c for c in capturas if m["inicio"] <= c[0] <= m["fin"]]
        m["captura"] = min(dentro, key=lambda c: abs(c[0] - mitad))[1] if dentro else ""
        m["titulos"] = [] if m["privado"] else m["titulos"][-3:]
    # Color estable por app: las más usadas del día primero
    peso = {}
    for m in ms:
        peso[m["clase"]] = peso.get(m["clase"], 0) + m["activo"]
    apps = [c for c, _ in sorted(peso.items(), key=lambda p: -p[1])]
    for m in ms:
        m["app"] = apps.index(m["clase"])
    dias = sorted((f.stem for f in b.LINEA.glob("*.jsonl")), reverse=True) if b.LINEA.is_dir() else []
    return {"dia": dia.isoformat(), "hoy": dia == dt.date.today(), "dias": dias[:30],
            "momentos": list(reversed(ms))[:MAXIMO], "capturas": bool(capturas)}


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dia", type=dt.date.fromisoformat, default=None)
    a = p.parse_args()
    dia = a.dia or dt.date.today()
    if b.escritorio().get("privacidad_activa") == "true":
        print(json.dumps({"dia": dia.isoformat(), "privado": True, "momentos": [], "dias": []}))
        return
    print(json.dumps(datos(dia), ensure_ascii=False))


if __name__ == "__main__":
    main()
