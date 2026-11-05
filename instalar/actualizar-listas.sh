#!/usr/bin/env bash
# Regenera las listas de paquetes desde ESTE sistema. Córrelo cuando instales algo nuevo
# y haz commit: así el instalador siempre trae lo mismo que tienes.
#   ~/dotfiles/instalar/actualizar-listas.sh
set -euo pipefail
cd "$(dirname "$0")"

# Paquetes que NO deben ir a otro equipo
EXCLUIR='^(yay|yay-bin|yay-debug|paru-bin|paru-bin-debug|.*-debug|packettracer)$'

# Dependencias que no son "explícitas" pero hacen falta (Buds Manager)
EXTRA_PACMAN="python-gobject gtk4 libadwaita"
# Del AUR que el instalador debe traer aunque aún no estén aquí
EXTRA_AUR="vesktop-bin spicetify-cli"

{
  echo "# pacman: paquetes de los repos oficiales (generado por actualizar-listas.sh)"
  { pacman -Qqen; tr ' ' '\n' <<<"$EXTRA_PACMAN"; } | grep -Ev "$EXCLUIR" | sort -u
} > paquetes.txt

{
  echo "# AUR (los instala yay; generado por actualizar-listas.sh)"
  { pacman -Qqem; tr ' ' '\n' <<<"$EXTRA_AUR"; } | grep -Ev "$EXCLUIR" | sort -u
} > aur.txt

{
  echo "# Flatpak desde Flathub (generado por actualizar-listas.sh)"
  flatpak list --app --columns=application | sort -u
} > flatpak.txt

printf 'pacman: %s · AUR: %s · flatpak: %s\n' \
  "$(grep -vc '^#' paquetes.txt)" "$(grep -vc '^#' aur.txt)" "$(grep -vc '^#' flatpak.txt)"
