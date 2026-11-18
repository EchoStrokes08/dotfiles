"""Activación compartida de GameMode y escritorio, con servicios simulados."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

RAIZ = Path(__file__).resolve().parents[1]
ENERGIA = RAIZ / "hypr/.config/hypr/scripts/juego-energia.sh"
FSR = RAIZ / "hypr/.config/hypr/scripts/juego-fsr.sh"


class Energia(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="juego-energia-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.runtime = self.base / "runtime"
        self.runtime.mkdir()
        self.perfil = self.base / "perfil"
        self.perfil.write_text("balanced\n")
        self.env = {**os.environ, "PATH": str(self.bin) + ":" + os.environ["PATH"],
                    "XDG_RUNTIME_DIR": str(self.runtime), "PERFIL_PRUEBA": str(self.perfil)}
        self.mock("powerprofilesctl", '''case "$1" in
get) cat "$PERFIL_PRUEBA" ;;
set) [ "${FALLAR_PERFIL:-0}" = 1 ] && exit 1; printf '%s\\n' "$2" > "$PERFIL_PRUEBA" ;;
esac''')
        self.mock("id", 'if [ "$1" = -nG ]; then echo oscar; else echo 1000; fi')
        self.mock("systemctl", "exit 0")
        self.mock("pgrep", "exit 1")

    def mock(self, nombre, cuerpo):
        ruta = self.bin / nombre
        ruta.write_text("#!/usr/bin/env bash\n" + cuerpo + "\n")
        ruta.chmod(0o755)

    def energia(self, *args):
        return subprocess.run(["bash", str(ENERGIA), *args], env=self.env,
                              capture_output=True, text=True, timeout=5)

    def test_ambos_origenes_conservan_potencia_hasta_que_sale_el_ultimo(self):
        for origen in ("gamemode", "escritorio"):
            self.assertEqual(self.energia("inicio", origen).returncode, 0)
        self.assertEqual(self.perfil.read_text().strip(), "performance")
        self.assertEqual((self.runtime / "juego-energia.perfil").read_text().strip(), "balanced")
        self.energia("fin", "gamemode")
        self.assertTrue((self.runtime / "juego-activo").exists())
        self.assertEqual(self.perfil.read_text().strip(), "performance")
        self.energia("fin", "escritorio")
        self.assertFalse((self.runtime / "juego-activo").exists())
        self.assertEqual(self.perfil.read_text().strip(), "balanced")

    def test_inicio_repetido_no_pierde_perfil_y_fin_sin_juego_no_lo_cambia(self):
        self.energia("fin", "escritorio")
        self.assertEqual(self.perfil.read_text().strip(), "balanced")
        self.energia("inicio")
        self.energia("inicio")
        self.assertEqual((self.runtime / "juego-energia.perfil").read_text().strip(), "balanced")

    def test_perfil_fallido_se_informa(self):
        self.env["FALLAR_PERFIL"] = "1"
        r = self.energia("inicio")
        self.assertIn("No se pudo activar", r.stderr)
        self.assertEqual(self.perfil.read_text().strip(), "balanced")

    def test_origen_desconocido_no_activa_juego(self):
        self.assertEqual(self.energia("inicio", "otro").returncode, 2)
        self.assertFalse((self.runtime / "juego-activo").exists())

    def test_lanzador_nativo_preserva_argumentos_y_codigo_de_salida(self):
        self.mock("gamemoderun", 'printf "%s\\n" "$@" > "$PERFIL_PRUEBA"; exit 7')
        r = subprocess.run(["bash", str(FSR), "juego", "ruta con espacios", "--opcion"],
                           env={**self.env, "FSR_RES": "native"}, capture_output=True, timeout=5)
        self.assertEqual(r.returncode, 7)
        self.assertEqual(self.perfil.read_text().splitlines(), ["juego", "ruta con espacios", "--opcion"])

    def test_resolucion_invalida_no_ejecuta_el_juego(self):
        r = subprocess.run(["bash", str(FSR), "juego"], env={**self.env, "FSR_RES": "720p"},
                           capture_output=True, timeout=5)
        self.assertEqual(r.returncode, 2)

    def test_fsr_reescala_sin_limitar_fps_y_preserva_argumentos(self):
        self.mock("gamescope", 'printf "%s\\n" "$@" > "$PERFIL_PRUEBA"; exit 7')
        self.mock("hyprctl", '''echo '[{"focused": true, "width": 1920, "height": 1080}]' ''')
        r = subprocess.run(["bash", str(FSR), "juego", "ruta con espacios"],
                           env={**self.env, "FSR_RES": "1280x720", "FSR_FPS": "0"}, capture_output=True, timeout=5)
        self.assertEqual(r.returncode, 7)
        self.assertEqual(self.perfil.read_text().splitlines(),
                         ["-w", "1280", "-h", "720", "-W", "1920", "-H", "1080",
                          "-F", "fsr", "-f", "--", "gamemoderun", "juego", "ruta con espacios"])

    def test_fsr_monitor_ilegible_usa_salida_conocida_y_limite_opcional(self):
        self.mock("gamescope", 'printf "%s\\n" "$@" > "$PERFIL_PRUEBA"')
        self.mock("hyprctl", "exit 1")
        r = subprocess.run(["bash", str(FSR), "juego"],
                           env={**self.env, "FSR_RES": "960x540", "FSR_FPS": "60"}, capture_output=True, timeout=5)
        self.assertEqual(r.returncode, 0)
        args = self.perfil.read_text().splitlines()
        self.assertEqual(args[:10], ["-w", "960", "-h", "540", "-W", "1920", "-H", "1080", "-r", "60"])


if __name__ == "__main__":
    unittest.main()
