#!/usr/bin/env bash
set -eu
umask 077
src=$(cd "$(dirname "$0")" && pwd)
dir="${XDG_CACHE_HOME:-$HOME/.cache}/orion-pizarra"
mkdir -p "$dir"
(
    flock -x 9
    if [[ ! -x "$dir/pizarra" || "$src/pizarra.cpp" -nt "$dir/pizarra" || "$0" -nt "$dir/pizarra" ]]; then
        tmp=$(mktemp "$dir/pizarra.XXXXXXXX")
        trap 'rm -f "$tmp"' EXIT
        g++ -fPIC -std=c++17 -O2 -Wall -Wextra "$src/pizarra.cpp" -o "$tmp" $(pkg-config --cflags --libs Qt6Widgets) || {
            notify-send -u critical Pizarra 'No se pudo preparar la interfaz Qt.' || true
            exit 1
        }
        mv -f "$tmp" "$dir/pizarra"
    fi
) 9>"$dir/build.lock"
if [[ ${1:-} == --compilar ]]; then exit 0; fi
exec "$dir/pizarra" "$src" "$@"
