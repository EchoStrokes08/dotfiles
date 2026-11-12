#!/usr/bin/env bash
# sistema-base.sh: lo que le faltaba al SO debajo de Hyprland.
#   1. Paquetes   archivos (USB, celular, miniaturas, zip), visores, llavero, mantenimiento
#   2. zram       swap comprimida en RAM (no tenías nada de swap)
#   3. Firewall   ufw: bloquea conexiones entrantes, deja salir todo
#   4. Snapshots  snapper (/ y /home) + snap-pac + grub-btrfs: volver atrás si algo se rompe
#   5. Limpieza   paccache semanal, quitar tlp (choca con power-profiles-daemon)
#   6. Apps por defecto  imágenes→imv, PDF→zathura, video→mpv
#   7. Hub USB    no dejar que se duerma el hub del teclado+ratón (se desconectaba solo)
#   8. earlyoom   si se acaba la RAM, cierra UNA app (pestañas/apps web primero) en vez de congelarse
#   9. Salud      aviso si el SSD falla (smartd), firmware semanal (fwupd), caché de pacman: 1 versión
#  10. Arranque  GRUB sin menú (1 s; Esc o Shift al encender lo muestra)
#  11. Batería   el botón «Conservar» del centro de control puede cambiar el modo conservación de Lenovo
#  12. DNS       cifrado (DNS-over-TLS, Quad9 + Cloudflare); `dns-cifrado off` para Wi-Fi con portal
#  13. Mirrors   reflector: servidores de paquetes rápidos cerca de Colombia (antes salía uno de Suecia)
#  14. KDE Connect  puertos 1714-1764 abiertos SOLO para la red local (el móvil)
#  17. Hibernación  swapfile de 16 GB en el subvolumen @swap (zram no sirve para hibernar)
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
# /home también: si borras o rompes algo tuyo, `snapper -c home list` y copias el archivo de
# /home/.snapshots/N/snapshot/... Retención corta (6 horas, 7 días, 2 semanas): /home cambia mucho.
if [ -f /etc/snapper/configs/home ]; then
    ok "snapper de /home ya configurado"
elif findmnt -no FSTYPE /home | grep -q btrfs; then
    run sudo snapper -c home create-config /home && run sudo snapper -c home set-config \
        TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=6 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=2 \
        TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 NUMBER_LIMIT=10 ALLOW_USERS="$USER" SYNC_ACL=yes \
        && ok "snapper configurado para /home"
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

# ── 8. earlyoom ─────────────────────────────────────────────────────────
# Sin esto, al llenarse RAM + zram el equipo se congela minutos. systemd-oomd NO sirve aquí: mata
# cgroups enteros, y Firefox/kitty/Quickshell comparten el de la sesión de Hyprland (cerraría todo).
# Comillas: systemd parte la línea por espacios y no las entiende → regex sin comillas ni espacios.
paso "earlyoom (sin congelarse si se acaba la RAM)"
run sudo pacman -S --needed --noconfirm earlyoom systembus-notify >/dev/null && ok "earlyoom + systembus-notify"
escribir /etc/default/earlyoom <<'CONF'
# earlyoom: si la RAM y la swap (zram) se acaban, cierra UN proceso antes de que el equipo se congele.
# (systemd-oomd no sirve aquí: mata grupos enteros y tus apps comparten grupo con Hyprland.)
#   -m 5 -s 10   actuar cuando quede <5 % de RAM libre Y <10 % de swap libre
#   -n           avisar con una notificación (necesita systembus-notify en la sesión: autostart.lua)
#   --avoid      nunca estos (la sesión entera depende de ellos)
#   --prefer     primero estos (pestañas del navegador y apps web: se recargan sin perder nada)
# OJO: systemd parte esta línea por espacios y NO entiende comillas → expresiones sin comillas ni espacios
# (por eso "Isolated Web Co" se escribe Isolated.Web.Co). Gestionado desde ~/dotfiles/instalar/sistema-base.sh
EARLYOOM_ARGS="-m 5 -s 10 -r 3600 -n --avoid (^|/)(init|systemd|sddm|Hyprland|Xwayland|qs|kitty|zsh|pipewire|pipewire-pulse|wireplumber|hypridle|dbus-daemon|dbus-broker)$ --prefer (^|/)(Isolated.Web.Co|Web.Content|QtWebEngineProc|electron|code-oss|vesktop|zapzap|java)$"
CONF
run sudo systemctl enable --quiet earlyoom && run sudo systemctl restart earlyoom && ok "earlyoom activo"

