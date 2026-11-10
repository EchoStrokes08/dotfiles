#!/usr/bin/env bash
# Capturas. Cada una se guarda en ~/Imágenes/screenshots y se copia al portapapeles.
#   capturas.sh          -> menú de Quickshell (Menu.qml); si qs no responde, el de fuzzel
#   capturas.sh <modo>   -> directo: region | pantalla | ventana | temporizador | anotar
#   capturas.sh editar <archivo>  -> abre una captura ya hecha en el editor
# Anotar (SUPER+SHIFT+A, o el botón "Anotar" de la notificación): abre satty para poner flechas,
# texto, recuadros, números, resaltar o difuminar. Ctrl+C copia, Ctrl+S guarda (…_anotada.png), Enter = copiar y salir.

DESTINO="$HOME/Imágenes/screenshots"
mkdir -p "$DESTINO"
archivo="$DESTINO/$(date +'%Y%m%d_%H%M%S')_captura.png"

editar() {   # abre el editor sobre una imagen; lo anotado se guarda al lado como …_anotada.png
    satty --filename "$1" --output-filename "${1%.png}_anotada.png"
}

guardar() {  # recibe la geometría de grim ("" = pantalla completa)
    if [ -n "$1" ]; then grim -g "$1" "$archivo"; else grim "$archivo"; fi || exit 1
    wl-copy < "$archivo"
    accion=$(notify-send -a Capturas -i "$archivo" -A anotar=Anotar -A abrir=Abrir -A carpeta="Ver carpeta" \
             "Captura guardada" "$(basename "$archivo") · copiada al portapapeles")
    case "$accion" in
        anotar)  editar "$archivo" ;;
        abrir)   xdg-open "$archivo" ;;
        carpeta) thunar "$DESTINO" ;;
    esac
}

modo="$1"
if [ -z "$modo" ] && [ -z "$(qs ipc call menu capturas 2>&1)" ]; then
    exit 0   # el menú de Quickshell llamará a "capturas.sh <modo>"
fi
if [ -z "$modo" ]; then   # respaldo: fuzzel
    eleccion=$(printf '%s\n' \
        "󰩭  Región" \
        "󰹑  Pantalla completa" \
        "󱂬  Ventana activa" \
        "󰔛  Pantalla en 5 s" \
        "󰏫  Región y anotar" \
        | fuzzel --dmenu --prompt "󰄀  " --lines 5 --width 30)
    case "$eleccion" in
        *Región*)    modo=region ;;
        *completa*)  modo=pantalla ;;
        *Ventana*)   modo=ventana ;;
        *5\ s*)      modo=temporizador ;;
        *anotar*)    modo=anotar ;;
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
    anotar)
        geo=$(slurp -b 0e141988 -c f19618ff -w 2) || exit 0
        grim -g "$geo" "$archivo" || exit 1
        editar "$archivo" ;;
    editar)
        [ -f "$2" ] && editar "$2" ;;
    temporizador)
        notify-send -a Capturas -t 4000 "Captura en 5 segundos…"
        sleep 5; guardar "" ;;
esac
