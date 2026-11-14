"""Acciones y recuperación con datos temporales, sin modificar la sesión real."""
import datetime as dt
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'hypr/.config/hypr/scripts'))
import acciones as a
import mesa
import flujo


class Acciones(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=Path(self.tmp.name)
        for parche in [patch.dict(os.environ,{'XDG_STATE_HOME':str(self.home/'state')}),patch.object(a,'HOME',self.home),patch.object(a,'ESTADO',self.home/'recuperar')]:
            parche.start();self.addCleanup(parche.stop)

    def test_borrar_y_recuperar_plantilla_conserva_id_y_texto(self):
        original=mesa.plantillas('lista')['plantillas'][0]
        r=a.ejecutar_accion({'tipo':'plantilla','id':original['id']},'eliminar')
        self.assertFalse(any(x['id']==original['id'] for x in mesa.plantillas('lista')['plantillas']))
        a.deshacer(r['deshacer'])
        self.assertIn(original,mesa.plantillas('lista')['plantillas'])
        with self.assertRaises(ValueError):a.deshacer(r['deshacer'])

    def test_undo_no_sobrescribe_un_elemento_recreado(self):
        original=mesa.plantillas('lista')['plantillas'][0]
        r=a.ejecutar_accion({'tipo':'plantilla','id':original['id']},'eliminar')
        p=mesa.ruta_plantillas();datos=json.loads(p.read_text());datos.append(original);p.write_text(json.dumps(datos))
        with self.assertRaisesRegex(ValueError,'No se sobrescribió'):a.deshacer(r['deshacer'])

    def test_edicion_usa_revision_y_no_pisa_un_cambio_reciente(self):
        original=mesa.plantillas('lista')['plantillas'][0];ref={'tipo':'plantilla','id':original['id']}
        ref['revision']=a.opciones(ref)['revision']
        mesa.plantillas('guardar',original['id'],'Actualizada','Texto nuevo')
        with self.assertRaisesRegex(ValueError,'cambió'):a.ejecutar_accion(ref,'guardar',{'titulo':'Anterior','texto':'Viejo'})
        self.assertEqual(mesa.plantillas('lista')['plantillas'][0]['texto'],'Texto nuevo')

    def test_archivar_y_recuperar_proyecto(self):
        p={'id':'a'*32,'nombre':'ORION','siguiente':'Revisar','apps':[],'recursos':[],'carpeta':''}
        ruta=flujo.ruta_local();ruta.write_text(json.dumps({'version':1,'proyectos':[p],'ultimo':p['id']}))
        r=a.ejecutar_accion({'tipo':'proyecto','id':p['id']},'archivar')
        self.assertEqual(flujo.cargar_proyectos()['proyectos'],[])
        a.deshacer(r['deshacer'])
        self.assertEqual(flujo.cargar_proyectos()['proyectos'],[p])

    def test_editar_siguiente_no_recaptura_ventanas(self):
        p={'id':'b'*32,'nombre':'Proyecto','siguiente':'Antes','apps':[{'clase':'kitty'}],'recursos':['/recurso'],'carpeta':''}
        ruta=flujo.ruta_local();ruta.write_text(json.dumps({'version':1,'proyectos':[p],'ultimo':p['id']}))
        a.ejecutar_accion({'tipo':'proyecto','id':p['id']},'editar',{'nombre':'Nuevo','siguiente':'Después'})
        nuevo=flujo.cargar_proyectos()['proyectos'][0]
        self.assertEqual(nuevo['apps'],p['apps']);self.assertEqual(nuevo['recursos'],p['recursos'])
        self.assertEqual(nuevo['siguiente'],'Después')

    def test_ocultar_de_orion_no_modifica_firefox(self):
        url='https://example.com/pagina?clave=1'
        r=a.ejecutar_accion({'tipo':'web','id':url},'ocultar')
        self.assertIn(url,a.ocultos());a.deshacer(r['deshacer']);self.assertNotIn(url,a.ocultos())

    def test_titulos_humanos_no_cambian_url(self):
        url='https://example.com/mi%20documento?token=abc#seccion'
        titulo=a.titulo_web(url)
        self.assertIn('mi documento',titulo);self.assertIn('example.com',titulo);self.assertNotIn('token',titulo)
        self.assertEqual(a.titulo_web(url,'Título real'),'Título real')

    def test_copiar_enlace_conserva_url_completa(self):
        url='https://example.com/a?q=1#b'
        with patch.object(a.subprocess,'run') as copiar:
            a.ejecutar_accion({'tipo':'web','id':url},'copiar')
        self.assertEqual(copiar.call_args.args[0],['wl-copy','--',url])

    def test_rechaza_referencia_y_accion_inyectadas(self):
        with self.assertRaises(ValueError):a.elemento({'tipo':'ventana','id':'0x1;codigo()'})
        with self.assertRaises(ValueError):a.ejecutar_accion({'tipo':'web','id':'https://example.com'},'rm -rf')
        with self.assertRaises(ValueError):a.elemento({'tipo':'web','id':'file:///etc/passwd'})

    def test_identidad_de_ventana_no_se_reutiliza_por_pid(self):
        with patch.object(a,'ejecutar',return_value=json.dumps([{'address':'0x1','pid':2}])):
            with self.assertRaisesRegex(ValueError,'ventana'):a.ventana({'tipo':'ventana','id':'0x1','pid':1})

    def test_recordatorio_descartar_es_explicito_y_recuperable(self):
        ruta=self.home/'.local/state/quickshell/recordatorios.json';ruta.parent.mkdir(parents=True)
        original={'id':'1','texto':'Tarea','cuando':int((time.time()+3600)*1000)};ruta.write_text(json.dumps([original]))
        r=a.ejecutar_accion({'tipo':'recordatorio','id':'1'},'descartar')
        self.assertEqual(json.loads(ruta.read_text()),[]);a.deshacer(r['deshacer'])
        self.assertEqual(json.loads(ruta.read_text()),[original])

    def test_posponer_rechaza_hora_pasada(self):
        ruta=self.home/'.local/state/quickshell/recordatorios.json';ruta.parent.mkdir(parents=True)
        ruta.write_text(json.dumps([{'id':'1','texto':'Tarea','cuando':int((time.time()+3600)*1000)}]))
        with self.assertRaises(ValueError):a.ejecutar_accion({'tipo':'recordatorio','id':'1'},'posponer',{'fecha':'2000-01-01 12:00'})

    def test_acciones_archivo_y_vista_previa(self):
        archivo=self.home/'apuntes.md';archivo.write_text('Contenido de prueba')
        r=a.opciones({'tipo':'archivo','id':str(archivo)})
        self.assertIn('Contenido',r['vista']);self.assertIn('abrir_con',{x['codigo'] for x in r['acciones']})

    def test_tarea_edita_solo_titulo_y_preserva_fecha(self):
        with patch.object(a.gcal,'tareas',return_value=[{'id':'t1','titulo':'Antes','fecha':'2030-01-01'}]),patch.object(a.gcal,'api') as api:
            a.ejecutar_accion({'tipo':'tarea','id':'t1'},'editar',{'titulo':'Después'})
        self.assertEqual(api.call_args.args[0],'PATCH');self.assertEqual(api.call_args.args[2],{'title':'Después'})

    def test_tarea_fallida_no_anuncia_confirmacion(self):
        with patch.object(a.gcal,'tareas',return_value=[{'id':'t1','titulo':'Antes'}]),patch.object(a.gcal,'hecha',side_effect=a.gcal.Error('Sin conexión')):
            with self.assertRaises(a.gcal.Error):a.ejecutar_accion({'tipo':'tarea','id':'t1'},'completar')

    def test_elegir_aplicacion_solo_si_hay_opciones(self):
        archivo=self.home/'texto.txt';archivo.write_text('Texto')
        with patch.object(a,'aplicaciones_para',return_value=[]):
            acciones=a.opciones({'tipo':'archivo','id':str(archivo)})['acciones']
        self.assertNotIn('abrir_con',{x['codigo'] for x in acciones})


if __name__=='__main__':unittest.main()
