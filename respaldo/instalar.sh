#!/usr/bin/env bash
# Instala las copias de seguridad automáticas (restic → disco externo).
#   ~/dotfiles/respaldo/instalar.sh [UUID] [CARPETA]
# Por defecto: el disco "TOSHIBA EXT" (UUID 70C6C69DC6C66348) y la carpeta OSCAR/hyprland dentro de él.
# Para otro disco: lsblk -f  → copia su UUID y pásalo como primer argumento.
#
# Qué deja instalado:
#   /usr/local/bin/respaldo                    el script (respaldo ahora · estado · lista · montar · comprobar)
#   /etc/respaldo/{config,excluir,clave}       disco y carpeta · qué no copiar · CONTRASEÑA (solo root)
#   respaldo.service + respaldo.timer          revisa cada hora: copia si toca, si no hay disco recuerda
#   /etc/udev/rules.d/90-respaldo.rules        al conectar ese disco, copia sola
# Idempotente: si la contraseña ya existe, NO la cambia (las copias viejas dejarían de abrirse).
set -euo pipefail
[ "$EUID" -ne 0 ] || { echo "Ejecútalo SIN sudo (lo pide él)."; exit 1; }
DIR=$(cd "$(dirname "$0")" && pwd)
UUID=${1:-70C6C69DC6C66348}
CARPETA=${2:-OSCAR/hyprland}

sudo pacman -S --needed --noconfirm restic fuse3 jq ntfsprogs systembus-notify >/dev/null

sudo install -Dm755 "$DIR/respaldo.sh" /usr/local/bin/respaldo
sudo install -Dm644 "$DIR/excluir" /etc/respaldo/excluir
printf 'UUID=%s\nCARPETA=%s\nUSUARIO=%s\n' "$UUID" "$CARPETA" "$USER" | sudo install -Dm644 /dev/stdin /etc/respaldo/config
sudo install -Dm644 "$DIR/respaldo.service" /etc/systemd/system/respaldo.service
sudo install -Dm644 "$DIR/respaldo.timer"   /etc/systemd/system/respaldo.timer
# Al conectar el disco (por su UUID) → arrancar el servicio (él espera a que udiskie lo monte)
echo "ACTION==\"add\", SUBSYSTEM==\"block\", ENV{ID_FS_UUID}==\"$UUID\", TAG+=\"systemd\", ENV{SYSTEMD_WANTS}+=\"respaldo.service\"" \
    | sudo install -Dm644 /dev/stdin /etc/udev/rules.d/90-respaldo.rules

if ! sudo test -s /etc/respaldo/clave; then
    # (no "tr </dev/urandom | head": con pipefail, tr muere por SIGPIPE y aborta el script)
    clave=$(python3 -c 'import secrets,string; a=string.ascii_lowercase+string.digits; print("-".join("".join(secrets.choice(a) for _ in range(6)) for _ in range(4)))')
    printf '%s\n' "$clave" | sudo install -Dm600 /dev/stdin /etc/respaldo/clave
    echo
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  CONTRASEÑA DE LAS COPIAS:  $clave  │"
    echo "  │  Apúntala FUERA del portátil (móvil, papel). Sin ella, las  │"
    echo "  │  copias no se pueden abrir en otro equipo.                  │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo "  (verla otra vez: sudo cat /etc/respaldo/clave)"
    echo
fi

sudo udevadm control --reload
sudo systemctl daemon-reload
sudo systemctl enable --now respaldo.timer
echo "Listo. Primera copia: respaldo ahora   ·   estado: respaldo estado"
