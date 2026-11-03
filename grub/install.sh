#!/usr/bin/env bash
# Instala el tema «Ayu Dark Glass» en GRUB.   Uso: sudo ./install.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Ejecútalo con sudo: sudo $0"; exit 1; }

SRC="$(cd "$(dirname "$0")" && pwd)/ayu-dark-glass"
DEST=/boot/grub/themes/ayu-dark-glass
CFG=/etc/default/grub

# 1. Copiar el tema a /boot, que es donde GRUB lo busca al arrancar
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
echo "✓ Tema copiado a $DEST"

# 2. Copia de seguridad de la config
cp "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"

# 3. Activar el tema y la resolución nativa
set_var() {   # set_var CLAVE valor  → reemplaza (o descomenta) la línea, o la añade
    if grep -qE "^#?\s*$1=" "$CFG"; then
        sed -i -E "s|^#?\s*$1=.*|$1=$2|" "$CFG"
    else
        echo "$1=$2" >> "$CFG"
    fi
}
set_var GRUB_THEME "\"$DEST/theme.txt\""
set_var GRUB_GFXMODE "1920x1080,auto"
set_var GRUB_TERMINAL_OUTPUT "gfxterm"
echo "✓ $CFG actualizado (copia en $CFG.bak-*)"

# 4. Regenerar grub.cfg
grub-mkconfig -o /boot/grub/grub.cfg
echo "✓ Listo. Reinicia para verlo."
