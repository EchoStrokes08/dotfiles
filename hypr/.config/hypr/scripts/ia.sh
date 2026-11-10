#!/usr/bin/env bash
# Asistente local sobre el texto SELECCIONADO (si no hay selección, lo último copiado).
#   ia.sh                  -> menú: resumir, corregir, mejorar, explicar, traducir, preguntar (SUPER+ALT+A)
#   ia.sh <accion>         -> directo:  resumir | corregir | mejorar | explicar | traducir
#   ia.sh preguntar [texto] -> abre el panel para preguntar (con la selección como contexto si la hay)
#   En el lanzador:  ia cómo se calcula una máscara de subred
# El texto se guarda en $XDG_RUNTIME_DIR/ia-entrada.txt (en RAM) y el panel (IA.qml) llama a ia.py.
ENTRADA="${XDG_RUNTIME_DIR:-/tmp}/ia-entrada.txt"
if [ -z "$1" ]; then exec qs ipc call menu ia; fi
if [ "$1" = preguntar ] && [ -n "$2" ]; then        # pregunta directa: sin contexto
    : > "$ENTRADA"
else
    sel=$(wl-paste -p -n 2>/dev/null); [ -z "$sel" ] && sel=$(wl-paste -n -t text 2>/dev/null)
    printf '%s' "$sel" > "$ENTRADA"
fi
accion=$1; shift
qs ipc call ia abrir "$accion" "$*"
