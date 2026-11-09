#!/usr/bin/env bash
# sistema-base.sh: lo que le faltaba al SO debajo de Hyprland.
#   1. Paquetes   archivos (USB, celular, miniaturas, zip), visores, llavero, mantenimiento
#   2. zram       swap comprimida en RAM (no tenías nada de swap)
#   3. Firewall   ufw: bloquea conexiones entrantes, deja salir todo
#   4. Snapshots  snapper + snap-pac + grub-btrfs: volver atrás si una actualización rompe algo
#   5. Limpieza   paccache semanal, quitar tlp (choca con power-profiles-daemon)
#   6. Apps por defecto  imágenes→imv, PDF→zathura, video→mpv
#   7. Hub USB    no dejar que se duerma el hub del teclado+ratón (se desconectaba solo)
#
# Uso (SIN sudo; lo pide él):  ~/dotfiles/instalar/sistema-base.sh [--simular]
# Idempotente: si algo ya está hecho, lo salta.
set -uo pipefail

SIMULAR=0; [ "${1:-}" = "--simular" ] && SIMULAR=1
B=$'\e[1m'; NAR=$'\e[38;2;241;150;24m'; VER=$'\e[38;2;184;204;82m'; ROJ=$'\e[38;2;255;51;51m'; R=$'\e[0m'
paso()  { printf '\n%s==> %s%s\n' "$NAR$B" "$*" "$R"; }
ok()    { printf '%s  ✓ %s%s\n' "$VER" "$*" "$R"; }
aviso() { printf '%s  ! %s%s\n' "$ROJ" "$*" "$R"; }
run() { if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s %s\n' "$B" "$R" "$*"; return 0; fi; "$@"; }
# Escribe un archivo de sistema (como root) solo si su contenido cambió
escribir() {  # escribir RUTA  (contenido por stdin)
    local tmp; tmp=$(mktemp); cat > "$tmp"
    if cmp -s "$tmp" "$1" 2>/dev/null; then ok "$1 ya estaba bien"; rm -f "$tmp"; return 0; fi
    if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s escribir %s:\n' "$B" "$R" "$1"; sed 's/^/      /' "$tmp"; rm -f "$tmp"; return 0; fi
    sudo install -Dm644 "$tmp" "$1" && rm -f "$tmp" && ok "escrito $1"
}

[ "$EUID" -ne 0 ] || { echo "Ejecútalo SIN sudo (lo pedirá cuando haga falta)."; exit 1; }
[ "$SIMULAR" = 1 ] || sudo -v || exit 1

# ── 1. Paquetes ─────────────────────────────────────────────────────────
paso "Paquetes"
PAQ=(
    # Snapshots: snapper los crea, snap-pac antes/después de cada pacman, grub-btrfs los pone en GRUB
    snapper snap-pac grub-btrfs inotify-tools
    ufw                                   # firewall sencillo
    gvfs gvfs-mtp                         # Thunar: papelera, montar USB con un clic, celular por cable
    tumbler ffmpegthumbnailer             # miniaturas de imágenes y videos en Thunar
    thunar-archive-plugin file-roller     # "Extraer aquí" / "Comprimir" en el clic derecho
    ntfs-3g exfatprogs                    # USBs y discos de Windows
    imv zathura zathura-pdf-mupdf mpv     # visor de imágenes, PDF y video (ligeros, de teclado)
    gnome-keyring                         # llavero: VS Code/Vesktop recuerdan tu sesión (SDDM lo desbloquea al entrar)
    pacman-contrib                        # paccache (limpiar caché), checkupdates, pactree
    fwupd                                 # firmware de BIOS/SSD
    tealdeer                              # `tldr comando`: ejemplos rápidos
)
# -Syu: actualizar la base de datos y el sistema A LA VEZ que instalas. Con -S solo, si tu base
# de datos es vieja, pide versiones que el mirror ya borró (error 404). En Arch nunca se mezcla.
# Sin --noconfirm a propósito: si pacman pregunta algo (un conflicto), lo decides tú.
if ! run sudo pacman -Syu --needed "${PAQ[@]}"; then
    aviso "pacman falló o lo cancelaste: me detengo aquí (no toco nada más)."
    exit 1
fi
ok "paquetes instalados"

# ── 2. zram ─────────────────────────────────────────────────────────────
# Un disco virtual en RAM, comprimido con zstd (~3:1). Cuando la RAM se llena, el kernel
# mueve ahí lo menos usado en vez de matar programas. Mucho más rápido que swap en disco.
paso "zram (swap comprimida)"
escribir /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
EOF
# Ajustes recomendados por la wiki de Arch cuando la swap es zram (no disco):
# swappiness alto = usar zram sin miedo; page-cluster 0 = no leer en bloques (no hay disco que optimizar)
escribir /etc/sysctl.d/99-vm-zram.conf <<'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
run sudo sysctl --system >/dev/null
run sudo systemctl daemon-reload
run sudo systemctl start systemd-zram-setup@zram0.service && ok "zram activa" || aviso "zram no arrancó"

# ── 3. Firewall ─────────────────────────────────────────────────────────
paso "Firewall (ufw)"
run sudo ufw default deny incoming  >/dev/null
run sudo ufw default allow outgoing >/dev/null
if systemctl is-enabled --quiet sshd 2>/dev/null; then
    run sudo ufw limit ssh >/dev/null && ok "ssh permitido (limitado contra fuerza bruta)"
fi
run sudo ufw --force enable >/dev/null
run sudo systemctl enable --quiet --now ufw.service && ok "ufw activo: nada entra, todo sale"

# ── 4. Snapshots ────────────────────────────────────────────────────────
# Tu disco ya tiene el subvolumen @snapshots montado en /.snapshots. snapper create-config
# quiere crear ESE directorio él mismo, así que: desmontar, dejar que snapper cree el suyo,
# borrar el suyo y volver a montar el tuyo (el de fstab). Es el método de la wiki de Arch.
paso "Snapshots (snapper)"
if [ "$SIMULAR" = 0 ] && ! command -v snapper >/dev/null; then
    aviso "snapper no está instalado: salto los snapshots"
elif [ -f /etc/snapper/configs/root ]; then
    ok "snapper ya configurado"
else
    if [ -n "$(ls -A /.snapshots 2>/dev/null)" ]; then
        aviso "/.snapshots no está vacío: no lo toco. Revísalo a mano."
    else
        # Si algo falla a medias, el "|| ..." vuelve a montar tu @snapshots y para
        restaurar() { sudo mkdir -p /.snapshots; sudo mount /.snapshots 2>/dev/null; aviso "snapper falló; /.snapshots restaurado"; exit 1; }
        run sudo umount /.snapshots                   || restaurar
        run sudo rmdir /.snapshots                    || restaurar
        run sudo snapper -c root create-config /      || restaurar
        run sudo btrfs subvolume delete /.snapshots   || restaurar
        run sudo mkdir /.snapshots                    || restaurar
        run sudo mount /.snapshots                    || restaurar   # vuelve a montar @snapshots desde fstab
        run sudo chmod 750 /.snapshots
        # Retención: pocos snapshots para no llenar el disco
        #   timeline: 5 por hora, 7 diarios; number (los de pacman): 10 pares
        #   ALLOW_USERS: puedes ver la lista sin sudo (`snapper list`)
        run sudo snapper -c root set-config \
            TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=7 \
            TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 \
            NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 ALLOW_USERS="$USER" SYNC_ACL=yes
        ok "snapper configurado para /"
    fi
fi
run sudo systemctl enable --quiet --now snapper-timeline.timer snapper-cleanup.timer && ok "timers de snapper"
run sudo systemctl enable --quiet --now grub-btrfsd.service && ok "grub-btrfsd: añade cada snapshot al menú de GRUB"
run sudo snapper -c root create -d "sistema-base: primer snapshot" --cleanup-algorithm number && ok "primer snapshot creado"
run sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 && ok "GRUB regenerado (submenú 'Arch Linux snapshots')"

# ── 5. Limpieza y mantenimiento ─────────────────────────────────────────
paso "Mantenimiento"
run sudo systemctl enable --quiet --now paccache.timer && ok "paccache.timer: cada semana deja solo 3 versiones de cada paquete"
run sudo paccache -rq && ok "caché de pacman limpiada ahora"
if pacman -Qq tlp >/dev/null 2>&1; then
    # Ya usas power-profiles-daemon (lo cambia el módulo de la barra); tlp hace lo mismo y chocan
    run sudo pacman -Rns --noconfirm tlp $(pacman -Qq tlp-rdw 2>/dev/null) && ok "tlp quitado"
fi

# ── 6. Apps por defecto ─────────────────────────────────────────────────
paso "Apps por defecto"
d() { [ -f "/usr/share/applications/$1" ] && echo "$1"; }
ZATH=$(d org.pwmt.zathura-pdf-mupdf.desktop || d org.pwmt.zathura.desktop)
for m in image/png image/jpeg image/webp image/gif image/bmp image/avif image/svg+xml; do run xdg-mime default imv.desktop "$m"; done
[ -n "$ZATH" ] && run xdg-mime default "$ZATH" application/pdf
for m in video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo audio/mpeg audio/flac audio/ogg; do run xdg-mime default mpv.desktop "$m"; done
ok "imágenes→imv, PDF→zathura, video/audio→mpv"

# ── 7. Hub USB del teclado y ratón ──────────────────────────────────────
# El hub barato (214b:7250 "USB2.0 HUB") se desconectaba y reconectaba solo (error -71).
# El kernel duerme los hubs USB al instante (autosuspend 0 ms) y este hub no despierta bien.
# Esta regla lo mantiene siempre encendido. Si aun así falla: otro puerto o cable.
paso "Hub USB siempre encendido"
escribir /etc/udev/rules.d/50-hub-usb-sin-suspender.rules <<'REGLA'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="214b", ATTR{idProduct}=="7250", TEST=="power/control", ATTR{power/control}="on"
REGLA
run sudo udevadm control --reload && ok "reglas udev recargadas"
for d in /sys/bus/usb/devices/*; do
    [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = "214b:7250" ] || continue
    run sudo sh -c "echo on > $d/power/control" && ok "hub $(basename "$d"): encendido ya, sin reiniciar"
done

paso "Listo"
echo "  Comprueba:"
echo "    swapon --show          → /dev/zram0"
echo "    sudo ufw status        → Status: active"
echo "    snapper list           → tu primer snapshot"
echo "    fwupdmgr refresh && fwupdmgr get-updates   → firmware disponible"
echo "  Luego: ~/dotfiles/instalar/actualizar-listas.sh  (añade los paquetes nuevos a la lista)"
