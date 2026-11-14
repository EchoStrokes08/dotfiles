#!/usr/bin/env python3
"""Captura aislada de componentes reales con datos simulados de la fase 1.

python3 tests/previsualizar_orion.py [destino.png]
No abre paneles de la sesión, no consulta servicios ni lee datos personales.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

RAIZ = Path(__file__).resolve().parents[1]
QML = RAIZ / "quickshell/.config/quickshell"


def main():
    destino = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else RAIZ / "docs/screenshots/orion-fase1-estados.png"
    destino.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="orion-preview-") as tmp:
        base = Path(tmp)
        config = base / "config"
        config.mkdir()
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        for nombre in ("Paleta", "EstiloPanel", "FondoBoton", "FondoPanel", "ControlRapido", "BotonCompacto",
                       "ModoTeclado", "IndicadorTeclado", "EstadoAgenda", "EstadoRecarga", "TarjetaRecarga"):
            shutil.copy(QML / f"{nombre}.qml", config)
        (config / "EstadoEscritorio.qml").write_text('''pragma Singleton
import Quickshell
Singleton { property string perfil: "minimo"; property var datos: ({}) }
''')
        (config / "Eventos.qml").write_text('''pragma Singleton
import Quickshell
Singleton {
    property string estadoAgenda: "desactualizado"
    property string errorAgenda: "Sin conexión"
    property real sincronizadoEn: 1794594000
    property bool leyendo: false
    function actualizar() {}
}
''')
        texto = (RAIZ / "tests/fixtures/orion-fase1.qml").read_text()
        (config / "shell.qml").write_text(texto.replace("__CAPTURA__", json.dumps(str(destino))))
        env = {**os.environ, "HOME": tmp, "XDG_RUNTIME_DIR": str(runtime), "XDG_CONFIG_HOME": str(base / ".config"),
               "XDG_STATE_HOME": str(base / "state"), "XDG_CACHE_HOME": str(base / "cache"),
               "QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "", "QT_QUICK_CONTROLS_STYLE": "Basic",
               "QSG_RHI_BACKEND": "opengl", "LIBGL_ALWAYS_SOFTWARE": "1",
               "HYPRLAND_INSTANCE_SIGNATURE": "", "WAYLAND_DISPLAY": ""}
        env.pop("QT_QUICK_BACKEND", None)
        r = subprocess.run(["qs", "-p", str(config), "--no-color"], env=env, capture_output=True, text=True, timeout=10)
        if r.returncode or not destino.is_file():
            raise RuntimeError(r.stdout + r.stderr)
    print(destino)


if __name__ == "__main__":
    main()
