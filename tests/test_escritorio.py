import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'hypr/.config/hypr/scripts'
sys.path.insert(0, str(SCRIPTS))
import escritorio
import replay


def ventana(address='0xabc', pid=10, clase='kitty', workspace=1):
    return dict(address=address, pid=pid, **{'class': clase}, workspace=workspace)


def captura(ventanas, instancia='prueba'):
    return dict(version=1, instancia=instancia, ventanas=ventanas)


class Checkpoints(unittest.TestCase):
    def test_restaura_solo_identidad_original_y_cambios(self):
        original = captura([ventana(), ventana('0xdef', pid=11)])
        actual = captura([ventana(workspace=3), ventana('0xdef', pid=99)])
        plan, omitidas = escritorio.plan_restauracion(original, actual, 'prueba')
        self.assertEqual(plan, [ventana()])
        self.assertEqual(omitidas, 1)

    def test_rechaza_otra_sesion(self):
        with self.assertRaises(ValueError):
            escritorio.plan_restauracion(captura([]), captura([]), 'otra')

    def test_no_mueve_ventanas_que_no_cambiaron(self):
        dato = captura([ventana()])
        self.assertEqual(escritorio.plan_restauracion(dato, dato, 'prueba'), ([], 0))

    def test_rechaza_workspace_con_codigo_y_booleanos(self):
        for ws in ['1});os.execute("false")', True, -1]:
            with self.subTest(ws=ws), self.assertRaises(ValueError):
                escritorio.plan_restauracion(captura([ventana(workspace=ws)]), captura([ventana()]), 'prueba')

    def test_rechaza_direccion_con_codigo(self):
        mal = ventana(address='0xabc");os.execute("false")')
        with self.assertRaises(ValueError):
            escritorio.plan_restauracion(captura([mal]), captura([mal]), 'prueba')

    def test_diagnostico_continua_si_falla_dependencia(self):
        with patch.object(escritorio, 'estado', return_value={}), patch.object(escritorio, 'ejecutar', side_effect=FileNotFoundError):
            salida = escritorio.diagnostico()
        self.assertIn('no disponible', salida)

    def test_replay_no_adopta_otro_proceso_del_usuario(self):
        proceso = subprocess.Popen(['sleep', '10'])
        try:
            self.assertIsNone(replay.identidad(proceso.pid))
        finally:
            proceso.terminate()
            proceso.wait()

class Bloqueo(unittest.TestCase):
    def ejecutar_bloqueo(self, estado):
        import os
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            raiz = Path(tmp)
            programas = {
                'pidof': '#!/bin/sh\nexit 1\n',
                'qs': '#!/bin/sh\n[ "$4" = "estado" ] && echo ' + estado + '\nexit 0\n',
                'hyprlock': '#!/bin/sh\ntouch "$XDG_RUNTIME_DIR/respaldo"\n',
                'notify-send': '#!/bin/sh\nexit 0\n',
                'logger': '#!/bin/sh\nexit 0\n',
            }
            for nombre, texto in programas.items():
                ruta = raiz / nombre
                ruta.write_text(texto)
                ruta.chmod(0o755)
            env = dict(os.environ, PATH=tmp + ':' + os.defpath, XDG_RUNTIME_DIR=tmp)
            r = subprocess.run(['bash', str(SCRIPTS / 'bloquear.sh')], env=env, capture_output=True, timeout=12)
            return r.returncode, (raiz / 'respaldo').exists()

    def test_confirmacion_segura_no_lanza_otro_bloqueador(self):
        self.assertEqual(self.ejecutar_bloqueo('bloqueado'), (0, False))

    def test_bloqueo_pendiente_no_se_considera_exitoso(self):
        self.assertEqual(self.ejecutar_bloqueo('bloqueando'), (1, False))

    def test_sin_bloqueo_usa_hyprlock(self):
        self.assertEqual(self.ejecutar_bloqueo('libre'), (0, True))


class Operaciones(unittest.TestCase):
    def test_checkpoint_registra_deshacer_antes_de_mover(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(escritorio, 'directorio', return_value=(Path(tmp), 'prueba')):
                with patch.object(escritorio, 'captura', return_value=captura([ventana()])):
                    escritorio.checkpoint('guardar')
                actual = captura([ventana(workspace=5)])
                with patch.object(escritorio, 'captura', return_value=actual), patch.object(escritorio, 'ejecutar') as run:
                    escritorio.checkpoint('restaurar')
                    self.assertIn('workspace=1', run.call_args.args[0][2])
                with patch.object(escritorio, 'captura', return_value=captura([ventana()])), patch.object(escritorio, 'ejecutar') as run:
                    escritorio.checkpoint('deshacer')
                    self.assertIn('workspace=5', run.call_args.args[0][2])

    def test_privacidad_impide_encendido_manual_de_replay(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(replay, 'directorio', return_value=(Path(tmp), 'prueba')), patch.object(replay, 'estado', return_value={'privacidad':'true'}), patch.object(replay, 'buscar', return_value=None), patch.object(replay, 'iniciar') as iniciar, patch.object(sys, 'argv', ['replay.py','start']):
                replay.main()
                iniciar.assert_not_called()

    def test_auto_pausa_replay_por_bateria(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(replay, 'directorio', return_value=(Path(tmp), 'prueba')), patch.object(replay, 'estado', return_value={'pausar_replay':'true'}), patch.object(replay, 'buscar', return_value=None), patch.object(replay, 'iniciar') as iniciar, patch.object(sys, 'argv', ['replay.py','auto']):
                replay.main()
                iniciar.assert_not_called()


if __name__ == '__main__':
    unittest.main()
