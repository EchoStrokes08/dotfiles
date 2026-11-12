"""Permisos y herramientas generales sin modelo, red ni sesión gráfica."""
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import agente
import agente_sistema as sistema
import agente_navegador as navegador


class Herramientas(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.patches = [patch.object(agente, "HOME", self.home), patch.object(sistema, "HOME", self.home),
                        patch.object(agente, "DIR", self.home / "estado")]
        for p in self.patches:
            p.start()
        c = self.home / ".config/ia/permisos.json"
        c.parent.mkdir(parents=True)
        c.write_text('{"modo":"autonomo"}')
        agente.VISTA.clear()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        agente.VISTA.clear()
        self.tmp.cleanup()

    def test_permisos(self):
        for argv in [["rm", "a"], ["sudo", "pacman", "-S", "algo"], ["sh", "-c", "ls"],
                     ["python3", "-c", "print(1)"], ["date", "-s", "tomorrow"]]:
            self.assertTrue(agente.requiere_confirmacion("ejecutar_comando", {"argumentos": argv}))
        self.assertFalse(agente.requiere_confirmacion("ejecutar_comando", {"argumentos": ["ls", "-l"]}))
        self.assertFalse(agente.requiere_confirmacion("escribir_archivo", {"ruta": str(self.home / "Documents/a.txt")}))
        for p in [self.home / ".config/ia/permisos.json", self.home / "dotfiles/a", Path("/etc/hosts")]:
            self.assertTrue(agente.requiere_confirmacion("escribir_archivo", {"ruta": str(p)}))
        enlace = self.home / "documento"
        enlace.symlink_to("/etc/hosts")
        self.assertFalse(sistema.ruta_personal(str(enlace)))

    def test_escritura_prepara_sin_cambiar_y_respalda(self):
        p = self.home / "a.txt"
        p.write_text("antes")
        descripcion, hacer = sistema.preparar_escritura(str(p), "después")
        self.assertEqual(p.read_text(), "antes")
        self.assertIn("después", descripcion)
        hacer()
        self.assertEqual(p.read_text(), "después")
        copias = list(sistema._respaldos().iterdir())
        self.assertEqual(copias[0].read_text(), "antes")

    def test_comando_devuelve_errores_y_no_evalua_shell(self):
        _, hacer = sistema.preparar_comando([sys.executable, "-c", "import sys; print('fallo'); sys.exit(3)"], str(self.home))
        self.assertIn("Código de salida: 3\nfallo", hacer())
        _, hacer = sistema.preparar_comando(["/usr/bin/printf", "%s", "$(touch peligro)"], str(self.home))
        self.assertIn("$(touch peligro)", hacer())
        self.assertFalse((self.home / "peligro").exists())

    def test_accion_automatica_y_confirmacion_real(self):
        respuestas = iter([("", [{"function": {"name": "escribir_archivo", "arguments": {
            "ruta": str(self.home / "nota.txt"), "contenido": "hola"}}}]), ("Guardado.", [])])
        with patch.object(agente, "chat", lambda *a, **k: next(respuestas)), redirect_stdout(io.StringIO()) as out:
            agente.turno("Crea una nota")
        self.assertNotIn('"t": "confirmar"', out.getvalue())
        self.assertEqual((self.home / "nota.txt").read_text(), "hola")
        respuestas = iter([("", [{"function": {"name": "ejecutar_comando", "arguments": {
            "argumentos": ["rm", str(self.home / "nota.txt")]}}}]), ("Cancelado.", [])])
        with patch.object(agente, "chat", lambda *a, **k: next(respuestas)), redirect_stdout(io.StringIO()) as out:
            agente.turno("Borra la nota")
            self.assertTrue((self.home / "nota.txt").exists())
            agente.confirmar(False)
        self.assertIn('"t": "confirmar"', out.getvalue())
        self.assertTrue((self.home / "nota.txt").exists())

    def test_navegador_y_urls(self):
        for url in ["file:///etc/passwd", "javascript:alert(1)", "https://user:password@example.com", "http://"]:
            with self.assertRaises(ValueError):
                navegador.validar_url(url)
        with patch.object(navegador, "llamar", return_value="página") as llamar:
            self.assertEqual(navegador.buscar("Linux español"), "página")
            self.assertIn("Linux+espa%C3%B1ol", llamar.call_args.kwargs["url"])
            _, hacer = navegador.preparar("clic", selector="#enviar")
            self.assertEqual(llamar.call_count, 1)
            hacer()
            self.assertEqual(llamar.call_count, 2)
        self.assertTrue(agente.requiere_confirmacion("navegador", {"accion": "clic"}))

    def test_borrado_solo_despues_del_si(self):
        p = self.home / "nota.txt"
        p.write_text("hola")
        respuestas = iter([("", [{"function": {"name": "ejecutar_comando", "arguments": {
            "argumentos": ["/usr/bin/rm", str(p)]}}}]), ("Borrada.", [])])
        with patch.object(agente, "chat", lambda *a, **k: next(respuestas)), redirect_stdout(io.StringIO()):
            agente.turno("Borra la nota")
            self.assertTrue(p.exists())
            agente.confirmar(True)
        self.assertFalse(p.exists())

    def test_navegador_ausente_error_util_sin_arrancar(self):
        with patch.object(navegador, "disponible", return_value=False), patch.object(navegador.subprocess, "Popen") as popen:
            with self.assertRaisesRegex(ValueError, "agente-navegador-instalar.sh"):
                navegador.navegar("https://example.com")
            popen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
