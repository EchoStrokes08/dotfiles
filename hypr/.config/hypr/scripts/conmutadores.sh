#!/usr/bin/env bash
# CLI compatible; «json» añade disponibilidad y errores para el centro de control.
exec python3 -I "$(dirname "$(readlink -f "$0")")/conmutadores.py" "$@"
