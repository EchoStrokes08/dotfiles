#!/usr/bin/env bash
# Instala lo de rendimiento en juegos que necesita root:
#   · gamescope (FSR en los juegos de Steam, ver hypr/scripts/juego-fsr.sh)
#   · ryzenadj + el servicio juego-potencia (más vatios al procesador: solo jugando, con cargador y frío)
# Uso (como tu usuario, NO con sudo; pedirá la contraseña):  ~/dotfiles/potencia/instalar.sh
# Quitarlo:  ~/dotfiles/potencia/instalar.sh --quitar
set -uo pipefail
[[ $EUID -ne 0 ]] || { echo "Ejecútalo sin sudo (yay no funciona como root); ya pedirá la contraseña."; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"

if [ "${1:-}" = --quitar ]; then
    sudo systemctl disable --now juego-potencia.service
    sudo rm -f /etc/systemd/system/juego-potencia.service /usr/local/bin/juego-potencia
    sudo systemctl daemon-reload
    echo "✓ juego-potencia quitado (el procesador vuelve a sus límites de fábrica)"
    exit 0
fi

echo "── 1. gamescope y ryzenadj"
sudo pacman -S --needed --noconfirm gamescope || exit 1
yay -S --needed --noconfirm ryzenadj || exit 1

lee() { sudo ryzenadj -i 2>/dev/null | grep -q 'STAPM LIMIT'; }
echo "── 2. ¿ryzenadj puede leer este procesador?"
if ! lee; then
    echo "   No directamente: instalo el módulo ryzen_smu y lo vuelvo a probar"
    yay -S --needed --noconfirm ryzen_smu-dkms-git || exit 1
    sudo modprobe ryzen_smu && echo ryzen_smu | sudo tee /etc/modules-load.d/ryzen_smu.conf >/dev/null
    if ! lee; then
        echo "✗ ryzenadj no puede leer los límites de este procesador. No activo juego-potencia (el resto sí queda)."
        exit 1
    fi
fi
sudo ryzenadj -i | grep -E 'STAPM LIMIT|PPT LIMIT (FAST|SLOW)|THM LIMIT CORE'

echo "── 3. Servicio juego-potencia"
sudo install -Dm755 juego-potencia /usr/local/bin/juego-potencia
sudo install -Dm644 juego-potencia.service /etc/systemd/system/juego-potencia.service
sudo systemctl daemon-reload
sudo systemctl enable --now juego-potencia.service
sleep 3
systemctl --no-pager --lines=5 status juego-potencia.service | sed -n '1,3p;/Límites/p'
echo
juego-potencia estado
echo "✓ Listo. Ver qué hace mientras juegas:  juego-potencia estado   ·   journalctl -u juego-potencia -f"
