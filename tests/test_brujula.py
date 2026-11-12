"""Brújula: contexto automático, línea de tiempo, sesión, búsqueda universal y sugerencias.
Sin Hyprland ni Quickshell: todo lo externo se simula y los datos van a carpetas temporales."""
import datetime as dt
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hypr/.config/hypr/scripts"))
import brujula as b  # noqa: E402
import buscar  # noqa: E402
import indice  # noqa: E402
import sugerencias  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.parches = [
            patch.object(b, "ESTADO", self.root / "brujula"),
            patch.object(b, "LINEA", self.root / "brujula/linea"),
            patch.object(b, "CAPTURAS", self.root / "brujula/capturas"),
            patch.object(b, "osd", lambda *a: None),
            patch.dict(os.environ, {"HYPRLAND_INSTANCE_SIGNATURE": "prueba"}),
        ]
        for p in self.parches:
            p.start()

    def tearDown(self):
        for p in reversed(self.parches):
            p.stop()
        self.tmp.cleanup()


class Contexto(Base):
    """Las reglas se activan, aplican sus efectos y, al terminar, deshacen solo lo que nadie tocó."""

    REGLAS = [
        {"id": "programar", "nombre": "Programar", "si": {"apps": ["code*"], "gracia": 0}, "entonces": {"perfil": "lectura", "no_molestar": True}},
        {"id": "juego", "nombre": "Jugar", "si": {"apps": ["steam_app_*"], "modo": "abierta"}, "entonces": {"perfil": "rendimiento", "juego": True}},
    ]

    def setUp(self):
        super().setUp()
        self.escritorio = {"perfil": "cristal", "juego": "automatico"}
        self.puestos = []

        def poner(efecto, valor, deshacer=False):
            self.puestos.append((efecto, valor, deshacer))
            if efecto == "perfil":
                self.escritorio["perfil"] = valor
            if efecto == "juego":
                self.escritorio["juego"] = valor
        self.extra = [patch.object(b, "escritorio", lambda: dict(self.escritorio)),
                      patch.object(b.Contexto, "poner", staticmethod(poner)),
                      patch.object(b, "CONFIRMAR", 0),
                      patch.object(b, "bateria", lambda: (80, True))]
        for p in self.extra:
            p.start()
        self.ctx = b.Contexto()

    def tearDown(self):
        for p in reversed(self.extra):
            p.stop()
        super().tearDown()

    def paso(self, foco, clases):
        self.ctx.aplicar(self.ctx.evaluar(self.REGLAS, foco, clases, 1, dt.datetime(2026, 11, 11, 10)))

    def test_activa_y_restaura(self):
        self.paso("code-oss", ["code-oss", "firefox"])
        self.assertEqual(self.ctx.activas, ["programar"])
        self.assertEqual(self.escritorio["perfil"], "lectura")
        self.assertIn(("no_molestar", True, False), self.puestos)
        self.paso("firefox", ["firefox"])   # se cerró VS Code
        self.assertEqual(self.ctx.activas, [])
        self.assertEqual(self.escritorio["perfil"], "cristal")
        self.assertIn(("no_molestar", None, True), self.puestos)

    def test_respeta_cambio_manual(self):
        self.paso("code-oss", ["code-oss"])
        self.escritorio["perfil"] = "minimo"      # el usuario elige otro perfil a mano
        self.paso("firefox", ["firefox"])
        self.assertEqual(self.escritorio["perfil"], "minimo")

    def test_gana_la_regla_de_arriba_y_luego_vuelve(self):
        self.paso("code-oss", ["code-oss", "steam_app_42"])
        self.assertEqual(self.ctx.activas, ["programar", "juego"])
        self.assertEqual(self.escritorio["perfil"], "lectura")
        self.assertEqual(self.escritorio["juego"], "si")
        self.paso("steam_app_42", ["steam_app_42"])   # ya no hay VS Code: queda el juego
        self.assertEqual(self.escritorio["perfil"], "rendimiento")
        self.paso("firefox", ["firefox"])
        self.assertEqual(self.escritorio["perfil"], "cristal")   # el «previo» de verdad, no el intermedio
        self.assertEqual(self.escritorio["juego"], "automatico")

    def test_gracia_tras_cambiar_de_ventana(self):
        reglas = [dict(self.REGLAS[0], si={"apps": ["code*"], "gracia": 3})]
        ahora = dt.datetime(2026, 11, 11, 10)
        self.ctx.aplicar(self.ctx.evaluar(reglas, "code-oss", ["code-oss", "firefox"], 1, ahora))
        self.ctx.aplicar(self.ctx.evaluar(reglas, "firefox", ["code-oss", "firefox"], 1, ahora))
        self.assertEqual(self.ctx.activas, ["programar"])   # mirar la documentación no lo apaga

    def test_condiciones(self):
        reglas = [{"id": "ahorro", "si": {"bateria_menor": 20, "cargando": False}, "entonces": {}},
                  {"id": "noche", "si": {"hora": ["22:00", "06:00"], "dias": ["mie"]}, "entonces": {}},
                  {"id": "proyector", "si": {"pantalla_externa": True}, "entonces": {}}]
        with patch.object(b, "bateria", lambda: (15, False)):
            r = self.ctx.evaluar(reglas, "", [], 2, dt.datetime(2026, 11, 11, 23, 30))   # miércoles
        self.assertEqual([x["id"] for x in r], ["ahorro", "noche", "proyector"])
        with patch.object(b, "bateria", lambda: (15, True)):
            r = self.ctx.evaluar(reglas, "", [], 1, dt.datetime(2026, 11, 12, 23, 30))   # jueves, cargando
        self.assertEqual(r, [])

    def test_describir(self):
        d = b.describir({"si": {"bateria_menor": 20, "cargando": False}, "entonces": {"perfil": "minimo", "energia": "power-saver"}})
        self.assertEqual(d["cuando"], "batería < 20 % · sin cargador")
        self.assertIn("ahorro de energía", d["hace"])


