"""Tema: contraste real, publicación coherente, caché, fallos y peticiones obsoletas."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

RAIZ = Path(__file__).resolve().parents[1]
SCRIPTS = RAIZ / 'hypr/.config/hypr/scripts'
spec = importlib.util.spec_from_file_location('tema_orion', SCRIPTS / 'tema.py')
tema = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tema)


class Tema(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.out = self.home / 'state'
        self.out.mkdir()
        self.dir = self.home / 'config'
        shutil.copytree(RAIZ / 'tema/.config/tema', self.dir)
        for nombre, valor in [('HOME',self.home),('OUT',self.out),('DIR',self.dir),('CACHE',self.out/'generaciones')]:
            p=patch.object(tema,nombre,valor);p.start();self.addCleanup(p.stop)
        self.imagen = self.home / 'wallpaper.png'
        self.imagen.write_bytes(b'foto de prueba')
        (self.out/'peticion').write_text('actual')
        self.colores = {'colors': {'primary': {'default': {'color':'#8099aa'}}, 'tertiary': {'default': {'color':'#c09b82'}}}}

    def generar(self, modo='ayu', variante='oscuro', token='actual'):
        return tema.generar(modo,variante,self.imagen,token)

    def test_claro_y_oscuro_contraste_de_textos_y_acento_solido(self):
        for variante in ('oscuro','claro'):
            with self.subTest(variante=variante), patch.object(tema,'comando',return_value=json.dumps(self.colores)):
                p=tema.paleta('wallpaper',variante,self.imagen)
            for fondo in (p['fondo'],p['seleccion'],tema.mezcla(p['fondo'],p['texto'],.035),tema.mezcla(p['fondo'],p['texto'],.065),tema.mezcla(p['fondo'],p['acento'],.16)):
                self.assertGreaterEqual(tema.contraste(p['texto'],fondo),4.5)
                self.assertGreaterEqual(tema.contraste(p['gris'],fondo),4.5)
                tenue=tema.mezcla(p['fondo'],p['texto'],.82 if variante=='claro' else .68)
                self.assertGreaterEqual(tema.contraste(tenue,fondo),4.5)
            for rol in ('acento','acento2','aviso','exito','peligro'):
                self.assertGreaterEqual(tema.contraste(p[rol],p['fondo']),4.5)
            self.assertGreaterEqual(tema.contraste(p['sobreAcento'],p['acento']),4.5)

    def test_imagen_no_tine_superficies_y_todas_las_plantillas_resuelven(self):
        with patch.object(tema,'comando',return_value=json.dumps(self.colores)):
            p=tema.paleta('wallpaper','oscuro',self.imagen)
        archivos=tema.renderizar(p,'oscuro')
        self.assertEqual(p['fondo'],'#121519')
        for nombre in ('colores.css','kitty.conf','fuzzel.ini','gtk3.css','gtk4.css','btop.theme'):
            self.assertIn('121519',archivos[nombre],nombre)
            self.assertNotIn('{{',archivos[nombre])

    def test_generacion_completa_se_publica_mediante_un_enlace(self):
        self.assertTrue(self.generar())
        carpeta=(self.out/'actual').resolve()
        for nombre in ('colores.css','kitty.conf','gtk3.css','firefox.css','hyprland.lua'):
            self.assertTrue((self.out/nombre).is_symlink())
            self.assertEqual((self.out/nombre).resolve().parent,carpeta)
        self.assertTrue((self.out/'version').is_file())

    def test_cache_evitar_reextraer_imagen(self):
        with patch.object(tema,'comando',return_value=json.dumps(self.colores)) as extraer:
            self.generar('wallpaper');self.generar('wallpaper')
        self.assertEqual(extraer.call_count,1)

    def test_fallo_no_publica_archivos_a_medias(self):
        self.generar()
        anterior=(self.out/'actual').resolve()
        with patch.object(tema,'comando',side_effect=ValueError('matugen falló')):
            with self.assertRaises(ValueError):self.generar('wallpaper')
        self.assertEqual((self.out/'actual').resolve(),anterior)

    def test_peticion_obsoleta_no_pisa_la_actual(self):
        self.generar()
        anterior=(self.out/'actual').resolve()
        self.assertFalse(self.generar(variante='claro',token='antigua'))
        self.assertEqual((self.out/'actual').resolve(),anterior)
        self.assertEqual((self.out/'variante').read_text(),'oscuro')

    def test_fijado_no_vuelve_a_extraer_al_rotar(self):
        (self.out/'acento-fijo.json').write_text(json.dumps({'acento':'#a6c8ff','acento2':'#dabde2'}))
        with patch.object(tema,'comando') as extraer:
            self.generar('wallpaper')
        extraer.assert_not_called()
        self.assertTrue(json.loads((self.out/'preferencias.json').read_text())['fijado'])

    def test_migracion_conserva_generacion_previa(self):
        (self.out/'colores.css').write_text('anterior')
        self.generar()
        self.assertEqual((self.out/'generacion-inicial/colores.css').read_text(),'anterior')

    def test_contraste_color_extremo_se_corrige(self):
        for fondo in ('#121519','#f5f6f8'):
            for acento in ('#121519','#f5f6f8','#777777','#ff00ff','#00ff00'):
                self.assertGreaterEqual(tema.contraste(tema.ajustar(acento,fondo),fondo),4.5)


if __name__=='__main__': unittest.main()
