#!/bin/sh
estado="$XDG_RUNTIME_DIR/hypr-escritorio-$HYPRLAND_INSTANCE_SIGNATURE.state"
if [ -r "$estado" ] && grep -qx 'perfil=lectura' "$estado"; then
    echo 'background_opacity 1.0'
else
    echo 'background_opacity 0.90'
fi
