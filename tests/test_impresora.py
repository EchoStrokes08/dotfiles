"""Impresora (impresora.py): leer la cola y el estado de CUPS y las órdenes, sin impresora real."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import impresora  # noqa: E402

LPQ = """Epson is ready and printing
Rank    Owner   Job     File(s)                         Total Size
active  oscar   7       Tarea de cálculo.pdf            123456 bytes
1st     oscar   8       foto                            2048 bytes
"""


class Lectura(unittest.TestCase):
    def test_cola(self):
        t = impresora.leer_cola(LPQ)
        self.assertEqual([x["id"] for x in t], [7, 8])
        self.assertEqual(t[0]["archivo"], "Tarea de cálculo.pdf")
        self.assertEqual(t[0]["rango"], "active")
        self.assertEqual(t[1]["tamano"], 2048)

    def test_cola_vacia(self):
        self.assertEqual(impresora.leer_cola("Epson is ready\nno entries\n"), [])

    def test_estado(self):
        self.assertEqual(impresora.leer_estado("printer Epson is idle.  enabled since Sat\n"), ("idle", True, ""))
        est, hab, msg = impresora.leer_estado(
            "printer Epson disabled since Sat -\n\tThe printer is not responding.\n")
        self.assertFalse(hab)
        self.assertEqual(msg, "The printer is not responding.")

    def test_host(self):
        self.assertEqual(impresora.host("ipp://192.168.0.13/ipp/print"), "192.168.0.13")
        self.assertEqual(impresora.host("ipp://epson.local:631/ipp/print"), "epson.local")
        self.assertEqual(impresora.host(""), "")


class Ordenes(unittest.TestCase):
    def setUp(self):
        self.llamadas = []
        self.p = patch.object(impresora, "correr", lambda *c, **k: (self.llamadas.append(c), (0, "", ""))[1])
        self.p.start()

    def tearDown(self):
        self.p.stop()

    def test_cancelar(self):
        impresora.main(["cancelar", "7"])
        impresora.main(["cancelar", "todos"])
        self.assertEqual(self.llamadas, [("cancel", "Epson-7"), ("cancel", "-a", "Epson")])

    def test_imprimir_ignora_lo_que_no_es_archivo(self):
        self.assertEqual(impresora.main(["imprimir", "/no/existe"]), 1)
        self.assertEqual(self.llamadas, [])
        impresora.main(["imprimir", __file__])
        self.assertEqual(self.llamadas, [("lp", "-d", "Epson", __file__)])

    def test_reparar_no_toca_si_responde(self):
        with patch.object(impresora, "responde", lambda h: True), \
             patch.object(impresora, "buscar_ip", side_effect=AssertionError):
            self.assertEqual(impresora.main(["reparar"]), 0)


if __name__ == "__main__":
    unittest.main()
