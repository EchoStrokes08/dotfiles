"""Agente y memoria sin ollama: el modelo y los embeddings se simulan."""
import datetime as dt
import json
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import agente  # noqa: E402
import memoria  # noqa: E402


def falso_vector(textos, consulta=False):
    """Bolsa de palabras clave → vector: suficiente para probar el orden sin un modelo."""
    claves = ["simplex", "fases", "vlan", "redes", "cocina", "receta"]
    m = np.array([[t.lower().count(k) + 0.01 for k in claves] for t in textos], dtype=np.float32)
    return m / np.linalg.norm(m, axis=1, keepdims=True)


class Memoria(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.p = [patch.object(memoria, "DB", Path(self.tmp.name) / "m.db"), patch.object(memoria, "vectores", falso_vector)]
        for x in self.p:
            x.start()

    def tearDown(self):
        for x in reversed(self.p):
            x.stop()
        self.tmp.cleanup()

    def test_trocear(self):
        texto = "\n\n".join(f"Párrafo {i}. " + "palabra " * 40 for i in range(30))
        trozos = memoria.trocear(texto)
        self.assertGreater(len(trozos), 5)
        self.assertTrue(all(len(t) <= memoria.TROZO + 10 for t in trozos))
        self.assertEqual(memoria.trocear("corto"), [])

    def test_indexa_incremental_y_busca_por_significado(self):
        lecturas = []

        def fuente():
            for clave, texto in [("doc:a", "Apuntes del método simplex y de las dos fases. " * 5),
                                 ("doc:b", "Configurar VLAN en redes con Packet Tracer. " * 5),
                                 ("doc:c", "Receta de cocina: arepas con queso. " * 5)]:
                yield clave, "v1", lambda c=clave, t=texto: lecturas.append(c) or [("documento", c, c, 0, x) for x in memoria.trocear(t)]
        with patch.object(memoria, "FUENTES", {"x": fuente}):
            r = memoria.indexar()
            self.assertEqual(r["fuentes_actualizadas"], 3)
            memoria.indexar()
        self.assertEqual(len(lecturas), 3)   # la segunda vez no relee nada
        self.assertEqual(memoria.buscar("lo de las redes virtuales", k=1)[0]["ref"], "doc:b")
        self.assertEqual(memoria.buscar("simplex", k=1)[0]["ref"], "doc:a")
        with patch.object(memoria, "vectores", lambda *a, **k: (_ for _ in ()).throw(OSError("sin ollama"))):
            self.assertEqual(memoria.buscar("arepas", k=1)[0]["ref"], "doc:c")   # cae a palabras exactas


class Agente(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.p = [patch.object(agente, "CONV", Path(self.tmp.name) / "c.json")]
        for x in self.p:
            x.start()
        agente.FUENTES.clear()

    def tearDown(self):
        for x in reversed(self.p):
            x.stop()
        self.tmp.cleanup()

    def correr(self, fn, *args):
        salida = io.StringIO()
        with redirect_stdout(salida):
            fn(*args)
        return [json.loads(l) for l in salida.getvalue().splitlines()]

    def test_consulta_sin_preguntar(self):
        respuestas = iter([("", [{"function": {"name": "agenda", "arguments": {"dia": "mañana"}}}]), ("Mañana: nada.", [])])
        with patch.object(agente, "chat", lambda m, **k: next(respuestas)), patch.dict(agente.CONSULTAS, {"agenda": lambda dia="hoy": "libre"}):
            ev = self.correr(agente.turno, "¿qué tengo mañana?")
        self.assertEqual([e["t"] for e in ev], ["herramienta"])
        d = agente.cargar()
        self.assertEqual(d["mensajes"][-2], {"role": "tool", "tool_name": "agenda", "content": "libre"})

    def test_accion_espera_confirmacion(self):
        hecho = []
        respuestas = iter([("", [{"function": {"name": "concentracion", "arguments": {"minutos": 50}}}]), ("Vale.", []), ("Listo.", [])])
        with patch.object(agente, "chat", lambda m, **k: next(respuestas)), \
                patch.object(agente, "sh", lambda a, timeout=10: hecho.append(a) or ""):
            ev = self.correr(agente.turno, "concentración de 50 minutos")
            self.assertEqual(ev[-1]["t"], "confirmar")
            self.assertEqual(hecho, [])                     # nada sin el «sí»
            self.correr(agente.confirmar, False)
            self.assertEqual(hecho, [])
        self.assertIn("dijo que no", agente.cargar()["mensajes"][-2]["content"])

        respuestas2 = iter([("", [{"function": {"name": "concentracion", "arguments": {"minutos": 25}}}]), ("Hecho.", [])])
        with patch.object(agente, "chat", lambda m, **k: next(respuestas2)), \
                patch.object(agente, "sh", lambda a, timeout=10: hecho.append(a) or ""):
            self.correr(agente.turno, "otra de 25")
            self.correr(agente.confirmar, True)
        self.assertEqual(hecho, [["qs", "ipc", "call", "concentracion", "empezar", "25"]])

    def test_preguntas_de_memoria_buscan_siempre(self):
        buscadas = []
        with patch.object(agente, "chat", lambda m, **k: ("Leíste X [1].", [])), \
                patch.object(agente, "t_buscar_memoria", lambda p, tipo=None: buscadas.append(p) or "[1] algo"):
            self.correr(agente.turno, "¿Qué estuve leyendo sobre redes?")
            self.correr(agente.turno, "¿qué hora es?")
        self.assertEqual(buscadas, ["¿Qué estuve leyendo sobre redes?"])

    def test_fechas(self):
        hoy = dt.date.today()
        self.assertEqual(agente.fecha_de("mañana"), hoy + dt.timedelta(days=1))
        self.assertEqual(agente.fecha_de("2026-01-05"), dt.date(2026, 1, 5))
        self.assertEqual(agente.fecha_de(agente.DIAS[hoy.weekday()]), hoy)

    def test_instrucciones_fijas_para_la_cache(self):
        self.assertEqual(agente.instrucciones(), agente.instrucciones())
        self.assertNotRegex(agente.instrucciones(), r"\d\d:\d\d")


if __name__ == "__main__":
    unittest.main()
