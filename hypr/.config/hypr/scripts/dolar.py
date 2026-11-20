#!/usr/bin/env python3
"""Dólar de hoy para el lanzador (SUPER+R → «dolar hoy») y tasas de cambio al día.

  dolar.py              JSON {resultados, errores}: TRM oficial de hoy, dólar y euro de mercado
  dolar.py actualizar   baja la TRM y las tasas de qalc (lo corre tasas-cambio.timer cada día)

TRM: Superintendencia Financiera vía datos.gov.co (sin clave). Mercado: las tasas de qalc
(~/.local/share/qalculate/rates.json), las mismas que usa la calculadora del lanzador («100 USD a COP»).
"""
from datetime import date, datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

TRM_URL = 'https://www.datos.gov.co/resource/32sa-8pi3.json?$order=vigenciadesde%20DESC&$limit=2'
CACHE = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'tasas' / 'trm.json'
QALC_TASAS = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'qalculate' / 'rates.json'
MESES = 'ene feb mar abr may jun jul ago sep oct nov dic'.split()


def pesos(v):
    """3415.1 → «$3.415,10» (formato colombiano)."""
    entero, dec = f'{v:,.2f}'.split('.')
    return '$' + entero.replace(',', '.') + ',' + dec


def fecha_corta(d):
    return f'{d.day} {MESES[d.month - 1]}'


def bajar_trm(plazo=5):
    with urllib.request.urlopen(urllib.request.Request(TRM_URL, headers={'User-Agent': 'dolar.py'}), timeout=plazo) as r:
        filas = json.load(r)
    trm = [{'valor': float(f['valor']), 'fecha': f['vigenciadesde'][:10]} for f in filas]
    if not trm:
        raise ValueError('sin datos')
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    tmp = CACHE.with_suffix('.tmp')
    tmp.write_text(json.dumps({'trm': trm, 'consultado': datetime.now().isoformat(timespec='seconds')}))
    tmp.replace(CACHE)
    return trm


def leer_cache():
    try:
        return json.loads(CACHE.read_text())['trm']
    except (OSError, ValueError, KeyError):
        return None


def trm_hoy(errores):
    """TRM más reciente: de la caché si ya es la de hoy; si no, la baja (y si falla, la de la caché)."""
    trm = leer_cache()
    if trm and trm[0]['fecha'] >= date.today().isoformat():
        return trm
    try:
        return bajar_trm(plazo=4)
    except Exception:
        errores.append('TRM: sin conexión' + (', se muestra la última guardada' if trm else ''))
        return trm


def qalc(expr):
    try:
        out = subprocess.run(['qalc', '-t', expr], capture_output=True, text=True, timeout=4).stdout.strip()
        return float(out.split('\n')[-1].split()[-1])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return None


def fecha_qalc():
    try:
        return date.fromisoformat(json.loads(QALC_TASAS.read_text())['date'])
    except (OSError, ValueError, KeyError):
        return None


def copiar(v):
    return ['wl-copy', f'{v:.2f}']


def consultar():
    errores, res = [], []
    trm = trm_hoy(errores)
    if trm:
        hoy = trm[0]
        d = date.fromisoformat(hoy['fecha'])
        detalle = 'TRM oficial ' + ('de hoy' if d == date.today() else 'del ' + fecha_corta(d))
        if len(trm) > 1:
            dif = hoy['valor'] - trm[1]['valor']
            detalle += f"   ·   {'▲' if dif > 0 else '▼' if dif < 0 else '='} {pesos(abs(dif))} vs. el {fecha_corta(date.fromisoformat(trm[1]['fecha']))}"
        res.append({'nombre': pesos(hoy['valor']) + ' COP', 'detalle': detalle + '   ·   Enter: copiar',
                    'glifo': 0xF01C1, 'cmd': copiar(hoy['valor'])})
    dq = fecha_qalc()
    sello = ('tasas del ' + fecha_corta(dq)) if dq else 'tasas sin actualizar'
    if dq and (date.today() - dq).days > 1:
        errores.append('Tasas de mercado del ' + fecha_corta(dq) + ': revisa tasas-cambio.timer')
    for moneda, nombre, glifo in (('USD', 'Dólar', 0xF01C1), ('EUR', 'Euro', 0xF01AD)):
        v = qalc(f'1 {moneda} to COP')
        if v:
            res.append({'nombre': pesos(v) + ' COP', 'detalle': f'{nombre} de mercado ({sello})   ·   Enter: copiar',
                        'glifo': glifo, 'cmd': copiar(v)})
    if not res:
        errores.append('No hay datos del dólar')
    return {'resultados': res, 'errores': errores}


def actualizar():
    fallos = []
    try:
        bajar_trm(plazo=20)
    except Exception as e:
        fallos.append(f'TRM: {e}')
    try:
        subprocess.run(['qalc', '-e', '-t', '1 USD to COP'], capture_output=True, timeout=90, check=True)
        if fecha_qalc() != date.today():
            fallos.append('qalc: las tasas no son de hoy')
    except (OSError, subprocess.SubprocessError) as e:
        fallos.append(f'qalc: {e}')
    for f in fallos:
        print(f, file=sys.stderr)
    return 1 if fallos else 0


if __name__ == '__main__':
    if sys.argv[1:] == ['actualizar']:
        sys.exit(actualizar())
    print(json.dumps(consultar(), ensure_ascii=False))