class Linea(Base):
    def escribir(self, regs):
        b.LINEA.mkdir(parents=True)
        dia = dt.date.fromtimestamp(regs[0]["t"])
        (b.LINEA / f"{dia}.jsonl").write_text("\n".join(json.dumps(r) for r in regs) + "\n")
        return dia

    def test_bloques_unen_y_cortan_en_pausas(self):
        t0 = int(dt.datetime(2026, 11, 10, 9).timestamp())
        dia = self.escribir([{"t": t0, "c": "firefox", "ti": "A"}, {"t": t0 + 60, "c": "firefox", "ti": "B"},
                             {"t": t0 + 120, "c": "kitty", "p": 1}, {"t": t0 + 300, "e": "pausa"},
                             {"t": t0 + 900, "c": "firefox", "ti": "C"}])
        bs = b.bloques(dia)
        self.assertEqual([(x["clase"], x["fin"] - x["inicio"]) for x in bs], [("firefox", 120), ("kitty", 180), ("firefox", 900)])
        self.assertEqual(bs[0]["titulos"], ["A", "B"])
        self.assertTrue(bs[1]["privado"])
        r = b.resumen_linea(dia)
        self.assertEqual(r["total"], 1200)
        self.assertEqual(r["resumen"][0]["clase"], "firefox")

    def test_privacidad_y_navegacion_privada(self):
        l = b.Linea()
        with patch.object(b, "ESTABLE", 0):
            l.ver("firefox", "Algo — Navegación privada de Mozilla Firefox")
            l.tick({}, False, False, "")
            l.ver("kitty", "~/secreto")
            l.tick({}, False, True, "")   # privacidad activa
            l.ver("Bitwarden", "Bóveda")
            l.tick({"sin_titulo": ["bitwarden"]}, False, False, "")
        regs = b.leer_linea(dt.date.today())
        self.assertTrue(all("ti" not in r and r.get("p") == 1 for r in regs))

    def test_bloqueo_pausa(self):
        l = b.Linea()
        with patch.object(b, "ESTABLE", 0):
            l.ver("kitty", "x")
            l.tick({}, False, False, "Programar")
            l.tick({}, True, False, "")
        regs = b.leer_linea(dt.date.today())
        self.assertEqual(regs[0]["x"], "Programar")
        self.assertEqual(regs[-1]["e"], "pausa")

    def test_limpieza(self):
        b.LINEA.mkdir(parents=True)
        viejo = b.LINEA / f"{dt.date.today() - dt.timedelta(days=40)}.jsonl"
        viejo.write_text("")
        b.Linea.limpiar({"dias": 30})
        self.assertFalse(viejo.exists())


