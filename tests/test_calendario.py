"""Calendario: crear eventos/tareas en Google (gcal.py) y mezclarlos con el feed iCal (eventos.py).
Sin red: la API de Google se simula y los archivos van a carpetas temporales."""
import datetime as dt
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import eventos  # noqa: E402
import gcal  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.creados = str(self.root / "creados.json")
        self.parches = [patch.object(gcal, "CREADOS", self.creados),
                        patch.object(gcal, "TOKEN", str(self.root / "token.json")),
                        patch.object(gcal, "CLIENTE", str(self.root / "cliente.json"))]
        for p in self.parches:
            p.start()

    def tearDown(self):
        for p in reversed(self.parches):
            p.stop()
        self.tmp.cleanup()


class CuerpoEvento(Base):
    def test_con_hora_usa_duracion(self):
        cuerpo, ini, fin, todo = gcal.cuerpo_evento(" Dentista ", "2030-03-04", "15:30", 45)
        self.assertFalse(todo)
        self.assertEqual(cuerpo["summary"], "Dentista")
        self.assertEqual((ini.hour, ini.minute), (15, 30))
        self.assertEqual(fin - ini, dt.timedelta(minutes=45))
        self.assertIsNotNone(dt.datetime.fromisoformat(cuerpo["start"]["dateTime"]).tzinfo)

    def test_sin_hora_es_todo_el_dia(self):
        cuerpo, _, _, todo = gcal.cuerpo_evento("Viaje", "2030-12-31")
        self.assertTrue(todo)
        self.assertEqual(cuerpo["start"], {"date": "2030-12-31"})
        self.assertEqual(cuerpo["end"], {"date": "2031-01-01"})

    def test_titulo_vacio_falla(self):
        with self.assertRaises(gcal.Error):
            gcal.cuerpo_evento("   ", "2030-01-01")


class Crear(Base):
    def test_evento_se_guarda_en_creados(self):
        with patch.object(gcal, "api", return_value={"id": "abc", "iCalUID": "abc@google.com"}) as api:
            r = gcal.crear_evento("Clase", "2099-05-01", "08:00", 90)
        self.assertTrue(r["ok"])
        metodo, url, cuerpo = api.call_args.args
        self.assertEqual((metodo, url), ("POST", gcal.CAL))
        creados = json.loads(Path(self.creados).read_text())
        self.assertEqual([c["uid"] for c in creados], ["abc@google.com"])

    def test_tarea_con_fecha(self):
        with patch.object(gcal, "api", return_value={"id": "t1"}) as api:
            gcal.crear_tarea("Informe", "2030-11-20")
        self.assertEqual(api.call_args.args[2], {"title": "Informe", "due": "2030-11-20T00:00:00.000Z"})

    def test_tareas_ordena_y_descarta_hechas(self):
        items = {"items": [{"id": "1", "title": "Sin fecha"},
                           {"id": "2", "title": "Luego", "due": "2030-02-01T00:00:00.000Z"},
                           {"id": "3", "title": "Hecha", "status": "completed"},
                           {"id": "4", "title": "Antes", "due": "2030-01-01T00:00:00.000Z"}]}
        with patch.object(gcal, "api", return_value=items):
            self.assertEqual([t["id"] for t in gcal.tareas()], ["4", "2", "1"])

    def test_sin_sesion_da_error_json(self):
        out = io.StringIO()
        with redirect_stdout(out):
            codigo = gcal.main(["tarea", "Algo"])
        self.assertEqual(codigo, 1)
        self.assertFalse(json.loads(out.getvalue())["ok"])


class Mezclar(Base):
    def _ev(self, uid, dias):
        ini = dt.datetime.now().astimezone() + dt.timedelta(days=dias)
        return {"inicio": ini.isoformat(), "fin": (ini + dt.timedelta(hours=1)).isoformat(),
                "titulo": uid, "lugar": "", "todoDia": False, "uid": uid}

    def test_anade_los_que_faltan_y_descarta_duplicados_y_pasados(self):
        feed = [self._ev("a", 1)]
        Path(self.creados).write_text(json.dumps([self._ev("a", 1), self._ev("b", 0.5), self._ev("viejo", -2)]))
        res = eventos.mezclar_creados(feed, self.creados)
        self.assertEqual([e["uid"] for e in res], ["b", "a"])

    def test_sin_archivo_no_cambia_nada(self):
        feed = [self._ev("a", 1)]
        self.assertIs(eventos.mezclar_creados(feed, self.creados), feed)


