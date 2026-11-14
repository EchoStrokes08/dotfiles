#!/usr/bin/env python3
"""Markdown y TeX locales para el visor Qt; entrada/salida JSON por stdin/stdout."""
import hashlib
import html
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlparse

MOTOR = Path(__file__).with_name('vendor') / 'mathjax' / 'render.cjs'
# Se reconocen primero los bloques y spans de código: sus dólares son literales.
TOKENS = re.compile(r'(?P<code>^[ \t]*(?P<fence>`{3,}|~{3,})[^\n]*\n.*?^[ \t]*(?P=fence)[ \t]*$|(?P<ticks>`+)[^`\n]*?(?P=ticks))|(?P<block>\$\$(?P<dollar>.*?)\$\$|\\\[(?P<bracket>.*?)\\\])|(?P<inline>\\\((?P<paren>.*?)\\\)|(?<![\\\w])\$(?![\s$]|\d+(?:[.,]\d+)?\s)(?P<single>[^\n$]*?[^\s$])\$(?![\d$]))', re.M | re.S)

class Limpiar(HTMLParser):
    """Qt acepta un subconjunto HTML: sin imágenes remotas ni enlaces ejecutables."""
    tags = {'p','br','hr','strong','b','em','i','s','del','ul','ol','li','blockquote','pre','code','h1','h2','h3','h4','h5','h6','table','thead','tbody','tr','td','th','a','sup','sub'}
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.salida=[]
    def handle_starttag(self, tag, attrs):
        if tag not in self.tags:return
        at=dict(attrs); extra=''
        if tag=='a':
            url=at.get('href','')
            if urlparse(url).scheme in ('http','https','mailto'):
                extra=' href="'+html.escape(url,quote=True)+'"'
        if tag=='table':extra=' border="1" cellspacing="0" cellpadding="6"'
        self.salida.append('<'+tag+extra+'>')
    def handle_endtag(self,tag):
        if tag in self.tags and tag not in {'br','hr'}:self.salida.append('</'+tag+'>')
    def handle_data(self,data):self.salida.append(html.escape(data))


def renderizar(texto, color='#edf0f5', ancho=800, cache=None):
    import markdown
    if len(texto)>250000:raise ValueError('El mensaje supera el tamaño admitido')
    if not re.fullmatch(r'#[0-9a-fA-F]{6}',color):color='#edf0f5'
    ancho=max(100,min(2000,int(ancho)))
    formulas=[]
    prefijo='ORION'+hashlib.sha256(texto.encode()).hexdigest()[:16]+'MATH'
    def extraer(m):
        if m.group('code'):return m.group()
        tex=next(m.group(k) for k in ('dollar','bracket','paren','single') if m.group(k) is not None)
        if len(formulas)>=200 or len(tex)>16000:return m.group()
        clave=prefijo+str(len(formulas))+'FIN'
        formulas.append({'tex':tex,'display':bool(m.group('block')),'clave':clave})
        return '\n\n'+clave+'\n\n' if m.group('block') else clave
    contenido=TOKENS.sub(extraer,texto)
    md=markdown.Markdown(extensions=['fenced_code','tables','sane_lists'])
    md.preprocessors.deregister('html_block')
    md.inlinePatterns.deregister('html')
    limpio=Limpiar();limpio.feed(md.convert(contenido))
    resultado=''.join(limpio.salida)
    errores=[]; representadas=0
    if formulas:
        try:
            p=subprocess.run(['node',str(MOTOR)],input=json.dumps(formulas),text=True,capture_output=True,timeout=12)
            if p.returncode:raise RuntimeError('Motor matemático no disponible')
            imagenes=json.loads(p.stdout)
            if len(imagenes)!=len(formulas):raise RuntimeError('Respuesta incompleta del motor')
        except (OSError,subprocess.TimeoutExpired,ValueError,RuntimeError):
            imagenes=[{'error':'No se pudo iniciar el renderizado matemático local'}]*len(formulas)
        carpeta=Path(cache) if cache else Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache'))) / 'orion' / 'formulas'
        carpeta.mkdir(parents=True,exist_ok=True,mode=0o700)
        os.chmod(carpeta,0o700)
        for f,im in zip(formulas,imagenes):
            if im.get('error'):
                errores.append(im['error']); etiqueta='<code>'+html.escape(f['tex'])+'</code>'
            else:
                svg=im['svg'].replace('currentColor',color)
                nombre=hashlib.sha256((svg+'png3x-v1').encode()).hexdigest()+'.png'
                destino=carpeta/nombre
                w_natural=im['width']*16/14; h_natural=im['height']*16/14
                escala=min(1,(ancho-12)/max(1,w_natural))
                w=max(1,round(w_natural*escala));h=max(1,round(h_natural*escala))
                if not destino.exists():
                    try:
                        png=subprocess.run(['rsvg-convert','--width',str(max(3,round(w_natural*3))),
                                            '--height',str(max(3,round(h_natural*3)))],input=svg.encode(),capture_output=True,timeout=5,check=True).stdout
                        import tempfile
                        with tempfile.NamedTemporaryFile(dir=carpeta,delete=False) as archivo:
                            archivo.write(png);temporal=archivo.name
                        os.replace(temporal,destino)
                    except (OSError,subprocess.SubprocessError):
                        errores.append('No se pudo dibujar una fórmula; se conserva el original')
                        resultado=resultado.replace(f['clave'],'<code>'+html.escape(f['tex'])+'</code>')
                        continue
                etiqueta=f'<img src="{destino.as_uri()}" width="{w}" height="{h}" alt="{html.escape(f["tex"],quote=True)}">'
                representadas+=1
            resultado=resultado.replace(f['clave'],etiqueta)
    luminoso=sum(int(color[i:i+2],16) for i in (1,3,5))<384
    enlace='#315f99' if luminoso else '#9abcf1'
    estilo='<style>a {color:'+enlace+';} p {margin-top:6px; margin-bottom:8px;} h1,h2,h3 {margin-top:14px; margin-bottom:8px;} pre,code {font-family:monospace;} pre {white-space:pre-wrap;} table {border-collapse:collapse;}</style>'
    return {'html':estilo+resultado,'formulas':representadas,'avisos':list(dict.fromkeys(errores))}


def main():
    try:
        d=json.loads(sys.stdin.readline(1500000))
        print(json.dumps(renderizar(d.get('texto',''),d.get('color','#edf0f5'),d.get('ancho',800)),ensure_ascii=False))
    except Exception:
        print(json.dumps({'error':'No se pudo preparar el mensaje. Puedes copiar su texto original.'}))
        return 1
    return 0

if __name__=='__main__':sys.exit(main())
