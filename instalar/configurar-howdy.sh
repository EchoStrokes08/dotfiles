#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    echo 'Ejecuta este script como oscar, sin sudo.' >&2
    exit 1
fi
if [[ ! -t 0 ]]; then
    echo 'Ejecuta el script desde una terminal interactiva.' >&2
    exit 1
fi

camera=''
for entry in /sys/class/video4linux/video*; do
    [[ -f "$entry/name" && -f "$entry/index" ]] || continue
    if [[ $(<"$entry/name") == *'Integrated Camera'* && $(<"$entry/index") == 0 ]]; then
        camera="/dev/${entry##*/}"
        break
    fi
done
if [[ -z "$camera" || ! -c "$camera" ]]; then
    echo 'No se encuentra la cámara integrada. Ejecuta esto en la terminal del equipo.' >&2
    exit 1
fi
# Preferir un enlace persistente de la misma cámara.
for link in /dev/v4l/by-id/* /dev/v4l/by-path/*; do
    if [[ -L "$link" && $(readlink -f -- "$link") == "$camera" ]]; then
        camera="$link"
        break
    fi
done

echo "Cámara: $camera"
echo 'Instalando Howdy desde AUR. Revisa los archivos de compilación cuando yay los muestre.'
yay -S --needed howdy

# Guardar la configuración instalada antes de cambiarla.
backup="/var/backups/howdy-config-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 700 "$backup"
while IFS= read -r config; do
    if [[ "$config" == */config.ini && -f "$config" ]]; then
        sudo cp -a -- "$config" "$backup/"
    fi
done < <(pacman -Qlq howdy)

sudo howdy set device_path "$camera"
sudo howdy set certainty 3
sudo howdy set timeout 4
sudo howdy set save_failed false
sudo howdy set save_successful false

echo 'Abre la tapa de privacidad de la cámara y mira hacia ella con buena luz.'
sudo howdy -U "$(id -un)" add
echo 'Se abrirá la prueba de reconocimiento. Pulsa q para salir de la ventana.'
sudo howdy -U "$(id -un)" test
echo
echo 'Registro y prueba terminados. Todavía no se han editado los archivos PAM.'
echo 'Indica si la prueba reconoció tu rostro para continuar con Hyprlock.'
