#!/usr/bin/env bash
# Cambia los colores de TODO el escritorio (Hyprland, waybar, swaync, kitty, fuzzel, GTK).
#   tema.sh ayu         -> paleta Ayu fija (la de siempre)
#   tema.sh wallpaper   -> colores sacados del wallpaper actual (matugen)
#   tema.sh alternar    -> cambia entre los dos
#   tema.sh aplicar [img] -> vuelve a generar en el modo actual (lo usa wallpaper.sh)
#   tema.sh estado      -> dice el modo actual
# Todos los programas leen la paleta activa de ~/.local/state/tema/

DIR="$HOME/.config/tema"
OUT="$HOME/.local/state/tema"
mkdir -p "$OUT"
modo=$(cat "$OUT/modo" 2>/dev/null || echo ayu)

wallpaper_actual() {
    if [ -e "$OUT/wallpaper" ]; then readlink -f "$OUT/wallpaper"
    else hyprctl hyprpaper listactive | head -1 | cut -d' ' -f2-; fi
}

generar() {
    if [ "$modo" = wallpaper ]; then
        img="${1:-$(wallpaper_actual)}"
        # --prefer saturation: el color más saturado de la imagen (el más abundante suele ser el negro)
        if ! matugen -c "$DIR/matugen.toml" image "$img" -m dark --prefer saturation -q; then
            notify-send -a Tema "No se pudo generar la paleta" "Vuelvo a Ayu"; modo=ayu
        fi
    fi
    [ "$modo" = ayu ] && cp "$DIR"/ayu/* "$OUT"/
    echo "$modo" > "$OUT/modo"
}

recargar() {
    hyprctl reload >/dev/null                 # bordes y sombras (colores.lua lee la paleta)
    swaync-client -rs >/dev/null 2>&1         # CSS de notificaciones
    pkill -SIGUSR2 -x waybar                  # waybar recarga config y estilo
    pkill -SIGUSR1 -x kitty                   # kitty recarga colores en todas sus ventanas
    pkill -RTMIN+9 -x waybar 2>/dev/null      # (refresca el mando de modo juego)
    qs ipc call barra refrescar todo >/dev/null 2>&1   # lo mismo en la barra de Quickshell
    # swayosd no recarga el CSS en vivo: se reinicia (setsid = que no muera con este script)
    pkill -x swayosd-server; setsid -f swayosd-server >/dev/null 2>&1
    # fuzzel lee el archivo al abrirse; las apps GTK, al abrir ventanas nuevas
}

case "$1" in
    ayu|wallpaper) modo="$1"; generar; recargar
                   notify-send -a Tema -u low "Colores: $modo" ;;
    alternar)      [ "$modo" = ayu ] && modo=wallpaper || modo=ayu; generar; recargar
                   notify-send -a Tema -u low "Colores: $modo" ;;
    aplicar)       generar "$2"; recargar ;;
    estado)        echo "$modo" ;;
    *)             echo "uso: tema.sh ayu|wallpaper|alternar|aplicar [imagen]|estado"; exit 1 ;;
esac
