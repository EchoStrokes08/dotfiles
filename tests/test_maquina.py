"""Máquina del tiempo (scripts/maquina.py): momentos a partir de la línea de tiempo de Brújula."""
import datetime as dt
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import brujula as b  # noqa: E402
import maquina  # noqa: E402


class Maquina(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.dia = dt.date(2026, 1, 15)
        self.archivos = []
        for p in (patch.object(b, "LINEA", self.root / "linea"), patch.object(b, "capturas_del_dia", lambda d: []),
                  patch.object(b, "archivos_del_dia", lambda d: self.archivos),
                  patch.object(b, "nombre_de", lambda c: c.title()), patch.object(b, "app_de", lambda c: None)):
            p.start()
            self.addCleanup(p.stop)
        (self.root / "linea").mkdir()

    def t(self, h, m=0):
        return int(dt.datetime.combine(self.dia, dt.time(h, m)).timestamp())

    def linea(self, regs):
        (self.root / "linea" / f"{self.dia}.jsonl").write_text("\n".join(json.dumps(r) for r in regs))

    def test_un_vistazo_a_otra_app_no_corta_el_momento(self):
        self.linea([{"t": self.t(9), "c": "code", "ti": "a.py"}, {"t": self.t(9, 30), "c": "zapzap", "ti": "chat"},
                    {"t": self.t(9, 31), "c": "code", "ti": "b.py"}, {"t": self.t(10), "e": "pausa"}])
        ms = maquina.datos(self.dia)["momentos"]
        self.assertEqual(len(ms), 1)
        self.assertEqual((ms[0]["clase"], ms[0]["inicio"], ms[0]["fin"]), ("code", self.t(9), self.t(10)))
        self.assertEqual(ms[0]["titulos"], ["a.py", "b.py"])

    def test_orden_archivos_y_privacidad(self):
        self.archivos = [{"t": self.t(11, 10), "ruta": "/x/informe.pdf", "nombre": "informe.pdf", "existe": True},
                         {"t": self.t(11, 20), "ruta": "/x/borrado.txt", "nombre": "borrado.txt", "existe": False}]
        self.linea([{"t": self.t(8), "c": "kitty", "ti": "zsh"}, {"t": self.t(8, 30), "e": "pausa"},
                    {"t": self.t(11), "c": "opera", "ti": "secreto", "p": 1}, {"t": self.t(11, 30), "e": "pausa"}])
        ms = maquina.datos(self.dia)["momentos"]
        self.assertEqual([m["clase"] for m in ms], ["opera", "kitty"])      # del más reciente al más antiguo
        self.assertEqual(ms[0]["titulos"], [])                               # ventana privada: sin títulos
        self.assertEqual([a["nombre"] for a in ms[0]["archivos"]], ["informe.pdf"])   # solo los que existen
        self.assertEqual(ms[1]["archivos"], [])

    def test_ratos_cortos_no_son_momentos(self):
        self.linea([{"t": self.t(8), "c": "kitty"}, {"t": self.t(8, 1), "e": "pausa"}])
        self.assertEqual(maquina.datos(self.dia)["momentos"], [])


if __name__ == "__main__":
    unittest.main()
