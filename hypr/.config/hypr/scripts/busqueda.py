#!/usr/bin/env python3
"""Búsqueda incremental. Cada fuente y sus hijos tienen plazo y proceso propios."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

SCRIPTS=Path(__file__).resolve().parent
GRUPOS=[('ventanas','Ventanas'),('documentos','Documentos'),('notas','Notas'),('historial','Visitado en Firefox'),('ajustes','Ajustes'),('linea','Línea de tiempo'),('atajos','Atajos'),('portapapeles','Portapapeles')]


def buscar(tipo, consulta):
    fuentes=GRUPOS if tipo=='todo' else [(tipo,tipo.capitalize())]
    pendientes={};resultados=[];errores=[]
    def emitir(cargando):
        print(json.dumps({'consulta':consulta,'resultados':resultados,'errores':errores,'cargando':cargando},ensure_ascii=False),flush=True)
    def interrumpir(*_):raise SystemExit(0)
    previo=signal.signal(signal.SIGTERM,interrumpir)
    try:
        for fuente,nombre in fuentes:
            args=['fd','-i','--max-results','40','--exclude','.cache','--',consulta,str(Path.home())] if fuente=='archivos' else [sys.executable,str(SCRIPTS/'buscar.py'),fuente,consulta,'--estado']
            if fuente=='calc':args=['qalc','-t',consulta]
            try:pendientes[fuente]=(subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True),nombre)
            except OSError:errores.append(nombre+': servicio no disponible')
        limite=time.monotonic()+(2 if tipo=='todo' else 6)
        while pendientes and time.monotonic()<limite:
            for fuente,(p,nombre) in list(pendientes.items()):
                if p.poll() is None:continue
                out,err=p.communicate();pendientes.pop(fuente)
                if p.returncode:errores.append(nombre+': no se pudo consultar')
                else:
                    try:
                        if fuente=='calc':datos=[{'nombre':out.strip().split('\n')[-1]}] if out.strip() else []
                        elif fuente=='archivos':
                            datos=[{'nombre':Path(r).name,'detalle':r.replace(str(Path.home()),'~'),'glifo':0xF0214,'cmd':['xdg-open',r],'referencia':{'tipo':'archivo','id':r}} for r in out.splitlines() if r]
                        else:
                            d=json.loads(out);datos=d['resultados'];errores.extend(nombre+': '+e for e in d['errores'])
                        for item in datos[:4] if tipo=='todo' else datos:
                            item['grupo']=nombre;resultados.append(item)
                    except (ValueError,KeyError,TypeError):errores.append(nombre+': respuesta no válida')
                emitir(bool(pendientes))
            if pendientes:time.sleep(.02)
        errores.extend(nombre+': no respondió a tiempo' for _,nombre in pendientes.values())
        emitir(False)
    finally:
        for p,_ in pendientes.values():
            try:os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            p.communicate()
        signal.signal(signal.SIGTERM,previo)


if __name__=='__main__':buscar(sys.argv[1],sys.argv[2])
