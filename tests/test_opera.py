import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'hypr/.config/hypr/scripts'
sys.path.insert(0, str(SCRIPTS))
import buscar

spec = importlib.util.spec_from_file_location('opera_gx', SCRIPTS / 'opera-gx.py')
og = importlib.util.module_from_spec(spec)
spec.loader.exec_module(og)


def registro(tipo, datos):
    return struct.pack('<HB', len(datos) + 1, tipo) + datos


def navegacion(pestana, indice, url, titulo):
    u = url.encode()
    t = titulo.encode('utf-16-le')
    cuerpo = struct.pack('<iii', pestana, indice, len(u)) + u + b'\0' * (-len(u) % 4)
    cuerpo += struct.pack('<i', len(titulo)) + t + b'\0' * (-len(t) % 4)
    return registro(6, struct.pack('<i', len(cuerpo)) + cuerpo)


class SesionOpera(unittest.TestCase):
    def test_pestanas_abiertas_con_su_pagina_actual(self):
        datos = b'SNSS' + struct.pack('<i', 3)
        datos += registro(0, struct.pack('<ii', 1, 10)) + registro(0, struct.pack('<ii', 1, 11))
        datos += registro(0, struct.pack('<ii', 2, 12))
        datos += navegacion(10, 0, 'https://a.com/', 'A vieja') + navegacion(10, 1, 'https://a.com/nueva', 'Á nueva')
        datos += registro(7, struct.pack('<ii', 10, 1))
        datos += navegacion(11, 0, 'https://cerrada.com/', 'Cerrada') + registro(16, struct.pack('<iq', 11, 0))
        datos += navegacion(12, 0, 'https://otra-ventana.com/', 'Ventana cerrada') + registro(17, struct.pack('<iq', 2, 0))
        self.assertEqual(buscar.leer_sesion(datos), [('https://a.com/nueva', 'Á nueva')])

    def test_archivo_que_no_es_sesion(self):
        self.assertEqual(buscar.leer_sesion(b'basura'), [])


class ModOpera(unittest.TestCase):
    def test_id_de_extension_desempaquetada(self):
        # Chromium: sha256 de la ruta, 32 cifras hex pasadas a a-p (comprobado con Opera GX 140)
        self.assertEqual(og.id_extension(Path('/home/oscar/.local/share/opera-gx-orion')), 'cimifemjbdljkdmdnnddekliehlefgnh')

    def test_mod_con_paleta_y_wallpaper(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / 'estado').mkdir()
            (d / 'estado/colores.css').write_text('@define-color fondo #121519;\n@define-color acento #ddc66e;\n@define-color texto #edf0f5;')
            (d / 'fondo.jpg').write_bytes(b'jpg')
            (d / 'estado/wallpaper').symlink_to(d / 'fondo.jpg')
            with patch.object(og, 'ESTADO', d / 'estado'), patch.object(og, 'MOD', d / 'mod'):
                og.generar()
            m = json.loads((d / 'mod/manifest.json').read_text())['mod']['payload']
            self.assertEqual(m['theme'][0]['dark']['gx_accent']['h'], 47.6)
            self.assertTrue((d / 'mod' / m['wallpaper'][0]['dark']['preview']['352x248']).exists())
            self.assertTrue(all('id' in e for e in m['page_styles']))   # GX rechaza el mod si falta

    def test_activar_elige_el_mod_y_quita_sonidos(self):
        with tempfile.TemporaryDirectory() as d:
            prefs = Path(d) / 'Preferences'
            prefs.write_text(json.dumps({'gx': {'sounds_browser_sounds_set': 'mods/x/1'}, 'otra': 1}))
            with patch.object(og, 'PREFS', prefs), patch.object(og, 'MOD', Path('/m')):
                og.activar()
            p = json.loads(prefs.read_text())
            self.assertTrue(p['ui']['active_theme_id'].endswith('/orion'))
            self.assertEqual(p['rich_wallpapers']['selected_id'], p['ui']['active_theme_id'])
            self.assertNotIn('sounds_browser_sounds_set', p['gx'])
            self.assertEqual(p['otra'], 1)


if __name__ == '__main__':
    unittest.main()
