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

    def whatsapp(self, respuesta, espera="0"):
        """Simula WhatsApp abierto y un aviso que responde `respuesta`; devuelve el registro de systemctl."""
        registro = self.base / "systemctl.log"
        self.env.update(REGISTRO=str(registro), RESPUESTA=respuesta, ESPERA=espera)
        self.mock("systemctl", '''if [ "$2" = list-units ]; then
    case "$*" in *zapzap*) echo "app-flatpak-com.rtosta.zapzap-1.scope loaded active running x" ;; esac
else echo "$*" >> "$REGISTRO"; fi''')
        self.mock("notify-send", 'echo 42; sleep "$ESPERA"; [ -n "$RESPUESTA" ] && echo "$RESPUESTA"; exit 0')
        self.mock("gdbus", 'echo "gdbus $*" >> "$REGISTRO"')
        return registro

    def esperar_pregunta(self):
        import time
        for _ in range(100):
            if not (self.runtime / "juego-pregunta").exists():
                return
            pid = (self.runtime / "juego-pregunta").read_text().strip()
            if not Path(f"/proc/{pid}").exists():
                return
            time.sleep(0.05)
        self.fail("la pregunta de WhatsApp no terminó")

    def test_whatsapp_no_se_toca_sin_preguntar(self):
        registro = self.whatsapp("")
        self.assertEqual(self.energia("inicio").returncode, 0)
        self.esperar_pregunta()
        self.assertNotIn("zapzap", registro.read_text() if registro.exists() else "")
        self.assertFalse((self.runtime / "juego-congeladas").exists())

    def test_whatsapp_pausado_si_se_elige_y_vuelve_al_terminar(self):
        registro = self.whatsapp("pausar")
        self.energia("inicio")
        self.esperar_pregunta()
        self.assertIn("--user freeze app-flatpak-com.rtosta.zapzap-1.scope", registro.read_text())
        self.energia("fin")
        self.assertIn("--user thaw app-flatpak-com.rtosta.zapzap-1.scope", registro.read_text())

    def test_whatsapp_cerrado_si_se_elige(self):
        registro = self.whatsapp("cerrar")
        self.energia("inicio")
        self.esperar_pregunta()
        self.assertIn("--user stop app-flatpak-com.rtosta.zapzap-1.scope", registro.read_text())

    def test_fin_del_juego_cancela_la_pregunta_y_cierra_el_aviso(self):
        registro = self.whatsapp("pausar", espera="30")
        self.energia("inicio")
        import time; time.sleep(0.3)
        self.energia("fin")
        self.esperar_pregunta()
        texto = registro.read_text() if registro.exists() else ""
        self.assertNotIn("freeze", texto)
        self.assertIn("CloseNotification 42", texto)

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
