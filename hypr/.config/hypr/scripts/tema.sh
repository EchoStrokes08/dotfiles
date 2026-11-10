#!/usr/bin/env bash
# Cambia los colores de TODO el escritorio (Hyprland, Quickshell, kitty, fuzzel, GTK, btop).
# Hay dos ajustes independientes:
#   MODO      de dónde salen los colores:  ayu (paleta fija)  |  wallpaper (matugen)
#   VARIANTE  claro u oscuro
#
#   tema.sh ayu | wallpaper     -> elige el modo            tema.sh alternar  -> cambia de modo
#   tema.sh claro | oscuro      -> elige la variante        tema.sh variante  -> cambia de variante
#   tema.sh auto on|off|estado  -> claro de día y oscuro de noche (horario en modulos/tema.lua)
#   tema.sh automatico <claro|oscuro>  -> lo llama Hyprland al llegar la hora (no a mano)
#   tema.sh aplicar [img]       -> vuelve a generar con lo actual (lo usa wallpaper.sh)
#   tema.sh estado              -> "ayu oscuro auto"
# Todos los programas leen la paleta activa de ~/.local/state/tema/

DIR="$HOME/.config/tema"
OUT="$HOME/.local/state/tema"
mkdir -p "$OUT"
modo=$(cat "$OUT/modo" 2>/dev/null || echo ayu)
variante=$(cat "$OUT/variante" 2>/dev/null || echo oscuro)
auto=$(cat "$OUT/auto" 2>/dev/null || echo on)

wallpaper_actual() {
    if [ -e "$OUT/wallpaper" ]; then readlink -f "$OUT/wallpaper"
    else awww query 2>/dev/null | sed -n 's/.*image: //p' | head -1; fi
}

generar() {
    if [ "$modo" = wallpaper ]; then
        img="${1:-$(wallpaper_actual)}"
        m=dark; [ "$variante" = claro ] && m=light
        # --prefer saturation: el color más saturado de la imagen (el más abundante suele ser el negro)
        if ! matugen -c "$DIR/matugen.toml" image "$img" -m "$m" --prefer saturation -q; then
            notify-send -a Tema "No se pudo generar la paleta" "Vuelvo a Ayu"; modo=ayu
        elif [ "$variante" = claro ]; then
            # la plantilla de kitty trae los 16 colores ANSI pensados para fondo oscuro: poner los claros
            { grep -v '^color[0-9]' "$OUT/kitty.conf"; grep '^color[0-9]' "$DIR/ayu-claro/kitty.conf"; } > "$OUT/kitty.conf.tmp" \
                && mv "$OUT/kitty.conf.tmp" "$OUT/kitty.conf"
        fi
    fi
    if [ "$modo" = ayu ]; then
        if [ "$variante" = claro ]; then cp "$DIR"/ayu-claro/* "$OUT"/; else cp "$DIR"/ayu/* "$OUT"/; fi
    fi
    echo "$modo" > "$OUT/modo"
    echo "$variante" > "$OUT/variante"
    # GTK y todo lo que pregunta "¿claro u oscuro?" por el portal (Firefox, apps libadwaita, webs)
    if [ "$variante" = claro ]; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-light
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3
    else
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
    fi
}

recargar() {
    hyprctl reload >/dev/null                 # bordes y sombras (colores.lua lee la paleta)
    pkill -SIGUSR2 -x waybar                  # waybar recarga config y estilo
    pkill -SIGUSR1 -x kitty                   # kitty recarga colores en todas sus ventanas
    pkill -RTMIN+9 -x waybar 2>/dev/null      # (refresca el mando de modo juego)
    qs ipc call barra refrescar todo >/dev/null 2>&1   # lo mismo en la barra de Quickshell
    # fuzzel lee el archivo al abrirse; las apps GTK3 ya abiertas cambian al abrir ventanas nuevas
}

avisar() {   # OSD de Quickshell; si qs no corre, notificación
    qs ipc call osd mensaje "$1" "$2" >/dev/null 2>&1 || notify-send -a Tema -u low "$1"
}

case "$1" in
    ayu|wallpaper) modo="$1"; generar; recargar; avisar "Colores: $modo" f03d8 ;;
    alternar)      [ "$modo" = ayu ] && modo=wallpaper || modo=ayu; generar; recargar
                   avisar "Colores: $modo" f03d8 ;;
    claro|oscuro|variante)
                   if [ "$1" = variante ]; then [ "$variante" = claro ] && variante=oscuro || variante=claro
                   else variante="$1"; fi
                   generar; recargar
                   [ "$variante" = claro ] && avisar "Tema claro" f05a8 || avisar "Tema oscuro" f0594 ;;
    automatico)    # llega la hora: se cambia solo si el horario automático está encendido
                   echo "$2" > "$OUT/ultimo_auto"          # se apunta siempre, para no reintentar cada minuto
                   [ "$auto" = on ] || exit 0
                   [ "$2" = "$variante" ] && exit 0
                   variante="$2"; generar; recargar
                   [ "$variante" = claro ] && avisar "Ya es de día: tema claro" f05a8 || avisar "Ya es de noche: tema oscuro" f0594 ;;
    auto)          case "$2" in
                       on)  echo on  > "$OUT/auto"; rm -f "$OUT/ultimo_auto"   # sin "último": se pone al día en el próximo minuto
                            avisar "Tema automático: claro de día, oscuro de noche" f0599 ;;
                       off) echo off > "$OUT/auto"; avisar "Tema automático apagado" f0599 ;;
                       *)   echo "$auto" ;;
                   esac ;;
    aplicar)       generar "$2"; recargar ;;
    estado)        echo "$modo $variante $([ "$auto" = on ] && echo auto || echo manual)" ;;
    modo)          echo "$modo" ;;
    *)             echo "uso: tema.sh ayu|wallpaper|alternar|claro|oscuro|variante|auto on/off|aplicar [imagen]|estado"; exit 1 ;;
esac