class Sesion(Base):
    def test_restaura_solo_lo_que_falta_en_su_espacio(self):
        b.ESTADO.mkdir(parents=True)
        b.atomico(b.ESTADO / "sesion-anterior.json", {"version": 1, "apps": [
            {"clase": "kitty", "ws": 1, "argv": ["kitty", "--directory", "/tmp"]},
            {"clase": "firefox", "ws": 2, "argv": ["firefox"]},
            {"clase": "malo", "ws": 99, "argv": ["sh"]},
            {"clase": "raro", "ws": 3, "argv": "rm -rf ~"}]})
        despachos = []
        with patch.object(b, "ejecutar", lambda a, t=4: json.dumps([{"class": "firefox"}]) if a[:2] == ["hyprctl", "-j"] else ""), \
                patch.object(b, "despachar", despachos.append), patch.object(b.shutil, "which", lambda x: "/usr/bin/" + x), \
                patch.object(b.time, "sleep", lambda s: None):
            r = b.restaurar()
        self.assertEqual(len(despachos), 1)
        self.assertIn('kitty --directory /tmp', despachos[0])
        self.assertIn('workspace="1"', despachos[0])
        self.assertIn("1 apps", r["mensaje"])
        self.assertFalse((b.ESTADO / "sesion-anterior.json").exists())

    def test_foto_una_por_app_salvo_terminales(self):
        ventanas = [{"class": "kitty", "pid": 1, "workspace": {"id": 1}, "at": [0, 0]},
                    {"class": "kitty", "pid": 2, "workspace": {"id": 1}, "at": [9, 0]},
                    {"class": "firefox", "pid": 3, "workspace": {"id": 2}, "at": [0, 0]},
                    {"class": "firefox", "pid": 3, "workspace": {"id": 4}, "at": [0, 0]},
                    {"class": "kitty", "pid": 4, "workspace": {"id": -98}, "at": [0, 0]},
                    {"class": "xdg-desktop-portal-gtk", "pid": 5, "workspace": {"id": 3}, "at": [0, 0]}]
        with patch.object(b, "ejecutar", lambda a, t=4: json.dumps(ventanas)), \
                patch.object(b, "comando_de", lambda w: [w["class"]]), patch.object(b, "escritorio", lambda: {}):
            f = b.foto_sesion({"ignorar": ["xdg-desktop-portal*"]})
        self.assertEqual([(a["clase"], a["ws"]) for a in f["apps"]], [("kitty", 1), ("kitty", 1), ("firefox", 2)])

    def test_nombres_legibles(self):
        with patch.object(b, "apps_instaladas", lambda: ({}, {})):
            self.assertEqual(b.nombre_de("com-cburch-logisim-Main"), "Logisim")
            self.assertEqual(b.nombre_de("org.vinegarhq.Sober"), "Sober")


