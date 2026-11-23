"""Vínculos de Pizarra con Hyprland, sin cambiar el foco de la sesión real."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

RUTA = Path(__file__).resolve().parents[1] / "hypr/.config/hypr/pizarra/ventanas.py"
SPEC = importlib.util.spec_from_file_location("pizarra_ventanas", RUTA)
ventanas = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ventanas)


class VentanasDePizarra(unittest.TestCase):
    def setUp(self):
        self.mocks = contextlib.ExitStack()
        self.addCleanup(self.mocks.close)
        self.mocks.enter_context(patch.dict(ventanas.os.environ, HYPRLAND_INSTANCE_SIGNATURE="sesion-a"))
        self.w = dict(address="0xab12", pid=101, title="Proyecto", mapped=True)
        self.w["class"] = "editor"
        self.mocks.enter_context(patch.object(ventanas, "hypr", return_value=[self.w]))
        self.enfocar = self.mocks.enter_context(patch.object(ventanas.mesa, "ventana"))
        self.lanzar = self.mocks.enter_context(patch.object(ventanas.subprocess, "Popen"))
        self.mocks.enter_context(patch.object(ventanas.brujula, "app_de", return_value={"id": "editor"}))

    def accion(self, nombre, ref):
        with patch.object(ventanas.sys, "argv", ["ventanas.py", nombre]), \
                patch.object(ventanas.sys, "stdin", io.StringIO(json.dumps(ref))):
            return ventanas.main()

    def test_enfoca_la_misma_ventana_aunque_cambie_el_titulo(self):
        ref = ventanas.identidad(self.w)
        ref["title"] = "Título anterior"
        self.assertEqual(self.accion("activar", ref), "enfocada")
        self.enfocar.assert_called_once_with("enfocar", self.w["address"])
        self.lanzar.assert_not_called()

    def test_direccion_reutilizada_y_sesion_anterior_requieren_decision(self):
        ref = ventanas.identidad(self.w)
        for cambio in ({"pid": 202}, {"sesion": "otra"}, {"class": "otra"}):
            with self.subTest(cambio=cambio):
                self.assertEqual(self.accion("activar", ref | cambio), "ofrecer")
                self.assertEqual(self.accion("volver", ref | cambio), "cerrada")
        self.enfocar.assert_not_called()
        self.lanzar.assert_not_called()
        self.assertEqual(self.accion("abrir", ref | {"sesion": "otra"}), "abierta")
        self.assertEqual(self.lanzar.call_args.args[0], ["gtk-launch", "editor"])

    def test_reutiliza_la_pizarra_que_ya_tiene_el_proyecto(self):
        self.w["class"] = "orion-pizarra"
        self.assertTrue(self.accion("traer", {"pid": 101}))
        self.assertFalse(self.accion("traer", {"pid": 999}))
        self.enfocar.assert_called_once_with("enfocar", "0xab12")
