#!/bin/sh
# Guarda el nivel real incluso cuando el usuario ya está por debajo del objetivo.
set -eu
actual=$(brightnessctl -c backlight get)
maximo=$(brightnessctl -c backlight max)
objetivo=$(( (maximo + 9) / 10 ))
if [ "$actual" -lt "$objetivo" ]; then objetivo=$actual; fi
exec brightnessctl -c backlight -s set "$objetivo"
