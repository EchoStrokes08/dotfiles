#!/usr/bin/env bash
# Instala FSR mediante Gamescope y configura Steam. Ejecutar sin sudo y con Steam cerrado.
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo 'Ejecuta este instalador sin sudo; pedirá la contraseña si hace falta.' >&2; exit 1; }
carpeta=$(dirname "$(readlink -f "$0")")
if pgrep -u "$(id -u)" -x steam >/dev/null; then
    echo 'Cierra Steam completamente (Steam → Salir) y vuelve a ejecutar este comando.' >&2
    exit 1
fi
python3 "$carpeta/configurar-fsr.py" --simular
if ! command -v gamescope >/dev/null; then sudo pacman -S --needed gamescope; fi
command -v gamescope >/dev/null || { echo 'Gamescope no quedó instalado.' >&2; exit 1; }
python3 "$carpeta/configurar-fsr.py"
unidades="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$unidades"
install -m644 "$carpeta/orion-fsr.service" "$unidades/orion-fsr.service"
install -m644 "$carpeta/orion-fsr.timer" "$unidades/orion-fsr.timer"
install -m644 "$carpeta/orion-fsr.path" "$unidades/orion-fsr.path"
systemctl --user daemon-reload
systemctl --user enable --now orion-fsr.timer orion-fsr.path
echo 'Actualización automática activa: al instalar o actualizar un juego, se configura en cuanto cierras Steam.'
