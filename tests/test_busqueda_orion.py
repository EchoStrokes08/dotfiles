"""Coordinador real de procesos: errores parciales, incremental y cancelación."""
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPTS=Path(__file__).resolve().parents[1]/'hypr/.config/hypr/scripts'
spec=importlib.util.spec_from_file_location('busqueda_orion',SCRIPTS/'busqueda.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)

class Busqueda(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.p=Path(self.tmp.name)
    def test_emite_resultados_antes_de_terminar_y_errores_por_fuente(self):
        (self.p/'buscar.py').write_text('''import json,sys,time
if sys.argv[1]=='lenta':time.sleep(.12)
print(json.dumps({'resultados':[{'nombre':sys.argv[2]}],'errores':['sin conexión'] if sys.argv[1]=='fallida' else []}))
''')
        out=io.StringIO()
        with patch.object(b,'SCRIPTS',self.p),patch.object(b,'GRUPOS',[('rapida','Rápida'),('lenta','Lenta'),('fallida','Fallida')]),patch('sys.stdout',out):b.buscar('todo','consulta vigente')
        lineas=[json.loads(x) for x in out.getvalue().splitlines()]
        self.assertTrue(any(x['cargando'] and x['resultados'] for x in lineas))
        self.assertFalse(lineas[-1]['cargando']);self.assertEqual(len(lineas[-1]['resultados']),3)
        self.assertEqual(lineas[-1]['errores'],['Fallida: sin conexión'])
    def test_fuente_sin_coincidencias_no_es_error(self):
        (self.p/'buscar.py').write_text('print(\'{"resultados":[],"errores":[]}\')')
        out=io.StringIO()
        with patch.object(b,'SCRIPTS',self.p),patch('sys.stdout',out):b.buscar('notas','nada')
        fin=json.loads(out.getvalue().splitlines()[-1]);self.assertEqual(fin['resultados'],[]);self.assertEqual(fin['errores'],[])
    def test_cancelar_termina_el_proceso_hijo(self):
        import shutil
        shutil.copy(SCRIPTS/'busqueda.py',self.p)
        (self.p/'buscar.py').write_text('import os,time\nfrom pathlib import Path\nPath(__file__).with_suffix(".pid").write_text(str(os.getpid()))\ntime.sleep(30)')
        p=subprocess.Popen([sys.executable,str(self.p/'busqueda.py'),'notas','vieja'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            limite=time.monotonic()+3
            while not (self.p/'buscar.pid').exists() and time.monotonic()<limite:time.sleep(.02)
            self.assertTrue((self.p/'buscar.pid').exists());pid=int((self.p/'buscar.pid').read_text())
            p.terminate();p.communicate(timeout=3)
            with self.assertRaises(ProcessLookupError):os.kill(pid,0)
        finally:
            if p.poll() is None:p.kill();p.communicate()
