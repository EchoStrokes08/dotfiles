#!/usr/bin/env bash
# CLI de colores: el motor prepara y publica una generación completa sin recargar Hyprland.
exec python3 -I "$(dirname "$(readlink -f "$0")")/tema.py" "$@"
