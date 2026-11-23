#!/usr/bin/env bash
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
g++ -fPIC -std=c++17 -O1 -Wall -Wextra "$dir/interaccion.cpp" -o "$tmp/prueba" $(pkg-config --cflags --libs Qt6Widgets Qt6Test)
QT_QPA_PLATFORMTHEME= "$tmp/prueba" "$@"
