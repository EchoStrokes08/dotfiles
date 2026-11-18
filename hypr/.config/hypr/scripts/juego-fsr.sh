#!/usr/bin/env bash
# Envoltorio para las opciones de lanzamiento de Steam:
#     /home/oscar/.config/hypr/scripts/juego-fsr.sh %command%
# Con gamescope, el juego se dibuja a 1280×720 y se reescala con FSR a la pantalla (menos trabajo para la
# gráfica, imagen nítida). Sin gamescope instalado, se lanza normal. Siempre con gamemode.
# Más FPS (más borroso):  FSR_RES=960x540 /home/oscar/.config/hypr/scripts/juego-fsr.sh %command%
# Resolución original (sin reescalado): FSR_RES=native .../juego-fsr.sh %command%
set -uo pipefail
res="${FSR_RES:-1280x720}"
fps="${FSR_FPS:-0}"
if (( $# == 0 )); then
    echo "Uso: $0 ejecutable [argumentos…]" >&2
    exit 2
fi
if [[ "$res" == native ]]; then exec gamemoderun "$@"; fi
if [[ ! "$res" =~ ^[1-9][0-9]{1,4}x[1-9][0-9]{1,4}$ ]]; then
    echo "FSR_RES debe ser native o una resolución como 1280x720" >&2
    exit 2
fi
if [[ ! "$fps" =~ ^[0-9]{1,4}$ ]]; then
    echo "FSR_FPS debe ser un entero entre 0 y 9999 (0 = sin límite)" >&2
    exit 2
fi
if command -v gamescope >/dev/null; then
    read -r W H < <(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
m = [x for x in json.load(sys.stdin) if x["focused"]][0]
assert int(m["width"]) > 0 and int(m["height"]) > 0
print(int(m["width"]), int(m["height"]))' 2>/dev/null || echo "1920 1080")
    limite=()
    if (( 10#$fps > 0 )); then limite=(-r "$fps"); fi
    exec gamescope -w "${res%x*}" -h "${res#*x}" -W "${W:-1920}" -H "${H:-1080}" "${limite[@]}" \
        -F fsr -f -- gamemoderun "$@"
fi
echo "FSR no disponible: falta Gamescope. Se abre el juego sin reescalado, con GameMode." >&2
exec gamemoderun "$@"
