#!/usr/bin/env bash
# Estado del modo juego para waybar (JSON). El modo juego está activo cuando las animaciones están apagadas.
if [ "$(hyprctl -j getoption animations:enabled | jq .bool)" = false ]; then
    echo '{"text":"󰊗","class":"activo","tooltip":"Modo juego ACTIVO · clic para desactivar"}'
else
    echo '{"text":"󰊗","class":"inactivo","tooltip":"Modo juego apagado · clic para activar (o SUPER+SHIFT+G)"}'
fi
