#!/usr/bin/env bash
# Inactividad según la alimentación: reinicia hypridle con la configuración que toca.
#   inactividad.sh            → mira si hay cargador (auto)
#   inactividad.sh bateria    → ~/.config/hypr/hypridle-bateria.conf (bloquea a los 5 min)
#   inactividad.sh red        → ~/.config/hypr/hypridle.conf (bloquea a los 10 min)
# Lo llaman el inicio de sesión (modulos/autostart.lua) y Cargador.qml al enchufar o desenchufar.
modo="${1:-auto}"
if [ "$modo" = auto ]; then
    if grep -qs '^1$' /sys/class/power_supply/A{DP,C}*/online; then modo=red; else modo=bateria; fi
fi
conf="$HOME/.config/hypr/hypridle.conf"
[ "$modo" = bateria ] && conf="$HOME/.config/hypr/hypridle-bateria.conf"

pkill -x hypridle
for _ in $(seq 20); do pgrep -x hypridle >/dev/null || break; sleep 0.1; done
setsid -f hypridle -c "$conf" >/dev/null 2>&1
echo "$modo"
