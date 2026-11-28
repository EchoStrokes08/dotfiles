#!/usr/bin/env bash
# Cambia el modo de energía (ahorro → equilibrado → rendimiento → …) y avisa con una notificación.
# Waybar se entera solo (escucha a power-profiles-daemon por D-Bus).
actual=$(powerprofilesctl get)
case "$actual" in
    power-saver) siguiente=balanced ;;
    balanced)    siguiente=performance ;;
    *)           siguiente=power-saver ;;
esac
powerprofilesctl set "$siguiente"

case "$siguiente" in
    power-saver) nombre="Ahorro de energía"; icono=ahorro ;;
    balanced)    nombre="Equilibrado";       icono=equilibrado ;;
    performance) nombre="Rendimiento";       icono=rendimiento ;;
esac
# Iconos propios (velocímetro con la aguja según el modo) en ~/.config/hypr/iconos
icono="$HOME/.config/hypr/iconos/energia-$icono.svg"
notify-send -a "Energía" -i "$icono" -t 1500 -h string:x-canonical-private-synchronous:modo-energia "Modo de energía" "$nombre"