# ── 9. Salud del equipo ─────────────────────────────────────────────────
paso "Salud: SSD, firmware y caché"
run sudo pacman -S --needed --noconfirm smartmontools >/dev/null && ok "smartmontools"
escribir /usr/local/bin/aviso-disco <<'AVISO'
#!/bin/sh
# Lo llama smartd (-M exec) cuando el SSD da un aviso: lo pasa a las notificaciones del escritorio
# (systembus-notify). smartd pone el texto en $SMARTD_MESSAGE. Gestionado desde ~/dotfiles/instalar/sistema-base.sh
dbus-send --system / net.nuetzlich.SystemNotifications.Notify \
    "string:⚠ Disco: ${SMARTD_FAILTYPE:-aviso}" "string:${SMARTD_MESSAGE:-smartd detectó un problema} · haz una copia: respaldo ahora"
AVISO
run sudo chmod 755 /usr/local/bin/aviso-disco
DISCO=$(lsblk -dno NAME,TYPE | awk '$2=="disk" && $1 ~ /^nvme/ {print "/dev/"$1; exit}')
[ -f /etc/smartd.conf.original ] || run sudo cp /etc/smartd.conf /etc/smartd.conf.original
escribir /etc/smartd.conf <<SMART
# smartd: vigila la salud del SSD y avisa en el escritorio (/usr/local/bin/aviso-disco) si:
#   -a          cambia algo importante de SMART (errores, reserva de bloques, desgaste, aviso crítico)
#   -W 0,60,75  la temperatura pasa de 60 °C (anotado) o 75 °C (aviso)
# Original de Arch: /etc/smartd.conf.original. Gestionado desde ~/dotfiles/instalar/sistema-base.sh
${DISCO:-DEVICESCAN} -a -W 0,60,75 -m <nomailer> -M exec /usr/local/bin/aviso-disco
SMART
escribir /etc/systemd/system/paccache.service.d/una-version.conf <<'PACC'
# Cada semana: dejar solo la última versión de cada paquete (los snapshots de snapper ya permiten volver
# atrás) y borrar las de paquetes desinstalados. Gestionado desde ~/dotfiles/instalar/sistema-base.sh
[Service]
Environment=PACCACHE_ARGS=-k1
ExecStartPost=/usr/bin/paccache -ruk0
PACC
run sudo systemctl daemon-reload
run sudo systemctl enable --quiet --now smartd fwupd-refresh.timer && ok "smartd + fwupd-refresh.timer"

# ── 10. Arranque ────────────────────────────────────────────────────────
# GRUB esperaba 5 s con el menú. Oculto + 1 s: Esc o Shift al encender lo muestra (snapshots incluidos).
paso "Arranque rápido (GRUB)"
if grep -qE '^GRUB_TIMEOUT=1$' /etc/default/grub && grep -qE '^GRUB_TIMEOUT_STYLE=hidden$' /etc/default/grub; then
    ok "GRUB ya estaba en 1 s / oculto"
else
    run sudo sed -i -E 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/; s/^#?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    run sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 && ok "GRUB: 1 s, menú oculto"
fi

# ── 11. Modo conservación de la batería (Lenovo) ────────────────────────
paso "Batería: modo conservación sin sudo"
if ls /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode >/dev/null 2>&1; then
    escribir /etc/tmpfiles.d/conservacion-bateria.conf <<'TMPF'
# Modo conservación de Lenovo (la batería para de cargar en ~80 % para durar más años):
# dejar que el grupo wheel lo cambie sin sudo (botón «Conservar» del centro de control de Quickshell).
# Gestionado desde ~/dotfiles/instalar/sistema-base.sh
z /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode 0664 root wheel - -
TMPF
    run sudo systemd-tmpfiles --create /etc/tmpfiles.d/conservacion-bateria.conf && ok "conservation_mode escribible por wheel"
else
    ok "no es un Lenovo ideapad: nada que hacer"
fi

