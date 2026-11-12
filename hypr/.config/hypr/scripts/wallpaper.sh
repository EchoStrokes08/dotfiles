#!/usr/bin/env bash
# Wallpapers.
#   wallpaper.sh               -> abre el selector de Quickshell (Wallpapers.qml); si qs no responde, el menú de fuzzel
#   wallpaper.sh aleatorio     -> pone uno al azar
#   wallpaper.sh poner <ruta>  -> pone ese (lo usa el selector de Quickshell)
#   wallpaper.sh restaurar     -> al iniciar sesión: vuelve a poner el último elegido (sin transición)
# El fondo lo pinta awww (awww-daemon): cambia con TRANSICIÓN. A mano, el fondo nuevo crece desde el
# cursor; en la rotación automática entra con un barrido suave; con batería, un fundido corto.
# Si awww-daemon no corre, se usa hyprpaper (respaldo).
# Las miniaturas se crean una vez con ffmpeg en ~/.cache/wallpapers-mini (fuzzel solo muestra PNG/SVG).
# El wallpaper elegido queda enlazado en ~/.local/state/tema/wallpaper (se restaura al arrancar)
# y, si el modo de color es "wallpaper", se regeneran los colores (tema.sh).
# La rotación cada 17,5 min la hace Hyprland (modulos/tema.lua).

CARPETA="$HOME/Imágenes/wallpapers"
MINIS="$HOME/.cache/wallpapers-mini"
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
mkdir -p "$MINIS"

TEMA="$HOME/.config/hypr/scripts/tema.sh"

con_bateria() { grep -qs 0 /sys/class/power_supply/A{DP,C}*/online; }

pintar() {   # pintar <ruta> <estilo: cursor|barrido|nada>
    if ! pgrep -x awww-daemon >/dev/null; then
        hyprctl hyprpaper wallpaper "$MONITOR, $1, cover" >/dev/null; return
    fi
    local estilo="$2"
    [ "$estilo" != nada ] && con_bateria && estilo=fundido
    case "$estilo" in
        cursor)   # crece en círculo desde donde está el cursor (posición en % de la pantalla)
            local pos
            pos=$(hyprctl monitors -j | jq -r --argjson c "$(hyprctl cursorpos -j)" '.[] | select(.focused)
                  | "\((($c.x - .x) / (.width / .scale)) | if . < 0 then 0 elif . > 1 then 1 else . end),\((($c.y - .y) / (.height / .scale)) | if . < 0 then 0 elif . > 1 then 1 else . end)"')
            awww img "$1" --transition-type grow --transition-pos "${pos:-0.5,0.5}" --invert-y \
                 --transition-duration 0.9 --transition-fps 60 --transition-bezier .16,1,.3,1 ;;
        barrido)  awww img "$1" --transition-type wipe --transition-angle 30 --transition-duration 1.4 --transition-fps 60 ;;
        fundido)  awww img "$1" --transition-type fade --transition-duration 0.4 --transition-fps 30 ;;
        *)        awww img "$1" --transition-type none ;;
    esac
}

aplicar() {   # aplicar <ruta> [estilo]
    pintar "$1" "${2:-cursor}"
    mkdir -p "$HOME/.local/state/tema"; ln -sf "$1" "$HOME/.local/state/tema/wallpaper"
    [ "$("$TEMA" modo)" = wallpaper ] && "$TEMA" aplicar "$1"
    notify-send -a Wallpaper -i "$MINIS/$(basename "${1%.*}").png" "Wallpaper" "$(basename "$1")"
}

if [ "$1" = restaurar ]; then   # autostart: espera a que awww-daemon esté listo (máx. 5 s)
    for _ in $(seq 25); do awww query >/dev/null 2>&1 && break; sleep 0.2; done
    ultimo=$(readlink -f "$HOME/.local/state/tema/wallpaper" 2>/dev/null)
    [ -f "$ultimo" ] && pintar "$ultimo" nada
    exit 0
fi

mapfile -t fondos < <(find "$CARPETA/" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
[ ${#fondos[@]} -eq 0 ] && { notify-send -a Wallpaper "No hay imágenes en $CARPETA"; exit 1; }

if [ "$1" = aleatorio ]; then
    aplicar "${fondos[RANDOM % ${#fondos[@]}]}" barrido; exit 0
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
    { if [ "$("$TEMA" modo)" = wallpaper ]
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