class FrescuraAgenda(Base):
    def setUp(self):
        super().setUp()
        self.cache = self.root / "eventos.json"
        self.conf = self.root / "url"
        self.conf.write_text("https://ejemplo.invalid/privado\n")
        for nombre, valor in (("CACHE", str(self.cache)), ("CONF", str(self.conf)), ("CREADOS", self.creados)):
            p = patch.object(eventos, nombre, valor)
            p.start()
            self.parches.append(p)

    def test_exito_actualiza_fecha_incluso_sin_eventos(self):
        with patch.object(eventos, "eventos", return_value=[]):
            r = eventos.leer_resultado()
        self.assertEqual(r["estado"], "actualizado")
        self.assertEqual(r["eventos"], [])
        self.assertEqual(r["actualizado"], self.cache.stat().st_mtime)

    def test_fallo_conserva_cache_y_su_fecha(self):
        self.cache.write_text("[]")
        fecha = self.cache.stat().st_mtime
        with patch.object(eventos, "eventos", side_effect=OSError("Sin red")):
            r = eventos.leer_resultado()
        self.assertEqual(r["estado"], "desactualizado")
        self.assertEqual(r["actualizado"], fecha)
        self.assertEqual(self.cache.stat().st_mtime, fecha)

    def test_cache_corrupta_no_revienta_ni_finge_agenda_vacia_actualizada(self):
        for contenido in ("{mal", "{}", '[{"inicio":"fecha inválida"}]'):
            self.cache.write_text(contenido)
            with self.subTest(contenido=contenido), patch.object(eventos, "eventos", side_effect=OSError("Sin red")):
                self.assertEqual(eventos.leer_resultado()["estado"], "error")

    def test_sin_configuracion_no_descarga(self):
        self.conf.unlink()
        with patch.object(eventos, "eventos") as descargar:
            self.assertEqual(eventos.leer_resultado()["estado"], "sin_configurar")
        descargar.assert_not_called()

    def test_fallo_no_expone_url_secreta(self):
        from contextlib import redirect_stderr
        err = io.StringIO()
        secreto = "https://servidor/calendario/token-privado"
        with patch.object(eventos, "eventos", side_effect=OSError(secreto)), redirect_stderr(err):
            r = eventos.leer_resultado()
        self.assertNotIn(secreto, err.getvalue() + json.dumps(r))

    def test_recuperacion_sustituye_cache_antigua(self):
        self.cache.write_text("[]")
        with patch.object(eventos, "eventos", side_effect=OSError("Sin red")):
            self.assertEqual(eventos.leer_resultado()["estado"], "desactualizado")
        with patch.object(eventos, "eventos", return_value=[]):
            self.assertEqual(eventos.leer_resultado()["estado"], "actualizado")


class Repeticion(unittest.TestCase):
    def test_describe_reglas_sin_inferir_por_titulos(self):
        self.assertEqual(eventos.repeticion("FREQ=DAILY;COUNT=3"),"diario")
        self.assertIn("lun",eventos.repeticion("FREQ=WEEKLY;BYDAY=MO,WE"))
        self.assertEqual(eventos.repeticion("FREQ=DAILY;INTERVAL=2"),"se repite")
        self.assertEqual(eventos.repeticion(""),"")

    def test_calendarios_y_excepciones_conservan_identidad(self):
        import importlib.util
        if not importlib.util.find_spec("icalendar") or not importlib.util.find_spec("recurring_ical_events"):
            self.skipTest("Requiere las dependencias opcionales de calendario")
        d=dt.date.today()+dt.timedelta(days=1);otra=d+dt.timedelta(days=1)
        formato=lambda x:x.strftime("%Y%m%d")
        ics=("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:serie\r\nDTSTART:"+formato(d)+"T213000Z\r\nDTEND:"+formato(d)+"T220000Z\r\nRRULE:FREQ=DAILY;COUNT=3\r\nSUMMARY:Clase\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:serie\r\nRECURRENCE-ID:"+formato(otra)+"T213000Z\r\nDTSTART:"+formato(otra)+"T223000Z\r\nDTEND:"+formato(otra)+"T230000Z\r\nSUMMARY:Clase movida\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n").encode()
        with tempfile.TemporaryDirectory() as tmp:
            conf=Path(tmp)/"url";conf.write_text("https://ejemplo.invalid/a\nhttps://ejemplo.invalid/b\n")
            with patch.object(eventos,"CONF",str(conf)),patch.object(eventos,"descargar",return_value=ics):
                datos=eventos.eventos()
        self.assertEqual(len(datos),6)
        self.assertEqual(len({e["serie"] for e in datos}),2)
        self.assertEqual(sum(e["excepcion"] for e in datos),2)
        self.assertTrue(all(e["repeticion"]=="diario" for e in datos))


class ErroresDeGoogle(unittest.TestCase):
    """gcal.py explica el fallo con un código estable y una salida, sin filtrar tokens."""
    def test_api_desactivada_da_enlace_a_google_cloud(self):
        e = gcal.clasificar(403, "Google Tasks API has not been used in project 123456 before or it is disabled.",
                            "https://tasks.googleapis.com/tasks/v1/lists/@default/tasks")
        self.assertEqual(e.codigo, "api_desactivada")
        self.assertIn("Google Tasks", str(e))
        self.assertEqual(e.enlace, "https://console.cloud.google.com/apis/library/tasks.googleapis.com?project=123456")
        self.assertIn("Habilitar", e.ayuda)

    def test_permiso_servicio_y_otros(self):
        self.assertEqual(gcal.clasificar(401, "Invalid Credentials", gcal.CAL).codigo, "sin_permiso")
        self.assertEqual(gcal.clasificar(403, "Insufficient Permission", gcal.CAL).codigo, "sin_permiso")
        self.assertEqual(gcal.clasificar(503, "", gcal.TASKS).codigo, "servicio")
        self.assertEqual(gcal.clasificar(400, "Bad Request", gcal.TASKS).codigo, "error")

    def test_main_imprime_codigo_y_ayuda(self):
        salida = io.StringIO()
        with patch.object(gcal, "tareas", side_effect=gcal.Error("Sin conexión con Google", "sin_red", "Se reintentará")):
            with redirect_stdout(salida):
                self.assertEqual(gcal.main(["tareas"]), 1)
        d = json.loads(salida.getvalue())
        self.assertEqual((d["ok"], d["codigo"], d["ayuda"]), (False, "sin_red", "Se reintentará"))
        self.assertNotIn("enlace", d)


if __name__ == "__main__":
    unittest.main()