# ── 12. DNS cifrado ─────────────────────────────────────────────────────
paso "DNS cifrado (DNS-over-TLS)"
escribir /etc/systemd/resolved.conf.d/dns-cifrado.conf <<'DNS'
# DNS cifrado (DNS-over-TLS): ni el operador ni la red Wi-Fi ven qué páginas visitas.
#   Quad9 (bloquea dominios de malware/phishing) y Cloudflare de respaldo; IPv4 e IPv6.
#   Domains=~.  → usar ESTOS para todo, no los que da el router.
# Comprobar:  resolvectl status   (debe salir +DNSOverTLS)
# Si una Wi-Fi de hotel/aeropuerto no abre su página de acceso: dns-cifrado off  (y luego on)
# Gestionado desde ~/dotfiles/instalar/sistema-base.sh
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 1.1.1.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com
FallbackDNS=
Domains=~.
DNSOverTLS=yes
DNSSEC=no
DNS
escribir /etc/NetworkManager/conf.d/dns.conf <<'NMDNS'
# DNS cifrado: NetworkManager NO pasa a resolved el DNS del router/operador (iría sin cifrar);
# se usan solo los de /etc/systemd/resolved.conf.d/dns-cifrado.conf. Para Wi-Fi con portal: dns-cifrado off
[main]
dns=none
NMDNS
run sudo systemctl enable --quiet --now systemd-resolved
if [ "$SIMULAR" = 0 ] && [ "$(readlink /etc/resolv.conf)" != /run/systemd/resolve/stub-resolv.conf ]; then
    sudo cp /etc/resolv.conf /etc/resolv.conf.antes-dns-cifrado
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    sudo nmcli general reload conf
    if getent hosts archlinux.org >/dev/null; then ok "DNS cifrado activo"
    else aviso "el DNS no responde: vuelvo al anterior"; sudo rm -f /etc/NetworkManager/conf.d/dns.conf /etc/resolv.conf
         sudo cp /etc/resolv.conf.antes-dns-cifrado /etc/resolv.conf; sudo nmcli general reload conf; fi
else
    ok "resolv.conf ya apunta a systemd-resolved"
fi

# ── 13. Servidores de paquetes (reflector) ─────────────────────────────
paso "Mirrors cercanos (reflector)"
escribir /etc/xdg/reflector/reflector.conf <<'REFL'
# reflector: elige los servidores de paquetes (mirrors). Antes usaba "--latest 5 --sort age" (los más
# recién sincronizados del mundo) y salía uno de Suecia, lentísimo desde Colombia.
# Ahora: países cercanos, solo https, sincronizados en las últimas 12 h, ordenados por velocidad real.
# Lo ejecuta reflector.timer cada semana. Gestionado desde ~/dotfiles/instalar/sistema-base.sh
--save /etc/pacman.d/mirrorlist
--protocol https
--country Colombia,Ecuador,Brazil,Chile,"United States"
--age 12
--latest 15
--fastest 6
--sort rate
REFL
run sudo systemctl enable --quiet reflector.timer && ok "reflector.timer (semanal)"

# ── 14. KDE Connect (móvil) ─────────────────────────────────────────────
# Abre sus puertos solo desde direcciones de red local: nadie de internet puede llegar a ellos.
paso "KDE Connect: puertos para el móvil (solo red local)"
if sudo ufw status | grep -q '1714:1764'; then
    ok "ya estaban abiertos"
else
    for r in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do for p in tcp udp; do
        run sudo ufw allow from "$r" to any port 1714:1764 proto "$p" comment 'KDE Connect (solo red local)' >/dev/null
    done; done
    ok "puertos 1714-1764 abiertos para 192.168/16, 10/8 y 172.16/12"
fi

# ── 15. keyd (capas de teclado) ─────────────────────────────────────────
# DESACTIVADO (2026-11-10): no me convence Bloq Mayús como Esc. Para reactivarlo, descomenta este bloque.
# # Bloq Mayús = Esc (toque) / Ctrl (mantenida) / flechas en HJKL. Config: ~/dotfiles/keyd/default.conf
# paso "keyd: Bloq Mayús como Esc, Ctrl y flechas"
# DOT="$(cd "$(dirname "$0")/.." && pwd)"
# run sudo pacman -S --needed --noconfirm keyd >/dev/null
# if cmp -s "$DOT/keyd/default.conf" /etc/keyd/default.conf 2>/dev/null && systemctl is-enabled --quiet keyd 2>/dev/null; then
#     ok "ya estaba bien"
# else
#     run sudo install -Dm644 "$DOT/keyd/default.conf" /etc/keyd/default.conf
#     run sudo systemctl enable --now --quiet keyd
#     run sudo keyd reload
#     ok "keyd activo (emergencia: Retroceso+Esc+Enter)"
# fi

