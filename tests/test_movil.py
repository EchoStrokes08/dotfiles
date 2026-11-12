"""PC + móvil (movil.py): mandos de KDE Connect, acciones fijas y estado, sin móvil real."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import movil  # noqa: E402


class Mandos(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.parches = [patch.object(movil, "HOME", self.home),
                        patch.object(movil, "dispositivo", lambda: ("abc123", None)),
                        patch.object(movil, "emparejado", lambda: "abc123")]
        for p in self.parches:
            p.start()

    def tearDown(self):
        for p in reversed(self.parches):
            p.stop()
        self.tmp.cleanup()

    def test_formato_kconfig_y_conserva_los_tuyos(self):
        archivo = self.home / ".config/kdeconnect/abc123/kdeconnect_runcommand/config"
        archivo.parent.mkdir(parents=True)
        propio = {"x1": {"name": "Mi orden", "command": "echo \"hola\" \\ adiós"}}
        archivo.write_text("[General]\ncommands=@ByteArray(" + json.dumps(propio).replace("\\", "\\\\") + ")\n")
        movil.instalar_comandos()
        movil.instalar_comandos()   # repetir no duplica
        texto = archivo.read_text()
        self.assertTrue(texto.startswith("[General]\ncommands=@ByteArray({"))
        self.assertTrue(all(ord(c) < 128 for c in texto))   # emojis como \uXXXX
        cmds = movil.leer_comandos("abc123")
        self.assertEqual(cmds["x1"], propio["x1"])
        nuestros = [c for c in cmds.values() if movil.YO in c["command"]]
        self.assertEqual(len(nuestros), len(movil.MANDOS))
        self.assertIn("▶ Diapositiva siguiente", [c["name"] for c in nuestros])

    def test_solo_acciones_fijas(self):
        llamadas = []
        with patch.object(movil, "sh", lambda a, timeout=4: llamadas.append(a) or ""), patch.object(movil, "osd", lambda *a: None):
            movil.pc("siguiente")
            movil.pc("bloquear")
            with self.assertRaises(ValueError):
                movil.pc("rm -rf ~")
        self.assertEqual(llamadas, [["wtype", "-k", "Right"], ["loginctl", "lock-session"]])

    def test_enlace_se_abre_y_texto_se_copia(self):
        llamadas = []

        def sh(a, timeout=4):
            llamadas.append(a)
            return self.copiado if a[0] == "wl-paste" else ""
        with patch.object(movil, "sh", sh), patch.object(movil, "osd", lambda *a: None):
            self.copiado = "https://example.org/a"
            movil.enlace()
            self.copiado = "texto normal"
            movil.enlace()
        self.assertIn(["kdeconnect-cli", "-d", "abc123", "--share", "https://example.org/a"], llamadas)
        self.assertIn(["kdeconnect-cli", "-d", "abc123", "--share-text", "texto normal"], llamadas)


class Estado(unittest.TestCase):
    def test_sin_movil(self):
        with patch.object(movil, "dispositivo", lambda: (None, None)), patch.object(movil, "emparejado", lambda: "x"):
            self.assertEqual(movil.estado(), {"conectado": False, "emparejado": True, "nombre": ""})

    def test_dbus_json(self):
        salida = json.dumps({"type": "a{sv}", "data": [{"charge": {"type": "i", "data": 54}}]})
        with patch.object(movil, "sh", lambda a, timeout=4: salida):
            self.assertEqual(movil.propiedades("/x", "i"), {"charge": 54})


if __name__ == "__main__":
    unittest.main()
