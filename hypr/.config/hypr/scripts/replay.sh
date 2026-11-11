#!/usr/bin/env bash
# CLI compatible; solo gestiona el replay de esta sesión, nunca otras grabaciones.
script="$(dirname "$(readlink -f "$0")")/replay.py"
if [ "${1:-}" = toggle ]; then
    if salida=$(python3 "$script" "$@"); then
        timeout 2 qs ipc call osd mensaje "$salida" f044b >/dev/null 2>&1 || true
        printf '%s\n' "$salida"
    else
        timeout 2 notify-send -a Replay 'No se pudo cambiar el replay' >/dev/null 2>&1 || true
        exit 1
    fi
else
    exec python3 "$script" "$@"
fi
