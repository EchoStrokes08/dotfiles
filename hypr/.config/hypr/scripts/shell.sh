#!/bin/sh
# Arranca Quickshell con la escala de interfaz elegida en «Más › Apariencia» (ORION 5.10).
#   shell.sh            arrancar (autostart.lua)
#   shell.sh reiniciar  cerrar la instancia actual y volver a abrirla con la escala guardada
# La escala vive en ~/.local/state/quickshell/preferencias.json («escala»: 1, 1.1 o 1.25).
PREF="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/preferencias.json"
escala=$(python3 -I -c 'import json,sys
try: v=float(json.load(open(sys.argv[1])).get("escala",1))
except Exception: v=1
print(v if v in (1,1.1,1.25) else 1)' "$PREF" 2>/dev/null) || escala=1
if [ "$1" = reiniciar ]; then
    pkill -x qs
    i=0; while pgrep -x qs >/dev/null && [ $i -lt 30 ]; do sleep 0.1; i=$((i+1)); done
fi
if [ "$escala" = 1.0 ] || [ "$escala" = 1 ]; then unset QT_SCALE_FACTOR; else export QT_SCALE_FACTOR="$escala"; fi
exec setsid -f qs