class Busqueda(Base):
    def test_indice_de_documentos(self):
        docs = self.root / "Documents"
        docs.mkdir()
        (docs / "apuntes.md").write_text("El método simplex resuelve problemas de programación lineal.")
        with zipfile.ZipFile(docs / "informe.docx", "w") as z:
            z.writestr("word/document.xml", "<w:document><w:p><w:t>Análisis de circuitos RLC</w:t></w:p></w:document>")
        (docs / ".oculto.md").write_text("simplex")
        with patch.object(indice, "DB", self.root / "cache/documentos.db"), patch.object(indice, "RAICES", [docs]):
            self.assertEqual(indice.actualizar()["indexados"], 2)
            self.assertEqual(indice.actualizar()["indexados"], 0)   # incremental
            self.assertEqual([Path(r).name for r, _ in indice.buscar("metodo simpl")], ["apuntes.md"])
            self.assertEqual([Path(r).name for r, _ in indice.buscar("circuitos")], ["informe.docx"])
            (docs / "apuntes.md").unlink()
            self.assertEqual(indice.actualizar()["borrados"], 1)
            self.assertEqual(indice.buscar("simplex"), [])

    def test_todo_agrupa_y_tolera_fallos(self):
        def falla(q):
            raise RuntimeError("roto")
        fuentes = {"ventanas": lambda q: [{"nombre": "v", "cmd": ["x"]}], "documentos": falla,
                   "notas": lambda q: [{"nombre": f"n{i}", "cmd": ["x"]} for i in range(9)],
                   "historial": lambda q: [], "linea": lambda q: [], "atajos": lambda q: [{"nombre": "sin cmd", "cmd": []}],
                   "portapapeles": lambda q: []}
        with patch.multiple(buscar, **fuentes):
            r = buscar.todo("algo")
        self.assertEqual([x["grupo"] for x in r], ["Ventanas"] + ["Notas"] * 4)
        self.assertEqual(buscar.todo("ab"), [])   # menos de 3 letras: nada


class Sugerencias(Base):
    def test_ideas_desde_los_datos(self):
        state = self.root / "state"
        ayer = dt.date.today() - dt.timedelta(days=1)
        (state / "tiempo-pantalla").mkdir(parents=True)
        (state / "tiempo-pantalla" / f"{ayer}.json").write_text(json.dumps({"discord": 2 * 3600, "firefox": 8 * 3600}))
        (state / "mesa-trabajo").mkdir()
        (state / "mesa-trabajo/proyectos.json").write_text(json.dumps({"ultimo": "p1", "proyectos": [
            {"id": "p1", "nombre": "Taller de redes", "siguiente": "Configurar las VLAN"}]}))
        import salud
        with patch.object(sugerencias, "STATE", state), patch.object(sugerencias, "HOME", self.root), \
                patch.object(salud, "todo", lambda: {"comprobaciones": []}), \
                patch.object(b, "config", lambda: {"reglas": [], "sugerencias": {"distracciones": ["discord"]}, "linea": {}, "sesion": {}}):
            d = sugerencias.calcular()
        ids = [s["id"] for s in d["sugerencias"]]
        self.assertEqual(ids, ["concentracion", "proyecto", "pausas"])
        self.assertIn("Configurar las VLAN", d["sugerencias"][1]["detalle"])
        self.assertEqual(d["datos"]["ayer"], "10 h 00 min")


