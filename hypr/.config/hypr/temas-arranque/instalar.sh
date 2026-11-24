#!/usr/bin/env bash
# Instala los temas Ayu Dark Glass para SDDM (login) y GRUB (arranque)
set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "Ejecuta con sudo"; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd)"
stamp=$(date +%Y%m%d-%H%M%S)

echo "==> SDDM"
rm -rf /usr/share/sddm/themes/ayu-glass
cp -r "$DIR/sddm-ayu" /usr/share/sddm/themes/ayu-glass
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-tema.conf <<CONF
[Theme]
Current=ayu-glass
CONF
# Colores y fondo del tema activo: se copian al login al encender y al apagar
usuario="${SUDO_USER:-$(logname 2>/dev/null || true)}"
install -m 755 "$DIR/sincronizar-sddm.sh" /usr/local/bin/sincronizar-sddm.sh
install -m 644 "$DIR/sddm-tema@.service" /etc/systemd/system/sddm-tema@.service
systemctl daemon-reload
if [ -n "$usuario" ] && [ "$usuario" != root ]; then
  systemctl enable "sddm-tema@$usuario.service"
  /usr/local/bin/sincronizar-sddm.sh "$usuario"
fi

echo "==> GRUB"
rm -rf /boot/grub/themes/ayu
cp -r "$DIR/grub-ayu" /boot/grub/themes/ayu
cp /etc/default/grub /etc/default/grub.bak-$stamp
setkey() {   # setkey CLAVE VALOR  → reemplaza o añade la línea
  if grep -qE "^#?$1=" /etc/default/grub; then
    sed -i -E "s|^#?$1=.*|$1=$2|" /etc/default/grub
  else echo "$1=$2" >> /etc/default/grub; fi
}
setkey GRUB_THEME '"/boot/grub/themes/ayu/theme.txt"'
setkey GRUB_GFXMODE '1920x1080,auto'
setkey GRUB_TERMINAL_OUTPUT 'gfxterm'
grub-mkconfig -o /boot/grub/grub.cfg

echo "Listo. Copia de seguridad: /etc/default/grub.bak-$stamp"
