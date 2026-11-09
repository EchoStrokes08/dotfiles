#!/usr/bin/env bash
# Elige un color de cualquier punto de la pantalla y lo copia en hex (SUPER+SHIFT+C).
# hyprpicker congela la pantalla (-r) y muestra una lupa; clic = elegir, Esc = cancelar.
color=$(hyprpicker -a -r -f hex) || exit 0
[ -n "$color" ] && qs ipc call osd mensaje "$color copiado" f020a   # 󰈊 cuentagotas
