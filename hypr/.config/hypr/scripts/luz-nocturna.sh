#!/usr/bin/env bash
# Enciende/apaga la luz nocturna (hyprsunset) y avisa con el OSD de Quickshell.
# Uso: luz-nocturna.sh [toggle|on|off]      (SUPER+ALT+N = toggle)
CALIDA=4500
pgrep -x hyprsunset >/dev/null || { hyprsunset >/dev/null 2>&1 & disown; sleep 0.5; }

# Sin argumento, "hyprctl hyprsunset temperature" devuelve la temperatura actual
actual=$(hyprctl hyprsunset temperature 2>/dev/null | tr -dc '0-9')
case "${1:-toggle}" in
    on)  modo=on ;;
    off) modo=off ;;
    *)   if [ -n "$actual" ] && [ "$actual" -lt 6000 ]; then modo=off; else modo=on; fi ;;
esac

if [ "$modo" = on ]; then
    hyprctl hyprsunset temperature "$CALIDA" >/dev/null
    qs ipc call osd mensaje "Luz nocturna activada" f0594      # 󰖔 weather-night
else
    hyprctl hyprsunset identity >/dev/null
    qs ipc call osd mensaje "Luz nocturna desactivada" f05a8   # 󰖨 sol
fi
