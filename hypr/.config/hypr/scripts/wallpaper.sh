#!/usr/bin/env bash
# Wallpapers.
#   wallpaper.sh               -> abre el selector de Quickshell (Wallpapers.qml); si qs no responde, el menú de fuzzel
#   wallpaper.sh aleatorio     -> pone uno al azar
#   wallpaper.sh poner <ruta>  -> pone ese (lo usa el selector de Quickshell)
# Las miniaturas se crean una vez con ffmpeg en ~/.cache/wallpapers-mini (fuzzel solo muestra PNG/SVG).
# El wallpaper elegido queda enlazado en ~/.local/state/tema/wallpaper (hyprpaper lo carga al arrancar)
# y, si el modo de color es "wallpaper", se regeneran los colores (tema.sh).
# La rotación cada 10 min la hace Hyprland (modulos/tema.lua), no hyprpaper.

CARPETA="$HOME/Imágenes/wallpapers"
MINIS="$HOME/.cache/wallpapers-mini"
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
mkdir -p "$MINIS"

TEMA="$HOME/.config/hypr/scripts/tema.sh"

aplicar() {
    hyprctl hyprpaper wallpaper "$MONITOR, $1, cover" >/dev/null
    mkdir -p "$HOME/.local/state/tema"; ln -sf "$1" "$HOME/.local/state/tema/wallpaper"
    [ "$("$TEMA" estado)" = wallpaper ] && "$TEMA" aplicar "$1"
    notify-send -a Wallpaper -i "$MINIS/$(basename "${1%.*}").png" "Wallpaper" "$(basename "$1")"
}

mapfile -t fondos < <(find "$CARPETA/" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
[ ${#fondos[@]} -eq 0 ] && { notify-send -a Wallpaper "No hay imágenes en $CARPETA"; exit 1; }

if [ "$1" = aleatorio ]; then
    aplicar "${fondos[RANDOM % ${#fondos[@]}]}"; exit 0
fi
if [ "$1" = poner ] && [ -f "$2" ]; then
    aplicar "$2"; exit 0
fi

# Selector de Quickshell; "qs ipc call" no imprime nada si funcionó
[ -z "$(qs ipc call wallpapers toggle 2>&1)" ] && exit 0

# --- Respaldo: menú de fuzzel ---

# Miniaturas que falten
for f in "${fondos[@]}"; do
    mini="$MINIS/$(basename "${f%.*}").png"
    [ -f "$mini" ] || ffmpeg -loglevel error -y -i "$f" -vf "scale=192:108:force_original_aspect_ratio=increase,crop=192:108" -frames:v 1 "$mini"
done

# Lista para fuzzel: "nombre\0icon\x1fruta-miniatura"
elegido=$(
    { if [ "$("$TEMA" estado)" = wallpaper ]
      then printf 'Colores: volver a Ayu\0icon\x1fpreferences-desktop-theme\n'
      else printf 'Colores: sacarlos del wallpaper\0icon\x1fpreferences-desktop-color\n'; fi
      printf 'Aleatorio\0icon\x1fmedia-playlist-shuffle\n'
      for f in "${fondos[@]}"; do
          n=$(basename "$f")
          printf '%s\0icon\x1f%s\n' "$n" "$MINIS/${n%.*}.png"
      done
    } | fuzzel --dmenu --prompt "󰸉  " --line-height 56 --lines 6 --width 46
)
[ -z "$elegido" ] && exit 0

if [[ "$elegido" == Colores:* ]]; then
    "$TEMA" alternar
elif [ "$elegido" = "Aleatorio" ]; then
    "$0" aleatorio
else
    aplicar "$CARPETA/$elegido"
fi
