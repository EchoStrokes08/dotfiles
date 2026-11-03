#!/usr/bin/env bash
# Inspector de ventanas (SUPER+I): muestra lo que necesitas para escribir una window rule
# y copia la class al portapapeles. Es hyprctl activewindow -j + jq.
info=$(hyprctl activewindow -j)
[ "$info" = "{}" ] && { notify-send -a Inspector "No hay ventana activa"; exit 0; }
clase=$(jq -r .class <<<"$info")
printf '%s' "$clase" | wl-copy
notify-send -a Inspector -t 10000 "󰈈  $clase  (copiada)" "$(jq -r '
  "título:    \(.title[0:60])\n" +
  "workspace: \(.workspace.name)   flotante: \(.floating)   xwayland: \(.xwayland)\n" +
  "tamaño:    \(.size[0])×\(.size[1]) en \(.at[0]),\(.at[1])\n" +
  "pid:       \(.pid)"' <<<"$info")"
