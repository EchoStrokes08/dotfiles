"""Tu día (scripts/tudia.py): horas, trasnoche, racha y música, con datos en carpetas temporales."""
import datetime as dt
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import brujula as b  # noqa: E402
import tudia  # noqa: E402


def t(dia, h, m=0):
    return int(dt.datetime.combine(dia, dt.time(h, m)).timestamp())


class TuDia(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.dia = dt.date(2026, 1, 15)
        for p in (patch.object(b, "LINEA", self.root / "linea"), patch.object(tudia, "MUSICA", self.root / "musica"),
                  patch.object(tudia, "CAPTURAS", self.root / "capturas"), patch.object(b, "archivos_del_dia", lambda d: []),
                  patch.object(b, "nombre_de", lambda c: c.title()), patch.object(b, "app_de", lambda c: None)):
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)
        (self.root / "linea").mkdir()
        regs = [{"t": t(self.dia, 1), "c": "kitty"}, {"t": t(self.dia, 1, 30), "e": "pausa"},
                {"t": t(self.dia, 8), "c": "code"}, {"t": t(self.dia, 10, 30), "c": "kitty"},
                {"t": t(self.dia, 11), "e": "pausa"}]
        (self.root / "linea" / f"{self.dia}.jsonl").write_text("\n".join(json.dumps(r) for r in regs))

    def test_horas_racha_y_trasnoche(self):
        d = tudia.datos(self.dia)
        self.assertEqual(d["total"], int(3.5 * 3600))
        self.assertEqual(d["horas"][8], 3600)
        self.assertEqual((d["horas"][10], d["horas"][11]), (3600, 0))   # media hora de code + media de kitty
        self.assertEqual(d["horaPico"], 8)            # 8 y 9 empatan a 1 h; gana la primera
        self.assertEqual(d["madrugada"], 1800)
        self.assertEqual(d["inicio"], t(self.dia, 8))   # lo de la 1:00 es trasnoche, no el inicio del día
        self.assertEqual(d["racha"]["clase"], "code")
        self.assertEqual(d["racha"]["segundos"], 2.5 * 3600)
        self.assertEqual(d["apps"][0]["clase"], "code")
        self.assertIsNone(d["musica"])

    def test_musica_suma_por_cancion(self):
        (self.root / "musica").mkdir()
        lineas = [{"t": 1, "s": 30, "ti": "A", "ar": "X", "art": "file:///a.png"}] * 3 + [{"t": 1, "s": 30, "ti": "B", "ar": "Y"}]
        (self.root / "musica" / f"{self.dia}.jsonl").write_text("\n".join(json.dumps(x) for x in lineas) + "\nbasura\n")
        m = tudia.datos(self.dia)["musica"]
        self.assertEqual(m["cancion"]["titulo"], "A")
        self.assertEqual(m["cancion"]["segundos"], 90)
        self.assertEqual(m["cancion"]["caratula"], "file:///a.png")
        self.assertEqual((m["canciones"], m["segundos"], m["artista"]), (2, 120, "X"))


if __name__ == "__main__":
    unittest.main()
