"""Almacenamiento: limpiar solo lo que se regenera, nunca lo que usan el agente o el dictado."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "hypr/.config/hypr/scripts"))
import almacenamiento as al  # noqa: E402


class Almacenamiento(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        self.p = [patch.object(al, "HOME", self.home), patch.object(al, "CACHE", self.home / ".cache"),
                  patch.object(al, "PAPELERA", self.home / ".local/share/Trash")]
        for x in self.p:
            x.start()

    def tearDown(self):
        for x in reversed(self.p):
            x.stop()
        self.tmp.cleanup()

    def archivo(self, ruta, bytes_=10):
        f = self.home / ruta
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_bytes(b"x" * bytes_)
        return f

    def test_limpiar_cache_no_toca_agente_dictado_ni_memoria(self):
        for seguro in ("pip/a", "yay/b", "go-build/c", "thumbnails/d"):
            self.archivo(".cache/" + seguro)
        intocables = [self.archivo(".cache/" + x) for x in ("ms-playwright/chrome", "whisper/modelo.pt", "brujula/memoria.db", "cliphist/db")]
        r = al.limpiar("cache")
        self.assertTrue(r["ok"])
        self.assertTrue(all(f.exists() for f in intocables))
        self.assertFalse((self.home / ".cache/pip").exists())

    def test_firefox_abierto_no_se_limpia(self):
        self.archivo(".cache/mozilla/firefox/cache2/x")
        with patch.object(al, "corriendo", return_value=True):
            with self.assertRaises(OSError):
                al.limpiar("firefox")
        self.assertTrue((self.home / ".cache/mozilla/firefox/cache2/x").exists())

    def test_grandes_solo_en_carpetas_visibles(self):
        with patch.object(al, "MINIMO_GRANDE", 1000):
            self.archivo("Downloads/instalador.iso", 5000)
            self.archivo(".local/share/app/version.bin", 9000)
            self.archivo(".cache/grande.bin", 9000)
            self.archivo("Downloads/pequeno.txt", 10)
            self.assertEqual([Path(x["ruta"]).name for x in al.grandes()], ["instalador.iso"])

    def test_a_papelera_solo_dentro_de_home(self):
        with self.assertRaises(ValueError):
            al.a_papelera("/etc/hostname")
        with patch.object(al.subprocess, "run") as run:
            run.return_value.returncode = 0
            f = self.archivo("Downloads/viejo.zip")
            self.assertTrue(al.a_papelera(str(f))["ok"])
            self.assertEqual(run.call_args.args[0][:2], ["gio", "trash"])

    def test_estado_suma_y_ordena(self):
        self.archivo("Downloads/a", 3000)
        with patch.object(al, "snapshots", return_value=3), patch.object(al, "corriendo", return_value=False):
            d = al.estado()
        self.assertEqual(d["categorias"][-1]["id"], "otros")
        self.assertTrue(any(c["id"] == "descargas" and c["bytes"] >= 3000 for c in d["categorias"]))
        orden_terminal = [c["accion"]["orden"] for c in d["categorias"] if c.get("accion", {}).get("tipo") == "terminal"]
        self.assertTrue(all(o.startswith("sudo ") for o in orden_terminal))   # lo de administrador va a la terminal


if __name__ == "__main__":
    unittest.main()