class Completado(Base):
    """Geometría, concentración programada, capturas cifradas, archivos del día y ajustes."""

    def test_reglas_de_ventana_validadas(self):
        a = {"ws": 3, "flotante": True, "geo": {"x": 420, "y": 160, "w": 560, "h": 300}}
        self.assertEqual(b.reglas_ventana(a), '{workspace="3", float=true, size="560 300", move="420 160"}')
        malo = {"ws": 2, "flotante": True, "geo": {"x": "0) os.exit(", "y": 1, "w": 500, "h": 300}}
        self.assertEqual(b.reglas_ventana(malo), '{workspace="2", float=true}')   # nada de texto hacia Lua
        self.assertEqual(b.reglas_ventana({"ws": 1, "completa": True}), '{workspace="1", fullscreen=true}')

    def test_programar_y_solapes(self):
        manana = int(time.time()) + 86400
        self.assertIn("Concentración programada", b.programar(manana, 90)["mensaje"])
        with self.assertRaises(ValueError):
            b.programar(manana + 1800, 30)           # se solapa
        with self.assertRaises(ValueError):
            b.programar(int(time.time()) - 3600, 30)  # ya pasó
        ident = b.programados()[0]["id"]
        b.cancelar_programado(ident)
        self.assertEqual(b.programados(), [])

    def test_aviso_antes_y_empieza_a_su_hora(self):
        lanzados = []
        ahora = time.time()
        b.atomico(b.ESTADO / "programados.json", [
            {"id": "a", "inicio": int(ahora + 120), "minutos": 30, "avisado": False},   # en 2 min: aviso
            {"id": "b", "inicio": int(ahora - 60), "minutos": 50, "avisado": True},     # empezó hace 1 min
            {"id": "c", "inicio": int(ahora - 3600), "minutos": 50, "avisado": True}])  # el equipo estaba apagado
        with patch.object(b, "lanzar", lanzados.append):
            b.revisar_programados()
            b.revisar_programados()   # el aviso no se repite
        self.assertEqual(sum(1 for x in lanzados if x[0] == "notify-send"), 1)
        empezar = [x for x in lanzados if x[:4] == ["qs", "ipc", "call", "concentracion"]]
        self.assertEqual(empezar, [["qs", "ipc", "call", "concentracion", "empezar", "49"]])
        self.assertEqual([x["id"] for x in b.programados()], ["a"])

    def test_hueco_libre_esquiva_eventos(self):
        ahora = dt.datetime(2026, 11, 11, 9, 5)
        evento = (dt.datetime(2026, 11, 11, 9, 30).timestamp(), dt.datetime(2026, 11, 11, 10, 40).timestamp())
        self.assertEqual(sugerencias.hueco_libre(90, ahora, [evento]), dt.datetime(2026, 11, 11, 11, 0))
        tarde = dt.datetime(2026, 11, 11, 21, 50)
        self.assertEqual(sugerencias.hueco_libre(90, tarde, []), dt.datetime(2026, 11, 12, 9, 0))

    def test_cifrado_ida_y_vuelta(self):
        destino = self.root / "x.enc"
        self.assertTrue(b.openssl("cifrar", "clave-de-prueba", b"\xff\xd8\xffJPEG", destino))
        self.assertNotIn(b"JPEG", destino.read_bytes())
        claro = self.root / "x.jpg"
        self.assertTrue(b.openssl("descifrar", "clave-de-prueba", destino.read_bytes(), claro))
        self.assertEqual(claro.read_bytes(), b"\xff\xd8\xffJPEG")
        self.assertFalse(b.openssl("descifrar", "otra", destino.read_bytes(), self.root / "y.jpg"))

    def test_sin_anillo_no_hay_capturas(self):
        with patch.object(b, "clave_capturas", lambda crear=True: ""), patch.object(b.subprocess, "run") as run:
            b.captura_cifrada()
        run.assert_not_called()

    def test_archivos_del_dia(self):
        xbel = self.root / ".local/share/recently-used.xbel"
        xbel.parent.mkdir(parents=True)
        xbel.write_text('''<?xml version="1.0"?><xbel version="1.0" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks">
<bookmark href="file:///tmp/Informe%20final.pdf" added="2026-11-10T10:00:00Z" modified="2026-11-10T10:00:00Z" visited="2026-11-10T10:00:00Z">
<info><metadata owner="http://freedesktop.org"><bookmark:applications>
<bookmark:application name="Zathura" exec="zathura %u" modified="2026-11-10T15:00:00Z" count="1"/>
</bookmark:applications></metadata></info></bookmark></xbel>''')
        with patch.object(b, "HOME", self.root):
            dia = dt.datetime(2026, 11, 10, 15, tzinfo=dt.timezone.utc).astimezone().date()
            r = b.archivos_del_dia(dia)
        self.assertEqual([(x["nombre"], x["app"]) for x in r], [("Informe final.pdf", "Zathura")])

    def test_ajustes_se_aplican(self):
        r = buscar.ajustes("tema claro")
        self.assertEqual(r[0]["nombre"], "Tema claro")
        self.assertEqual(r[0]["cmd"][-1], "claro")
        self.assertTrue(any("Perfil lectura" in x["nombre"] for x in buscar.ajustes("lectura")))
        self.assertTrue(all(x["cmd"] for x in buscar.ajustes("bluetooth")))


if __name__ == "__main__":
    unittest.main()
