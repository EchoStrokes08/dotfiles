"""Órdenes del centro de control: fallos no son apagados ni éxitos optimistas."""
import json
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import conmutadores as c


def estado(activo=False, disponible=True, error=""):
    return {"activo": activo, "disponible": disponible, "error": error}


class Lectura(unittest.TestCase):
    def test_replay_automatico_en_espera_no_parece_error(self):
        dato = {"grabando": False, "politica": "auto", "texto": "Automático · esperando un juego"}
        with patch.object(c, "ejecutar", return_value=json.dumps(dato)):
            r = c.leer("replay")
        self.assertTrue(r["disponible"])
        self.assertEqual(r["etiqueta"], "Automático")
        self.assertIn("esperando", r["detalle"])

    def test_wifi_apagado_sigue_disponible(self):
        with patch.object(c, "ejecutar", side_effect=["ethernet\nwifi", "disabled"]):
            self.assertEqual(c.leer("wifi"), estado())

    def test_wifi_sin_adaptador_no_se_confunde_con_apagado(self):
        with patch.object(c, "ejecutar", return_value="ethernet"):
            dato = c.leer("wifi")
        self.assertFalse(dato["disponible"])
        self.assertIsNone(dato["activo"])
        self.assertIn("adaptador", dato["error"])

    def test_servicio_fallido_tiene_motivo(self):
        with patch.object(c, "ejecutar", side_effect=RuntimeError("Bluetooth no responde")):
            self.assertEqual(c.leer("bluetooth"), estado(None, False, "Bluetooth no responde"))

    def test_luz_no_interpreta_error_hyprctl_como_temperatura(self):
        with patch.object(c, "ejecutar", return_value="error: hyprsunset not running"):
            self.assertFalse(c.leer("luz")["disponible"])

    def test_perfil_no_ofrecido_no_es_un_boton_disponible(self):
        with patch.object(c, "ejecutar", return_value="balanced:\npower-saver:"):
            self.assertFalse(c.leer("rendimiento")["disponible"])

    def test_conservacion_sin_permiso_no_se_anuncia_utilizable(self):
        with tempfile.TemporaryDirectory() as tmp:
            archivo = Path(tmp) / "conservation_mode"
            archivo.write_text("0\n")
            with patch.object(c, "archivo_conservacion", return_value=archivo), patch.object(c.os, "access", return_value=False):
                self.assertIn("permiso", c.leer("conservacion")["error"])

    def test_dependencia_ausente_y_timeout_son_errores_legibles(self):
        for error in (FileNotFoundError(), subprocess.TimeoutExpired("nmcli", 4)):
            with self.subTest(error=error), patch.object(c.subprocess, "run", side_effect=error):
                with self.assertRaises(RuntimeError):
                    c.ejecutar("nmcli")


class Ordenes(unittest.TestCase):
    def test_orden_fallida_conserva_estado_real(self):
        with patch.object(c, "leer", return_value=estado()), patch.object(c, "ejecutar", side_effect=RuntimeError("Sin permiso")):
            r = c.cambiar("wifi", True)
        self.assertFalse(r["ok"])
        self.assertFalse(r["estado"]["activo"])
        self.assertEqual(r["error"], "Sin permiso")

    def test_codigo_cero_sin_confirmacion_no_es_exito(self):
        with patch.object(c, "leer", return_value=estado()), patch.object(c, "ejecutar"), patch.object(c.time, "sleep"):
            r = c.cambiar("wifi", True)
        self.assertFalse(r["ok"])
        self.assertIn("no confirmó", r["error"])

    def test_confirmacion_tardia_se_acepta(self):
        with patch.object(c, "leer", side_effect=[estado(), estado(), estado(True)]), patch.object(c, "ejecutar"), patch.object(c.time, "sleep"):
            r = c.cambiar("bluetooth", True)
        self.assertTrue(r["ok"])
        self.assertTrue(r["estado"]["activo"])

    def test_orden_idempotente_no_alterna_un_control_ya_encendido(self):
        with patch.object(c, "leer", return_value=estado(True)), patch.object(c, "ejecutar") as ejecutar:
            self.assertTrue(c.cambiar("replay", True)["ok"])
        ejecutar.assert_not_called()

    def test_no_disponible_no_intenta_mutar_hardware(self):
        with patch.object(c, "leer", return_value=estado(None, False, "Sin hardware")), patch.object(c, "ejecutar") as ejecutar:
            self.assertFalse(c.cambiar("wifi", True)["ok"])
        ejecutar.assert_not_called()

    def test_cli_fallido_devuelve_json_y_codigo_no_cero(self):
        out = io.StringIO()
        with patch.object(c, "cambiar", return_value={"ok": False, "error": "falló", "estado": estado()}), redirect_stdout(out):
            self.assertEqual(c.main(["wifi", "on"]), 1)
        self.assertFalse(json.loads(out.getvalue())["ok"])


if __name__ == "__main__":
    unittest.main()
