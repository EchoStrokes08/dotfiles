#!/usr/bin/env bash
# SALIDA DE EMERGENCIA si la pantalla de bloqueo de Quickshell se cuelga
# (pantalla de un solo color o "lockdead" que no deja escribir la contraseña).
#
#   1. Ctrl+Alt+F3            → otra terminal (TTY3); entra con tu usuario y contraseña
#   2. ~/.config/hypr/scripts/desbloqueo-emergencia.sh
#   3. Ctrl+Alt+F1            → vuelves a Hyprland: ahora verás hyprlock; escribe tu contraseña
#
# Funciona porque misc.allow_session_lock_restore = true (modulos/sistema.lua): Hyprland deja que
# otro bloqueador (hyprlock) tome el relevo del que murió, sin cerrar tu sesión.
# Además reinicia Quickshell para que la barra y el resto vuelvan.

# Las variables de la sesión gráfica no existen en una TTY: se buscan a mano
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export HYPRLAND_INSTANCE_SIGNATURE="$(ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1)"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

echo "Instancia de Hyprland: $HYPRLAND_INSTANCE_SIGNATURE"
pkill -x qs                                   # el Quickshell colgado (si sigue vivo)
sleep 0.5
hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")' && echo "hyprlock lanzado: vuelve con Ctrl+Alt+F1"
hyprctl dispatch 'hl.dsp.exec_cmd("qs")'      >/dev/null && echo "Quickshell relanzado"
