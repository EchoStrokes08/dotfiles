#!/usr/bin/env bash
# Botones del centro de control (Quickshell, CentroControl.qml).
#   conmutadores.sh <cosa> estado   -> imprime on / off
#   conmutadores.sh <cosa> on|off   -> lo enciende / apaga
#   conmutadores.sh todos           -> "wifi on" "bluetooth off"… (una línea por cosa, para leerlos de una vez)
# <cosa>: wifi | bluetooth | replay | rendimiento
# (Antes vivía en ~/.config/swaync/scripts/toggle.sh)

estado() {
    case "$1" in
        wifi)        [ "$(nmcli radio wifi)" = enabled ] ;;
        bluetooth)   bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' ;;
        replay)      pgrep -f '^gpu-screen-recorder' >/dev/null ;;
        rendimiento) [ "$(powerprofilesctl get)" = performance ] ;;
        *)           return 2 ;;
    esac && echo on || echo off
}

cambiar() {   # cambiar <cosa> on|off
    case "$1" in
        wifi)        nmcli radio wifi "$2" ;;
        bluetooth)   bluetoothctl power "$2" >/dev/null ;;
        replay)      [ "$(estado replay)" != "$2" ] && ~/.config/hypr/scripts/replay.sh toggle ;;
        rendimiento) [ "$2" = on ] && powerprofilesctl set performance || powerprofilesctl set balanced ;;
    esac
}

case "$1" in
    todos) for c in wifi bluetooth replay rendimiento; do echo "$c $(estado $c)"; done ;;
    *)     if [ "$2" = estado ]; then estado "$1"; else cambiar "$1" "$2"; fi ;;
esac
