#!/usr/bin/env bash
# Botones del centro de control (Quickshell, CentroControl.qml).
#   conmutadores.sh <cosa> estado   -> imprime on / off
#   conmutadores.sh <cosa> on|off   -> lo enciende / apaga
#   conmutadores.sh todos           -> "wifi on" "bluetooth off"… (una línea por cosa, para leerlos de una vez)
# <cosa>: wifi | bluetooth | replay | rendimiento | conservacion | luz
#   conservacion: modo conservación de Lenovo (la batería para en ~80 %; off = carga al 100 %)
#   luz: luz nocturna (hyprsunset)
# (Antes vivía en ~/.config/swaync/scripts/toggle.sh)

CONSERV=$(echo /sys/bus/platform/drivers/ideapad_acpi/*/conservation_mode)   # escribible por wheel (tmpfiles)

estado() {
    case "$1" in
        wifi)        [ "$(nmcli radio wifi)" = enabled ] ;;
        bluetooth)   bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' ;;
        replay)      [ "$(~/.config/hypr/scripts/replay.sh estado)" = grabando ] ;;
        rendimiento) [ "$(powerprofilesctl get)" = performance ] ;;
        conservacion) [ "$(cat "$CONSERV" 2>/dev/null)" = 1 ] ;;
        luz)         t=$(hyprctl hyprsunset temperature 2>/dev/null | tr -dc '0-9'); [ -n "$t" ] && [ "$t" -lt 6000 ] ;;
        *)           return 2 ;;
    esac && echo on || echo off
}

cambiar() {   # cambiar <cosa> on|off
    case "$1" in
        wifi)        nmcli radio wifi "$2" ;;
        bluetooth)   bluetoothctl power "$2" >/dev/null ;;
        replay)      [ "$(estado replay)" != "$2" ] && ~/.config/hypr/scripts/replay.sh toggle ;;
        rendimiento) [ "$2" = on ] && powerprofilesctl set performance || powerprofilesctl set balanced ;;
        conservacion) [ "$2" = on ] && echo 1 > "$CONSERV" || echo 0 > "$CONSERV"
                     [ "$2" = on ] && qs ipc call osd mensaje 'Batería: carga hasta ~80 % (la cuida)' f0079 \
                                 || qs ipc call osd mensaje 'Batería: carga al 100 %' f0085 ;;
        luz)         ~/.config/hypr/scripts/luz-nocturna.sh "$2" ;;
    esac
}

case "$1" in
    todos) for c in wifi bluetooth replay rendimiento conservacion luz; do echo "$c $(estado $c)"; done ;;
    *)     if [ "$2" = estado ]; then estado "$1"; else cambiar "$1" "$2"; fi ;;
esac
