#!/usr/bin/env bash
# gestos.sh: que Quickshell vea los gestos del touchpad mientras ocurren (Gestos.qml), para que el panorama
# y la cápsula de Brújula sigan al dedo.
#   1. libinput-tools   el lector de gestos (`libinput debug-events`)
#   2. Regla udev       acceso SOLO al touchpad (no al teclado), solo para la sesión activa (uaccess).
#                       Más seguro que meter al usuario en el grupo «input», que daría acceso a todo el
#                       teclado a cualquier programa.
# Uso (SIN sudo; lo pide él):  ~/dotfiles/instalar/gestos.sh [--simular]
# Idempotente. No hace falta reiniciar sesión: Quickshell lo detecta solo en unos segundos.
set -uo pipefail

SIMULAR=0; [ "${1:-}" = "--simular" ] && SIMULAR=1
B=$'\e[1m'; NAR=$'\e[38;2;241;150;24m'; VER=$'\e[38;2;184;204;82m'; ROJ=$'\e[38;2;255;51;51m'; R=$'\e[0m'
paso()  { printf '\n%s==> %s%s\n' "$NAR$B" "$*" "$R"; }
ok()    { printf '%s  ✓ %s%s\n' "$VER" "$*" "$R"; }
aviso() { printf '%s  ! %s%s\n' "$ROJ" "$*" "$R"; }
run() { if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s %s\n' "$B" "$R" "$*"; return 0; fi; "$@"; }

[ "$EUID" -ne 0 ] || { echo "Ejecútalo SIN sudo (lo pedirá cuando haga falta)."; exit 1; }
[ "$SIMULAR" = 1 ] || sudo -v || exit 1

paso "libinput-tools"
if command -v libinput >/dev/null; then ok "ya estaba"
else run sudo pacman -S --needed --noconfirm libinput-tools && ok "instalado"; fi

paso "Acceso al touchpad para tu sesión (solo el touchpad)"
REGLA=/etc/udev/rules.d/70-touchpad-gestos.rules
CONTENIDO='# Quickshell (Gestos.qml) lee los gestos del touchpad: acceso para la sesión activa, solo a este dispositivo.
ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"'
if [ "$(cat "$REGLA" 2>/dev/null)" = "$CONTENIDO" ]; then
    ok "$REGLA ya estaba"
else
    if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s escribir %s:\n' "$B" "$R" "$REGLA"; printf '%s\n' "$CONTENIDO" | sed 's/^/      /'
    else printf '%s\n' "$CONTENIDO" | sudo install -Dm644 /dev/stdin "$REGLA" && ok "escrito $REGLA"; fi
    run sudo udevadm control --reload
    run sudo udevadm trigger --subsystem-match=input --action=change
fi

paso "Comprobación"
[ "$SIMULAR" = 1 ] && exit 0
sleep 1
for e in /sys/class/input/event*; do
    if grep -qi touchpad "$e/device/name" 2>/dev/null; then
        dev="/dev/input/$(basename "$e")"
        if [ -r "$dev" ]; then ok "$(cat "$e/device/name") ($dev) legible para ti"
        else aviso "$dev aún no es legible: cierra sesión y vuelve a entrar"; fi
    fi
done
