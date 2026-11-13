#!/usr/bin/env bash
# Estado explícito del coordinador; un perfil sin animaciones no equivale a modo juego.
estado="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr-escritorio-${HYPRLAND_INSTANCE_SIGNATURE:-}.state"
if rg -q '^juego_activo=true$' "$estado" 2>/dev/null; then
    echo '{"text":"󰊗","class":"activo","tooltip":"Modo juego ACTIVO · clic para desactivar"}'
else
    echo '{"text":"󰊗","class":"inactivo","tooltip":"Modo juego apagado · clic para activar (o SUPER+SHIFT+G)"}'
fi
