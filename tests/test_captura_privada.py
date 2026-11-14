import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
S=Path(__file__).resolve().parents[1]/'hypr/.config/hypr/scripts'
spec=importlib.util.spec_from_file_location('captura_privada',S/'captura_privada.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

class Captura(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.env=patch.dict(os.environ,{'XDG_RUNTIME_DIR':self.tmp.name});self.env.start();self.addCleanup(self.env.stop)
    def test_expiracion_absoluta_y_liberacion_solo_por_dueno(self):
        c.escribir({'activo':True,'token':'actual','expira':2000})
        self.assertTrue(c.vigente(c.leer(),1000));self.assertFalse(c.vigente(c.leer(),2001))
        c.liberar('anterior');self.assertTrue(c.leer()['activo']);c.liberar('actual');self.assertFalse(c.leer()['activo'])
    def test_fallo_restaurar_privacidad(self):
        p=Path(self.tmp.name)/'fallo.sh';p.write_text('exit 1')
        with self.assertRaises(RuntimeError):c.capturar('region',p,0)
        self.assertFalse(c.leer()['activo'])
    def test_cancelacion_no_deja_privacidad_temporal(self):
        with patch.object(c.subprocess,'Popen',side_effect=InterruptedError):
            with self.assertRaises(InterruptedError):c.capturar('region',espera=0)
        self.assertFalse(c.leer()['activo'])
    def test_liberar_despues_de_grim_sin_esperar_notificacion(self):
        p=Path(self.tmp.name)/'captura.sh'
        p.write_text('python3 '+str(S/'captura_privada.py')+' liberar "$ORION_CAPTURA_TOKEN"\nexit 0')
        c.capturar('region',p,0);self.assertFalse(c.leer()['activo'])
