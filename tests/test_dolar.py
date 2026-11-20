"""Dólar de hoy del lanzador: formato, caché de la TRM y respaldo sin conexión."""
from datetime import date, timedelta
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS=Path(__file__).resolve().parents[1]/'hypr/.config/hypr/scripts'
spec=importlib.util.spec_from_file_location('dolar',SCRIPTS/'dolar.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)

class Dolar(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);p=Path(self.tmp.name)
        self.cache=p/'trm.json';self.tasas=p/'rates.json'
        for a,b in (('CACHE',self.cache),('QALC_TASAS',self.tasas)):
            pa=patch.object(d,a,b);pa.start();self.addCleanup(pa.stop)
        self.tasas.write_text(json.dumps({'date':date.today().isoformat()}))
    def guardar(self,*filas):self.cache.write_text(json.dumps({'trm':[{'valor':v,'fecha':f} for v,f in filas]}))
    def test_formato_colombiano(self):
        self.assertEqual(d.pesos(3415.1),'$3.415,10');self.assertEqual(d.pesos(88.14),'$88,14')
    def test_usa_cache_de_hoy_sin_red_y_muestra_variacion(self):
        hoy=date.today();self.guardar((3415.1,hoy.isoformat()),(3326.96,(hoy-timedelta(1)).isoformat()))
        with patch.object(d,'bajar_trm',side_effect=AssertionError('no debe bajar')),patch.object(d,'qalc',return_value=3429.94):r=d.consultar()
        self.assertEqual(r['errores'],[]);self.assertEqual(r['resultados'][0]['nombre'],'$3.415,10 COP')
        self.assertIn('de hoy',r['resultados'][0]['detalle']);self.assertIn('▲ $88,14',r['resultados'][0]['detalle'])
        self.assertEqual(r['resultados'][0]['cmd'],['wl-copy','3415.10'])
    def test_cache_vieja_y_sin_red_avisa_y_muestra_la_ultima(self):
        self.guardar((3300.0,'2026-01-02'))
        with patch.object(d,'bajar_trm',side_effect=OSError('sin red')),patch.object(d,'qalc',return_value=None):r=d.consultar()
        self.assertIn('del 2 ene',r['resultados'][0]['detalle']);self.assertTrue(any('sin conexión' in e for e in r['errores']))
    def test_avisa_si_las_tasas_de_qalc_son_viejas(self):
        self.tasas.write_text(json.dumps({'date':(date.today()-timedelta(5)).isoformat()}))
        with patch.object(d,'bajar_trm',side_effect=OSError),patch.object(d,'qalc',return_value=3400.0):r=d.consultar()
        self.assertTrue(any('tasas-cambio.timer' in e for e in r['errores']));self.assertEqual(len(r['resultados']),2)

if __name__=='__main__':unittest.main()
