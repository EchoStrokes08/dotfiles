#!/usr/bin/env bash
# Replay buffer estilo ShadowPlay con gpu-screen-recorder.
# Graba continuamente en RAM los últimos $SEGUNDOS y solo escribe a disco cuando pides "save".
#   replay.sh start   -> arranca la grabación en segundo plano (lo hace el autostart)
#   replay.sh save    -> guarda los últimos 30 s en ~/Videos/Replays
#   replay.sh toggle  -> apaga/enciende el replay (útil si necesitas rendimiento)

SEGUNDOS=30
FPS=60
DESTINO="$HOME/Videos/Replays"
mkdir -p "$DESTINO"

corriendo() { pgrep -f "^gpu-screen-recorder" >/dev/null; }

case "$1" in
  start)
    corriendo && exit 0
    command -v gpu-screen-recorder >/dev/null || {
      notify-send -a Replay "Replay" "Falta instalar gpu-screen-recorder"; exit 1; }
    # -w: monitor a grabar (el primero que detecta, p. ej. eDP-1) · -r: segundos en buffer
    # -a: audio del sistema · -sc: script que se ejecuta tras guardar (recibe la ruta del video)
    MONITOR=$(gpu-screen-recorder --list-capture-options | head -1 | cut -d'|' -f1)
    setsid gpu-screen-recorder -w "$MONITOR" -f "$FPS" -c mp4 \
      -a default_output -r "$SEGUNDOS" -replay-storage ram \
      -o "$DESTINO" -sc "$0" >/dev/null 2>&1 &
    ;;
  save)
    if corriendo; then
      pkill -SIGUSR1 -f "^gpu-screen-recorder"
    else
      notify-send -a Replay "Replay apagado" "Actívalo con SUPER+ALT+PRINT"
    fi
    ;;
  toggle)
    if corriendo; then
      pkill -SIGINT -f "^gpu-screen-recorder"
      notify-send -a Replay "Replay apagado"
    else
      "$0" start && notify-send -a Replay "Replay encendido" "SUPER+SHIFT+PRINT guarda los últimos ${SEGUNDOS} s"
    fi
    ;;
  *)
    # Llamado por gpu-screen-recorder (-sc) con la ruta del video recién guardado
    [ -f "$1" ] && notify-send -a Replay "Replay guardado" "$(basename "$1")"
    ;;
esac