# ── 16. IA local, Syncthing y Tailscale ─────────────────────────────────
paso "Asistente local (ollama), Syncthing y Tailscale"
run sudo pacman -S --needed --noconfirm ollama syncthing tailscale >/dev/null
run sudo systemctl enable --now --quiet ollama tailscaled
run systemctl --user enable --now --quiet syncthing.service
MODELO=$(cat "$HOME/.config/ia/modelo" 2>/dev/null || echo gemma3:4b)
if ollama list 2>/dev/null | grep -q "^$MODELO"; then ok "modelo $MODELO ya descargado"
else run ollama pull "$MODELO" && ok "modelo $MODELO descargado"; fi
# Cortafuegos: Syncthing solo desde la red local; Tailscale solo por su interfaz (tus propios equipos)
if sudo ufw status | grep -q 22000; then
    ok "puertos de Syncthing ya abiertos"
else
    for r in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
        run sudo ufw allow from "$r" to any port 22000 comment 'Syncthing (solo red local)' >/dev/null
        run sudo ufw allow from "$r" to any port 21027 proto udp comment 'Syncthing descubrimiento (solo red local)' >/dev/null
    done
    run sudo ufw allow in on tailscale0 comment 'Tailscale (solo tus dispositivos)' >/dev/null
    ok "Syncthing (22000, 21027) desde la red local y Tailscale por tailscale0"
fi
echo "    Falta iniciar sesión tú:  sudo tailscale up --ssh   ·  Syncthing: http://127.0.0.1:8384"

# ── 17. Hibernación ─────────────────────────────────────────────────────
# zram no sirve para hibernar (vive en la RAM). Swapfile de 16 GB en su propio subvolumen @swap, para
# que los snapshots de / no lo incluyan. No hace falta resume= en GRUB: el initramfs usa el hook
# `systemd` y systemd anota dónde quedó la imagen en una variable EFI (HibernateLocation).
paso "Hibernación (swapfile en @swap)"
RAIZ=$(findmnt -no UUID /)
if [ "$(findmnt -no FSTYPE /)" != btrfs ]; then
    aviso "la raíz no es btrfs: hibernación sin configurar"
elif swapon --show=NAME --noheadings | grep -qx /swap/swapfile; then
    ok "swapfile ya activo"
else
    if ! grep -q '/@swap' /etc/fstab; then
        T=$(mktemp -d)
        run sudo mount -o subvolid=5 "UUID=$RAIZ" "$T"
        [ -d "$T/@swap" ] || run sudo btrfs subvolume create "$T/@swap" >/dev/null
        run sudo umount "$T"; rmdir "$T"
        run sudo mkdir -p /swap
        if [ "$SIMULAR" = 0 ]; then
            printf '\n# Hibernación: swapfile en su propio subvolumen (fuera de los snapshots). Prioridad baja: zram va primero.\nUUID=%s\t/swap\tbtrfs\trw,noatime,ssd,discard=async,space_cache=v2,subvol=/@swap\t0 0\n/swap/swapfile\tnone\tswap\tdefaults,pri=1\t0 0\n' "$RAIZ" \
                | sudo tee -a /etc/fstab >/dev/null
        fi
        run sudo systemctl daemon-reload
    fi
    findmnt /swap >/dev/null || run sudo mount /swap
    [ -f /swap/swapfile ] || run sudo btrfs filesystem mkswapfile --size 16g --uuid clear /swap/swapfile >/dev/null
    run sudo swapon -p 1 /swap/swapfile && ok "swapfile de 16 GB activo (probar: systemctl hibernate)"
fi
# Para «suspender y, a las 2 h, hibernar» (systemctl suspend-then-hibernate)
escribir /etc/systemd/sleep.conf.d/hibernar.conf <<'EOT'
[Sleep]
HibernateDelaySec=2h
EOT

paso "Listo"
echo "  Comprueba:"
echo "    swapon --show          → /dev/zram0 y /swap/swapfile"
echo "    sudo ufw status        → Status: active"
echo "    snapper list           → tu primer snapshot"
echo "    fwupdmgr refresh && fwupdmgr get-updates   → firmware disponible"
echo "  Luego: ~/dotfiles/instalar/actualizar-listas.sh  (añade los paquetes nuevos a la lista)"
