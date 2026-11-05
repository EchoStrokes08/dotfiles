#!/usr/bin/env bash
# Instala swayosd (indicador de volumen/brillo) y Plymouth con el tema Ayu Glass.
# Uso:  sudo ~/.config/hypr/temas-arranque/instalar-plymouth-osd.sh
#
# Qué toca (con copia .bak-FECHA de cada archivo de /etc):
#   /etc/mkinitcpio.conf      → añade el hook "plymouth" justo después de "systemd"
#   /etc/default/grub         → añade "splash" a la línea del kernel
#   /etc/plymouth/plymouthd.conf → tema ayu-glass, sin retraso
# Deshacer: restaurar los .bak, sudo mkinitcpio -P, sudo grub-mkconfig -o /boot/grub/grub.cfg
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Ejecuta con sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
stamp=$(date +%Y%m%d-%H%M%S)

echo "==> Paquetes"
pacman -S --needed --noconfirm plymouth swayosd

echo "==> swayosd: backend de libinput (detecta Bloq Mayús y teclas especiales)"
systemctl enable --now swayosd-libinput-backend.service

echo "==> Tema de Plymouth"
rm -rf /usr/share/plymouth/themes/ayu-glass
cp -r "$DIR/plymouth-ayu" /usr/share/plymouth/themes/ayu-glass
mkdir -p /etc/plymouth
[ -f /etc/plymouth/plymouthd.conf ] && cp /etc/plymouth/plymouthd.conf /etc/plymouth/plymouthd.conf.bak-$stamp
cat > /etc/plymouth/plymouthd.conf <<CONF
[Daemon]
Theme=ayu-glass
ShowDelay=0
DeviceTimeout=8
CONF

echo "==> mkinitcpio: hook plymouth"
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak-$stamp
if ! grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then
  # Va después de systemd (necesita udev) y antes de block/filesystems
  sed -i -E '/^HOOKS=/ s/\bsystemd\b/systemd plymouth/' /etc/mkinitcpio.conf
fi
grep -E '^HOOKS=' /etc/mkinitcpio.conf

echo "==> GRUB: parámetro splash"
cp /etc/default/grub /etc/default/grub.bak-$stamp
if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*\bsplash\b' /etc/default/grub; then
  sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"/\1 splash"/' /etc/default/grub
fi
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Regenerar initramfs (mkinitcpio -P)"
mkinitcpio -P

echo
echo "Listo. Copias: *.bak-$stamp en /etc/mkinitcpio.conf, /etc/default/grub y /etc/plymouth/"
echo "Reinicia para ver Plymouth. Si algo va mal, en GRUB pulsa 'e' y borra 'splash' de la línea linux."
