"""Edición precisa de opciones de lanzamiento sin reescribir el resto del VDF."""
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

RUTA = Path(__file__).resolve().parents[1] / "potencia/configurar-fsr.py"
spec = importlib.util.spec_from_file_location("configurar_fsr", RUTA)
fsr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fsr)


class ConfiguracionFsr(unittest.TestCase):
    def vdf(self, contenido):
        return '''// comentario conservado
"UserLocalConfigStore"
{
 "Software" { "Valve" { "Steam" { "apps" {
  "1243830"
  {
''' + contenido + '''
  }
 } } } }
 "OtrosDatos" { "1243830" "sin cambiar" }
}
'''

    def test_inserta_en_el_juego_sin_tocar_otras_secciones(self):
        original = self.vdf('   "Playtime" "162"')
        nuevo = fsr.configurar(original, ["1243830"], "/ruta/juego-fsr.sh %command%")
        self.assertEqual(nuevo.replace('  \t"LaunchOptions"\t\t"/ruta/juego-fsr.sh %command%"\n', ''), original)

    def test_sustituye_solo_el_valor_y_es_idempotente(self):
        original = self.vdf('   "LaunchOptions" "gamemoderun %command%"')
        comando = "/ruta/juego-fsr.sh %command%"
        nuevo = fsr.configurar(original, ["1243830"], comando)
        self.assertEqual(nuevo, original.replace('"gamemoderun %command%"', '"' + comando + '"'))
        self.assertEqual(fsr.configurar(nuevo, ["1243830"], comando), nuevo)

    def test_no_sobrescribe_ajustes_particulares(self):
        original = self.vdf('   "LaunchOptions" "mangohud %command%"')
        self.assertEqual(fsr.configurar(original, ["1243830"], "nuevo"), original)

    def test_crea_entrada_para_juego_nuevo_sin_sesion_previa(self):
        original = self.vdf('   "Playtime" "162"')
        nuevo = fsr.configurar(original, ["9999999"], "lanzador %command%")
        nodo = fsr.analizar(nuevo)
        for clave in ("UserLocalConfigStore", "Software", "Valve", "Steam", "apps", "9999999"):
            nodo = nodo[clave][0]
        self.assertEqual(nodo["LaunchOptions"][0], "lanzador %command%")
        self.assertEqual(fsr.configurar(nuevo, ["9999999"], "lanzador %command%"), nuevo)

    def manifiesto(self, biblioteca, appid, nombre="Juego nuevo", estado="4"):
        carpeta = biblioteca / "steamapps"
        carpeta.mkdir(parents=True, exist_ok=True)
        archivo = carpeta / f"appmanifest_{appid}.acf"
        archivo.write_text(f'"AppState" {{ "appid" "{appid}" "name" "{nombre}" "StateFlags" "{estado}" }}')
        return archivo

    def test_descubre_nuevas_instalaciones_y_bibliotecas_y_descarta_desinstalados(self):
        with tempfile.TemporaryDirectory() as tmp:
            steam = Path(tmp) / "steam"
            externa = Path(tmp) / "Otra biblioteca"
            archivo = self.manifiesto(steam, "9999999")
            self.manifiesto(externa, "8888888", "Otro juego")
            self.manifiesto(steam, "1493710", "Proton Experimental")
            self.manifiesto(steam, "4183110", "Steam Linux Runtime 4.0")
            self.manifiesto(steam, "322170", "Geometry Dash")
            self.manifiesto(steam, "7777777", estado="1026")
            (steam / "steamapps/libraryfolders.vdf").write_text(
                '"libraryfolders" { "0" { "path" ' + fsr.json.dumps(str(steam)) +
                ' } "1" { "path" ' + fsr.json.dumps(str(externa)) + ' } }')
            self.assertEqual(set(fsr.juegos_instalados(steam)), {"9999999", "8888888"})
            archivo.unlink()
            self.assertEqual(set(fsr.juegos_instalados(steam)), {"8888888"})
            self.manifiesto(steam, "6666666")
            self.assertEqual(set(fsr.juegos_instalados(steam)), {"6666666", "8888888"})

    def test_automatico_con_steam_abierto_no_lee_ni_escribe_configuracion(self):
        with patch.object(fsr, "steam_abierto", return_value=True), patch.object(fsr, "juegos_instalados") as descubrir:
            with patch("sys.argv", ["configurar-fsr.py", "--automatico"]):
                fsr.main()
            descubrir.assert_not_called()

    def test_biblioteca_vacia_es_valida(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(fsr.juegos_instalados(Path(tmp)), {})

    def test_automatico_agrega_nuevo_juego_sin_duplicar_copias_ni_cambiar_opciones_propias(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            steam = home / ".local/share/Steam"
            config = steam / "userdata/1/config/localconfig.vdf"
            config.parent.mkdir(parents=True)
            original = self.vdf('   "LaunchOptions" "mangohud %command%"')
            config.write_text(original)
            lanzador = home / ".config/hypr/scripts/juego-fsr.sh"
            lanzador.parent.mkdir(parents=True)
            lanzador.touch()
            self.manifiesto(steam, "1243830")
            self.manifiesto(steam, "9999999")
            with patch.object(fsr.Path, "home", return_value=home), patch.object(fsr, "steam_abierto", return_value=False), \
                 patch.dict(fsr.os.environ, {"XDG_STATE_HOME": str(home / "state")}), \
                 patch("sys.argv", ["configurar-fsr.py", "--automatico"]), redirect_stdout(io.StringIO()):
                fsr.main()
                cambiado = config.read_text()
                self.assertIn('"mangohud %command%"', cambiado)
                self.assertIn('"9999999"', cambiado)
                self.assertEqual(len(list(config.parent.glob("*.antes-fsr-*"))), 1)
                fsr.main()
                self.assertEqual(config.read_text(), cambiado)
                self.assertEqual(len(list(config.parent.glob("*.antes-fsr-*"))), 1)

    def test_rechaza_documentos_incompletos_o_ambiguos(self):
        for texto in ('"raiz" {', '"a" "1" "a" "2"', '"a" valor'):
            with self.subTest(texto=texto), self.assertRaises(ValueError):
                fsr.analizar(texto)


if __name__ == "__main__":
    unittest.main()
