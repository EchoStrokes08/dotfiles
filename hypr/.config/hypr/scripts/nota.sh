#!/usr/bin/env bash
# Notas rápidas: añade una línea con fecha y hora al final de ~/Documents/notas.md
# (el mismo archivo del scratchpad SUPER+CTRL+SHIFT+O).
#   nota.sh "comprar cable HDMI"   -> la guarda          (SUPER+SHIFT+O abre el cuadro para escribirla)
#   nota.sh seleccion              -> guarda el texto que tengas seleccionado (SUPER+ALT+O)
#   En el lanzador:  nota comprar cable HDMI
NOTAS="$HOME/Documents/notas.md"
mkdir -p "$(dirname "$NOTAS")"
if [ "$1" = seleccion ]; then
    texto=$(wl-paste -p -n 2>/dev/null); [ -z "$texto" ] && texto=$(wl-paste -n 2>/dev/null)
else
    texto="$*"
fi
texto=$(printf '%s' "$texto" | sed 's/[[:space:]]*$//')
[ -z "$texto" ] && { qs ipc call osd mensaje "Nada que anotar" f039a >/dev/null 2>&1; exit 1; }
[ -s "$NOTAS" ] && [ -n "$(tail -c1 "$NOTAS")" ] && echo >> "$NOTAS"      # que el archivo termine en salto de línea
if [ "$(printf '%s\n' "$texto" | wc -l)" -gt 1 ]; then    # varias líneas: como cita debajo de la fecha
    { printf -- '- %s ·\n' "$(date '+%Y-%m-%d %H:%M')"; printf '%s\n' "$texto" | sed 's/^/  > /'; } >> "$NOTAS"
else
    printf -- '- %s · %s\n' "$(date '+%Y-%m-%d %H:%M')" "$texto" >> "$NOTAS"
fi
qs ipc call osd mensaje "Anotado" f039a >/dev/null 2>&1 || notify-send -a Notas -u low "Anotado" "$texto"
