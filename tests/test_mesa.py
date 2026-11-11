import datetime as dt
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'hypr/.config/hypr/scripts'))
import mesa


class Plantillas(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_STATE_HOME': self.tmp.name})
        self.env.start()

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()

    def test_guardar_editar_eliminar_y_persistir(self):
        dato = mesa.plantillas('guardar', titulo='Nueva', texto='Texto')
        ident = dato['seleccion']
        self.assertTrue(ident)
        mesa.plantillas('guardar',ident,titulo='Editada',texto='Otro texto')
        self.assertEqual(mesa.plantillas('lista')['plantillas'][-1]['texto'],'Otro texto')
        mesa.plantillas('eliminar',ident)
        self.assertFalse(any(p['id']==ident for p in mesa.plantillas('lista')['plantillas']))
        self.assertEqual(mesa.ruta_plantillas().stat().st_mode & 0o777, 0o600)

    def test_cli_permite_texto_que_parece_opcion(self):
        import subprocess
        run=subprocess.run([sys.executable,str(Path(mesa.__file__)), 'plantilla','guardar','--titulo=--opción','--texto=--help'],capture_output=True,text=True,check=True)
        dato=json.loads(run.stdout)
        self.assertEqual(dato['plantillas'][-1]['texto'],'--help')

    def test_texto_con_codigo_se_trata_como_datos(self):
        texto = '$(touch /tmp/no-ejecutar); `false`; {{fecha}}'
        dato = mesa.plantillas('guardar',titulo='Literal',texto=texto)
        with patch.object(mesa.subprocess,'run') as ejecutar:
            mesa.plantillas('copiar',dato['seleccion'])
            args=ejecutar.call_args.args[0]
        self.assertEqual(args[:2],['wl-copy','--'])
        self.assertIn('$(touch /tmp/no-ejecutar)',args[2])

    def test_variables_solo_permitidas(self):
        texto = '{{fecha}} {{hora}} {{desconocida}}'
        self.assertEqual(mesa.expandir(texto,dt.datetime(2026,11,11,14,35)), '2026-11-11 14:35 {{desconocida}}')

    def test_rechaza_texto_vacio_y_excesivo(self):
        for texto in ['', 'x'*16001,'abc\0']:
            with self.subTest(texto=texto[:10]),self.assertRaises(ValueError):
                mesa.plantillas('guardar',titulo='Nombre',texto=texto)


class Ventanas(unittest.TestCase):
    def test_rechaza_codigo_en_direccion(self):
        with self.assertRaises(ValueError): mesa.normalizar_direccion('0xabc"});os.execute("false")')

    def test_ventana_cerrada_no_se_mueve(self):
        with patch.object(mesa,'ejecutar',return_value='[]') as ejecutar:
            with self.assertRaises(ValueError): mesa.ventana('mover','abc',3)
            self.assertEqual(ejecutar.call_count,1)

    def test_aparcar_y_recuperar_con_identidad(self):
        w={'address':'0xabc','pid':20,'class':'kitty','workspace':{'id':3,'name':'3'}}
        with tempfile.TemporaryDirectory() as tmp,patch.object(mesa,'directorio',return_value=(Path(tmp),'prueba')):
            with patch.object(mesa,'ejecutar',side_effect=[json.dumps([w]),'ok']) as run:
                mesa.ventana('aparcar','abc')
                self.assertIn('special:aparcadas',run.call_args.args[0][2])
            w['workspace']={'id':-99,'name':'special:aparcadas'}
            with patch.object(mesa,'ejecutar',side_effect=[json.dumps([w]),'ok']) as run:
                mesa.ventana('aparcar','abc')
                self.assertIn('workspace=3',run.call_args.args[0][2])

    def test_datos_manipulados_no_se_ejecutan(self):
        w={'address':'0xabc','pid':20,'class':'kitty','workspace':{'id':-99,'name':'special:aparcadas'}}
        with tempfile.TemporaryDirectory() as tmp,patch.object(mesa,'directorio',return_value=(Path(tmp),'prueba')):
            Path(tmp,'hypr-aparcadas-prueba.json').write_text(json.dumps({'0xabc':{'pid':20,'class':'kitty','workspace':'1});os.execute("false")'}}))
            with patch.object(mesa,'ejecutar',side_effect=[json.dumps([w]),'{"id":2}','ok']) as run:
                mesa.ventana('aparcar','abc')
                self.assertIn('workspace=2',run.call_args.args[0][2])
                self.assertNotIn('os.execute',run.call_args.args[0][2])


class Reunion(unittest.TestCase):
    def test_rechaza_duracion_fuera_de_rango(self):
        for minutos in [0,-1,181]:
            with self.subTest(minutos=minutos),self.assertRaises(ValueError):
                mesa.reunion('iniciar',minutos)

    def test_terminar_limpia_el_motivo_y_estado(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(mesa,'directorio',return_value=(Path(tmp),'prueba')):
            ruta=mesa.ruta_reunion();ruta.write_text('{"fin":100}')
            with patch.object(mesa,'ejecutar') as ejecutar:
                mesa.reunion('terminar')
            self.assertFalse(ruta.exists())
            self.assertIn('reunion",false',ejecutar.call_args.args[0][2])


class Supervisor(unittest.TestCase):
    def test_salida_siempre_restaura_y_cierra_solo_su_inhibidor(self):
        from unittest.mock import MagicMock
        with tempfile.TemporaryDirectory() as tmp, patch.object(mesa,'directorio',return_value=(Path(tmp),'prueba')):
            proceso=MagicMock(pid=123456)
            proceso.poll.return_value=None
            evento=MagicMock()
            evento.wait.return_value=True
            with patch.object(mesa.subprocess,'Popen',return_value=proceso), patch.object(mesa.threading,'Event',return_value=evento), patch.object(mesa.signal,'signal'), patch.object(mesa.time,'sleep'), patch.object(mesa.os,'killpg') as kill, patch.object(mesa,'ejecutar') as ejecutar:
                mesa.trabajador_reunion(1)
                self.assertIn('reunion",true',ejecutar.call_args_list[0].args[0][2])
                self.assertIn('reunion",false',ejecutar.call_args_list[-1].args[0][2])
                kill.assert_called_once_with(123456,mesa.signal.SIGTERM)
            self.assertFalse(mesa.ruta_reunion().exists())

    def test_rutina_guarda_antes_de_cambiar_y_no_cierra_apps(self):
        from unittest.mock import MagicMock
        orden=MagicMock()
        with patch.object(mesa,'checkpoint') as cp,patch.object(mesa,'ejecutar') as run:
            orden.attach_mock(cp,'checkpoint');orden.attach_mock(run,'ejecutar')
            mesa.rutina('programar')
            self.assertEqual(orden.mock_calls[0].args,('guardar',))
            self.assertEqual(run.call_count,3)
            self.assertNotIn('close',str(run.call_args_list))


if __name__=='__main__': unittest.main()
