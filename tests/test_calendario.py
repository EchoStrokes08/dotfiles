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


if __name__ == "__main__":
    unittest.main()
