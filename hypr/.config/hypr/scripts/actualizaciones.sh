#!/usr/bin/env bash
# Actualizaciones pendientes, para la barra (Actualizaciones.qml lo llama cada 3 h).
#   actualizaciones.sh          -> JSON { repos, aur, noticias, vulnerables, lista }
#   actualizaciones.sh instalar -> terminal con actualizar.py: comprobaciones, noticias, yay -Syu y revisión final
#   actualizaciones.sh deshacer -> terminal para devolver / a antes de la última actualización (snapper)
# checkupdates consulta los repos en una copia temporal: NO toca el sistema ni hace "pacman -Sy".
if [ "$1" = instalar ]; then
    # Con red de seguridad: batería, espacio, noticias, snapshot (snap-pac) y revisión al terminar
    exec kitty --class kitty-actualizar --title "Actualizando" -e "$HOME/.config/hypr/scripts/actualizar.py"
fi
if [ "$1" = deshacer ]; then
    exec kitty --class kitty-actualizar --title "Deshacer actualización" -e "$HOME/.config/hypr/scripts/actualizar.py" deshacer
fi
repos=$(checkupdates 2>/dev/null)
aur=$(yay -Qua 2>/dev/null)
n_repos=$(printf '%s' "$repos" | grep -c .)
n_aur=$(printf '%s' "$aur" | grep -c .)
noticias=$(informant list --unread 2>/dev/null | grep -c '^[0-9]')
vuln=$(arch-audit -u 2>/dev/null | grep -c .)
lista=$(printf '%s\n%s' "$repos" "$aur" | grep . | awk '{print $1}' | head -12 | paste -sd' ')
jq -cn --argjson r "$n_repos" --argjson a "$n_aur" --argjson n "${noticias:-0}" --argjson v "${vuln:-0}" --arg l "$lista" \
    '{repos:$r, aur:$a, noticias:$n, vulnerables:$v, lista:$l}'
