"""Salud, actualizaciones seguras, reabrir ventana y fin de jornada (sin tocar el sistema real)."""
import datetime as dt
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import actualizar  # noqa: E402
import brujula as b  # noqa: E402
import salud  # noqa: E402


class Salud(unittest.TestCase):
    def test_orden_y_fallo_aislado(self):
        def roto():
            raise RuntimeError("x")
        fijas = [lambda: salud.c("a", "A", "ok", "", ""), lambda: salud.c("b", "B", "mal", "", ""), roto,
                 lambda: salud.c("d", "D", "aviso", "", "")]
        with patch.object(salud, "COMPROBACIONES", fijas):
            d = salud.todo()
        self.assertEqual([x["estado"] for x in d["comprobaciones"]], ["mal", "aviso", "info", "ok"])
        self.assertEqual(d["estado"], "mal")
        self.assertEqual(salud.resumen(d), "2 cosas que revisar: b, d")

    def test_umbrales(self):
        with patch.object(salud.shutil, "disk_usage", lambda p: (100 * 2**30, 96 * 2**30, 4 * 2**30)):
            self.assertEqual(salud.espacio()["estado"], "mal")
        with patch.object(salud, "sh", lambda a, timeout=6: "\n".join(["usb 1-1: device descriptor read/64, error -71"] * 3)):
            self.assertEqual(salud.usb()["valor"], "3 errores")
        self.assertEqual(salud.hace(86400 + 5), "hace 1 día")


class Actualizar(unittest.TestCase):
    def test_pares_de_snap_pac(self):
        csv = "number,type,pre-number,date,description\n70,single,,2026-11-11 17:00:25,timeline\n" \
              "80,pre,,2026-11-12 09:00:00,pacman -Syu\n81,post,80,2026-11-12 09:03:00,linux systemd\n" \
              "82,pre,,2026-11-12 09:03:10,pacman -U\n83,post,82,2026-11-12 09:03:20,paquete-aur\n"
        with patch.object(actualizar, "sh", lambda a, timeout=30: csv):
            self.assertEqual([(p[0], p[1]) for p in actualizar.snapshots_pacman()], [(80, 81), (82, 83)])

    def test_deshacer_pide_confirmacion(self):
        with tempfile.TemporaryDirectory() as t:
            reg = Path(t) / "a.jsonl"
            reg.write_text(json.dumps({"fecha": int(time.time()), "pre": 80, "post": 83}) + "\n")
            llamadas = []
            with patch.object(actualizar, "REGISTRO", reg), patch.object(actualizar, "sh", lambda a, timeout=30: ""), \
                    patch("builtins.input", lambda *_: "si"), patch.object(actualizar.subprocess, "run", lambda *a, **k: llamadas.append(a)):
                self.assertEqual(actualizar.deshacer(), 1)   # «si» no basta: hay que escribir DESHACER
            self.assertEqual(llamadas, [])


class ReabrirYJornada(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.p = [patch.object(b, "ESTADO", Path(self.tmp.name)), patch.object(b, "osd", lambda *a: None)]
        for x in self.p:
            x.start()

    def tearDown(self):
        for x in reversed(self.p):
            x.stop()
        self.tmp.cleanup()

    def test_reabre_la_ultima_valida(self):
        b.atomico(b.ESTADO / "cerradas.json", [
            {"clase": "kitty", "nombre": "kitty", "ws": 2, "argv": ["kitty"], "flotante": False},
            {"clase": "rara", "nombre": "x", "ws": 99, "argv": ["sh"]}])
        enviados = []
        with patch.object(b, "despachar", enviados.append), patch.object(b.shutil, "which", lambda x: "/usr/bin/" + x):
            r = b.reabrir()
        self.assertIn("espacio 2", r["mensaje"])
        self.assertEqual(enviados, ['hl.dsp.exec_cmd("kitty", {workspace="2"})'])
        self.assertEqual(b.leer_json(b.ESTADO / "cerradas.json", None), [])

    def test_jornada_avisa_una_vez_y_respeta_posponer(self):
        hilos = []
        cfg = {"activa": True, "hora": "00:00", "dias": []}
        with patch.object(b, "jornada_cfg", lambda: cfg), patch.object(b.threading, "Thread", lambda target, daemon: hilos.append(target) or type("T", (), {"start": lambda s: None})()):
            b.revisar_jornada(False, False)
            b.revisar_jornada(False, False)
            self.assertEqual(len(hilos), 1)
            e = b.jornada_estado()
            e["posponer"] = int(time.time()) - 1   # pasaron los 15 min
            b.atomico(b.ESTADO / "jornada.json", e)
            b.revisar_jornada(False, False)
            self.assertEqual(len(hilos), 2)
            b.revisar_jornada(False, True)          # con un juego abierto no molesta
            self.assertEqual(len(hilos), 2)

    def test_por_la_manana_vuelve_todo(self):
        ayer = (dt.date.today() - dt.timedelta(days=1)).isoformat()
        b.atomico(b.ESTADO / "jornada.json", {"cerrada": True, "dia": ayer, "brillo_previo": 60})
        ordenes = []
        with patch.object(b, "lanzar", ordenes.append), patch.object(b, "ejecutar", lambda a, t=4: ordenes.append(a) or ""), \
                patch.object(b, "jornada_cfg", lambda: {"activa": True, "hora": "23:00"}):
            if dt.datetime.now().hour >= 5:
                b.revisar_jornada(False, False)
                self.assertIn(["brightnessctl", "-q", "set", "60%"], ordenes)
                self.assertIn(["qs", "ipc", "call", "notificaciones", "motivo", "jornada", "false"], ordenes)
                self.assertFalse(b.jornada_estado()["cerrada"])


if __name__ == "__main__":
    unittest.main()
