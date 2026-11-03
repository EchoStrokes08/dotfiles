#!/usr/bin/env bash
# Botones del panel de swaync.
#   toggle.sh <cosa> estado  -> imprime true/false (swaync lo usa para pintar el botón activo)
#   toggle.sh <cosa>         -> cambia el estado; swaync pasa el nuevo en $SWAYNC_TOGGLE_STATE
# <cosa>: wifi | bluetooth | replay | rendimiento

cosa="$1"; accion="$2"
nuevo="${SWAYNC_TOGGLE_STATE:-}"

case "$cosa" in
  wifi)
    if [ "$accion" = estado ]; then
      [ "$(nmcli radio wifi)" = enabled ] && echo true || echo false
    else
      [ "$nuevo" = true ] && nmcli radio wifi on || nmcli radio wifi off
    fi ;;
  bluetooth)
    if [ "$accion" = estado ]; then
      bluetoothctl show | grep -q 'Powered: yes' && echo true || echo false
    else
      [ "$nuevo" = true ] && bluetoothctl power on >/dev/null || bluetoothctl power off >/dev/null
    fi ;;
  replay)
    if [ "$accion" = estado ]; then
      pgrep -f '^gpu-screen-recorder' >/dev/null && echo true || echo false
    else
      ~/.config/hypr/scripts/replay.sh toggle
    fi ;;
  rendimiento)
    # activo = perfil "performance"; apagado = "balanced"
    if [ "$accion" = estado ]; then
      [ "$(powerprofilesctl get)" = performance ] && echo true || echo false
    else
      [ "$nuevo" = true ] && powerprofilesctl set performance || powerprofilesctl set balanced
      notify-send -a Energía "Perfil de energía" "$(powerprofilesctl get)"
    fi ;;
esac
