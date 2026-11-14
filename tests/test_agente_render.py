"""Regresiones del visor de respuestas: Markdown, TeX y contenido literal."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

RAIZ=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('agente_render',RAIZ/'hypr/.config/hypr/scripts/agente_render.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)

class Renderizado(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
    def render(self,texto,**kw):return r.renderizar(texto,cache=self.tmp.name,**kw)
    @unittest.skipUnless(shutil.which('node') and shutil.which('rsvg-convert'),'Motor local')
    def test_casos_fracciones_matrices_y_todas_las_delimitaciones(self):
        texto=r'''Con $x_3 \ge 0$, sustituir \(x_1^2\).

$$\begin{cases}2x_1+x_2+x_3=14\\x_1+x_2\ge5\end{cases}$$

\[\frac{1}{2}+\begin{pmatrix}1&2\\3&4\end{pmatrix}\]
'''
        d=self.render(texto)
        self.assertEqual(d['formulas'],4);self.assertEqual(d['avisos'],[])
        self.assertEqual(d['html'].count('<img '),4)
        for p in Path(self.tmp.name).glob('*.png'):
            self.assertTrue(p.read_bytes().startswith(b'\x89PNG'))
    def test_codigo_no_interpreta_dolares_y_tablas_conservan_estructura(self):
        d=self.render('`$x$`\n\n```python\nprint("$$x$$")\n```\n\n| A | B |\n|---|---|\n| 1 | 2 |')
        self.assertEqual(d['formulas'],0);self.assertIn('$$x$$',d['html']);self.assertIn('<table ',d['html'])
    def test_html_imagenes_y_enlaces_no_se_ejecutan(self):
        d=self.render('<script>alert(1)</script>\n\n![remota](https://example.org/a.png)\n\n[mal](file:///etc/passwd)\n\n[bien](https://example.org)')
        self.assertNotIn('<script>',d['html']);self.assertNotIn('<img',d['html'])
        self.assertNotIn('href="file:',d['html']);self.assertIn('href="https://example.org"',d['html'])
    def test_moneda_y_formula_incompleta_siguen_legibles(self):
        d=self.render('Cuesta $5 y $10. Fórmula que llega: $$\\frac{1}{')
        self.assertEqual(d['formulas'],0);self.assertIn('$5',d['html'])
    def test_motor_ausente_avisa_y_conserva_formula(self):
        with patch.object(r.subprocess,'run',side_effect=FileNotFoundError):d=self.render(r'$\frac{1}{2}$')
        self.assertTrue(d['avisos']);self.assertIn(r'\frac{1}{2}',d['html'])
    @unittest.skipUnless(shutil.which('node'),'Motor matemático')
    def test_tex_invalido_no_aparece_como_formula_correcta(self):
        d=self.render(r'$\comandoinexistente{x}$')
        self.assertEqual(d['formulas'],0);self.assertTrue(d['avisos'])
