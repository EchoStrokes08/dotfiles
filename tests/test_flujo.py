import datetime
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'hypr/.config/hypr/scripts'))
import flujo


def win(address='0xabc',pid=20,clase='kitty',ws=3,**extra):
    return dict(address=address,pid=pid,**{'class':clase},workspace={'id':ws},floating=False,fullscreen=0,**extra)


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.root=Path(self.tmp.name)
        self.env=patch.dict(os.environ,{'XDG_STATE_HOME':str(self.root/'state')});self.env.start()
        self.dir=patch.object(flujo,'directorio',return_value=(self.root,'prueba'));self.dir.start()
    def tearDown(self):
        self.dir.stop();self.env.stop();self.tmp.cleanup()


class Proyectos(Base):
    def guardar(self,**kwargs):
        with patch.object(flujo,'clientes',return_value=[win()]),patch.object(flujo,'estado',return_value={'perfil':'lectura'}):
            return flujo.proyectos('guardar',nombre='Proyecto',siguiente='Revisar capítulo',**kwargs)

    def test_persistencia_permisos_y_sin_titulos(self):
        with patch.object(flujo,'clientes',return_value=[dict(win(),title='PRIVADO',initialTitle='PRIVADO')]),patch.object(flujo,'estado',return_value={'perfil':'cristal'}):
            flujo.proyectos('guardar',nombre='Proyecto',siguiente='Revisar capítulo')
        dato=flujo.ruta_local().read_text()
        self.assertNotIn('PRIVADO',dato)
        self.assertNotIn('title',dato)
        self.assertEqual(flujo.ruta_local().stat().st_mode & 0o777,0o600)
        self.assertEqual(flujo.proyectos('lista')['proyectos'][0]['siguiente'],'Revisar capítulo')

    def test_apps_desconocidas_y_especiales_no_se_guardan(self):
        self.assertEqual(flujo.lista_apps([win(clase='desconocido'),win(ws=-9)]),[])

    def test_rechaza_comandos_guardados_como_app(self):
        p={'id':'a'*32,'perfil':'cristal','apps':[{'app':'sh -c false','workspace':3}]}
        with self.assertRaises(ValueError):flujo.plan_proyecto(p,[])

    def test_no_duplica_app_ya_abierta_en_el_espacio(self):
        p={'id':'a'*32,'perfil':'cristal','apps':[{'app':'terminal','workspace':3}]}
        self.assertEqual(flujo.plan_proyecto(p,[win()])['apps'],[])

    def test_ruta_unicode_y_metacaracteres_son_argumentos(self):
        folder=self.root/'á $(false)';folder.mkdir()
        d=self.guardar(carpeta=str(folder))
        with patch.object(flujo,'clientes',return_value=[]),patch.object(flujo.shutil,'which',return_value='/bin/kitty'),patch.object(flujo,'despachar') as dsp:
            flujo.proyectos('retomar',d['seleccion'])
        expr=dsp.call_args.args[0]
        comando=json.JSONDecoder().raw_decode(expr[len('hl.dsp.exec_cmd('):])[0]
        self.assertEqual(shlex.split(comando)[-1],str(folder))
        self.assertIn('á',expr)

    def test_rechaza_recursos_que_no_existen(self):
        with self.assertRaises(ValueError):self.guardar(recursos=str(self.root/'no-existe'))

    def test_eliminar_actualiza_ultimo(self):
        d=self.guardar();flujo.proyectos('eliminar',d['seleccion'])
        self.assertEqual(flujo.proyectos('lista')['ultimo'],'')


