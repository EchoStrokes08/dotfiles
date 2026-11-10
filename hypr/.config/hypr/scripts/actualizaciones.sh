#!/usr/bin/env bash
# Actualizaciones pendientes, para la barra (Actualizaciones.qml lo llama cada 3 h).
#   actualizaciones.sh          -> JSON { repos, aur, noticias, vulnerables, lista }
#   actualizaciones.sh instalar -> abre una terminal con yay -Syu (si hay noticias de Arch sin leer, primero las muestra)
# checkupdates consulta los repos en una copia temporal: NO toca el sistema ni hace "pacman -Sy".
if [ "$1" = instalar ]; then
    exec kitty --class kitty-actualizar --title "Actualizando" -e sh -c '
        if command -v informant >/dev/null && ! informant check >/dev/null 2>&1; then
            echo "── Noticias de Arch sin leer (pueden pedir pasos manuales) ──"; informant read --all; echo
        fi
        yay -Syu; echo; qs ipc call actualizaciones refrescar >/dev/null 2>&1
        read -rp "Enter para cerrar " _'
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
