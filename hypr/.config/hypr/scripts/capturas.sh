#!/usr/bin/env bash
# Menú de capturas con fuzzel. Cada captura se guarda en ~/Imágenes y se copia al portapapeles.
#   capturas.sh          -> menú
#   capturas.sh <modo>   -> directo: region | pantalla | ventana | temporizador

DESTINO="$HOME/Imágenes"
mkdir -p "$DESTINO"
archivo="$DESTINO/$(date +'%Y%m%d_%H%M%S')_captura.png"

guardar() {  # recibe la geometría de grim ("" = pantalla completa)
    if [ -n "$1" ]; then grim -g "$1" "$archivo"; else grim "$archivo"; fi || exit 1
    wl-copy < "$archivo"
    accion=$(notify-send -a Capturas -i "$archivo" -A abrir=Abrir -A carpeta="Ver carpeta" \
             "Captura guardada" "$(basename "$archivo") · copiada al portapapeles")
    case "$accion" in
        abrir)   xdg-open "$archivo" ;;
        carpeta) thunar "$DESTINO" ;;
    esac
}

modo="$1"
if [ -z "$modo" ]; then
    eleccion=$(printf '%s\n' \
        "󰩭  Región" \
        "󰹑  Pantalla completa" \
        "󱂬  Ventana activa" \
        "󰔛  Pantalla en 5 s" \
        | fuzzel --dmenu --prompt "󰄀  " --lines 4 --width 30)
    case "$eleccion" in
        *Región*)    modo=region ;;
        *completa*)  modo=pantalla ;;
        *Ventana*)   modo=ventana ;;
        *5\ s*)      modo=temporizador ;;
        *)           exit 0 ;;
    esac
    sleep 0.3  # que se cierre fuzzel antes de capturar
fi

case "$modo" in
    region)
        geo=$(slurp -b 0e141988 -c f19618ff -w 2) || exit 0   # colores Ayu en la selección
        guardar "$geo" ;;
    pantalla)
        guardar "" ;;
    ventana)
        geo=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        guardar "$geo" ;;
    temporizador)
        notify-send -a Capturas -t 4000 "Captura en 5 segundos…"
        sleep 5; guardar "" ;;
esac