class Organizar(Base):
    def mocks(self):
        return patch.object(flujo,'espacio',return_value={'id':3,'tiledLayout':'dwindle'}),patch.object(flujo,'clientes',return_value=[win(),win('0xdef',21,'code-oss')])

    def test_previsualizar_no_modifica_compositor(self):
        a,b=self.mocks()
        with a,b,patch.object(flujo,'ejecutar') as run:
            d=flujo.organizar('prever','programar')
            run.assert_not_called()
            self.assertEqual(d['plan']['principal'],'0xdef')

    def test_ventanas_cambiadas_exigen_nueva_previsualizacion(self):
        a,b=self.mocks()
        with a,b:d=flujo.organizar('prever')
        a,_=self.mocks()
        with a,patch.object(flujo,'clientes',return_value=[win()]),patch.object(flujo,'ejecutar') as run:
            with self.assertRaises(ValueError):flujo.organizar('aplicar',token=d['plan']['token'])
            run.assert_not_called()

    def test_aplicar_requiere_token_y_se_puede_volver(self):
        a,b=self.mocks()
        with a,b:
            d=flujo.organizar('prever')
            with self.assertRaises(ValueError):flujo.organizar('aplicar',token='otro')
            with patch.object(flujo,'ejecutar',return_value='ok') as run:
                flujo.organizar('aplicar',token=d['plan']['token'])
                self.assertIn('layout="master"',run.call_args.args[0][2])
                flujo.organizar('volver')
                self.assertIn('layout="dwindle"',run.call_args.args[0][2])

    def test_programar_no_expulsa_editor_ya_principal(self):
        a,b=self.mocks()
        with a,b:
            d=flujo.organizar('prever','programar')
            with patch.object(flujo,'ejecutar',return_value='ok') as run:
                flujo.organizar('aplicar',token=d['plan']['token'])
                self.assertIn('swapwithmaster master ignoremaster',run.call_args.args[0][2])

    def test_plan_caducado_no_se_aplica(self):
        a,b=self.mocks()
        with a,b:
            d=flujo.organizar('prever')
            with patch.object(flujo.time,'time',return_value=d['plan']['fecha']+121):
                with self.assertRaises(ValueError):flujo.organizar('aplicar',token=d['plan']['token'])


class Seleccion(Base):
    def capturar(self,texto=' texto original\n'):
        with patch.object(flujo.subprocess,'run',return_value=subprocess.CompletedProcess([],0,stdout=texto)):
            return flujo.seleccion('capturar')['seleccion']

    def test_conserva_espacios_y_no_relee_clipboard_al_actuar(self):
        d=self.capturar()
        with patch.object(flujo.subprocess,'run') as run:
            flujo.seleccion('copiar',d['token'])
            self.assertEqual(run.call_args.args[0],['wl-copy','--',' texto original\n'])

    def test_token_viejo_no_actua_sobre_texto_nuevo(self):
        viejo=self.capturar('anterior');self.capturar('nuevo')
        with self.assertRaises(ValueError):flujo.seleccion('copiar',viejo['token'])
        flujo.seleccion('limpiar',viejo['token'])
        self.assertTrue(flujo.ruta_temporal('seleccion').exists())

    def test_expira_y_se_borra(self):
        d=self.capturar()
        with patch.object(flujo.time,'time',return_value=__import__('time').time()+601):
            with self.assertRaises(ValueError):flujo.seleccion('copiar',d['token'])
        self.assertFalse(flujo.ruta_temporal('seleccion').exists())

    def test_codigo_no_es_recurso_ejecutable(self):
        self.assertEqual(flujo.recurso('javascript:alert(1)'),'')
        self.assertEqual(flujo.recurso('$(touch /tmp/no-ejecutar)'),'')
        self.assertEqual(flujo.recurso('https://example.org/pagina'),'https://example.org/pagina')

    def test_ia_usa_captura_local_con_permisos_privados(self):
        d=self.capturar('Contenido exacto')
        with patch.object(flujo,'ejecutar') as run:
            flujo.seleccion('resumir',d['token'])
        self.assertEqual((self.root/'ia-entrada.txt').read_text(),'Contenido exacto')
        self.assertEqual((self.root/'ia-entrada.txt').stat().st_mode & 0o777,0o600)
        self.assertEqual(run.call_args.args[0][:5],['qs','ipc','call','ia','abrir'])


if __name__=='__main__':unittest.main()
