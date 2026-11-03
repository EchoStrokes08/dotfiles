#!/usr/bin/env bash
# Selector de wallpapers con fuzzel (con miniaturas).
#   wallpaper.sh            -> abre el menú y aplica el elegido
#   wallpaper.sh aleatorio  -> pone uno al azar
# Las miniaturas se crean una vez con ffmpeg en ~/.cache/wallpapers-mini (fuzzel solo muestra PNG/SVG).
# Nota: hyprpaper sigue rotando la carpeta cada 10 min (hyprpaper.conf → timeout).

CARPETA="$HOME/Imágenes/wallpapers"
MINIS="$HOME/.cache/wallpapers-mini"
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
mkdir -p "$MINIS"

aplicar() {
    hyprctl hyprpaper wallpaper "$MONITOR, $1, cover" >/dev/null
    notify-send -a Wallpaper -i "$MINIS/$(basename "${1%.*}").png" "Wallpaper" "$(basename "$1")"
}

mapfile -t fondos < <(find "$CARPETA" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
[ ${#fondos[@]} -eq 0 ] && { notify-send -a Wallpaper "No hay imágenes en $CARPETA"; exit 1; }

if [ "$1" = aleatorio ]; then
    aplicar "${fondos[RANDOM % ${#fondos[@]}]}"; exit 0
fi

# Miniaturas que falten
for f in "${fondos[@]}"; do
    mini="$MINIS/$(basename "${f%.*}").png"
    [ -f "$mini" ] || ffmpeg -loglevel error -y -i "$f" -vf "scale=192:108:force_original_aspect_ratio=increase,crop=192:108" -frames:v 1 "$mini"
done

# Lista para fuzzel: "nombre\0icon\x1fruta-miniatura"
elegido=$(
    { printf 'Aleatorio\0icon\x1fmedia-playlist-shuffle\n'
      for f in "${fondos[@]}"; do
          n=$(basename "$f")
          printf '%s\0icon\x1f%s\n' "$n" "$MINIS/${n%.*}.png"
      done
    } | fuzzel --dmenu --prompt "󰸉  " --line-height 56 --lines 6 --width 46
)
[ -z "$elegido" ] && exit 0

if [ "$elegido" = "Aleatorio" ]; then
    "$0" aleatorio
else
    aplicar "$CARPETA/$elegido"
fi
