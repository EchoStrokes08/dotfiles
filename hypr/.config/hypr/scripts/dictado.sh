#!/usr/bin/env bash
# Dictado por voz (SUPER+ALT+D): pulsa, habla, vuelve a pulsar → el texto se escribe donde esté el cursor
# (y queda también en el portapapeles). Whisper en local (dictado.py): tu voz no sale del equipo.
#   dictado.sh            empezar / terminar
#   dictado.sh cancelar   terminar sin escribir nada
# Si el micrófono estaba silenciado, lo activa solo mientras graba y luego lo deja como estaba.
RUN=${XDG_RUNTIME_DIR:-/tmp}
PID=$RUN/dictado.pid; WAV=$RUN/dictado.wav; MUDO=$RUN/dictado.mudo
DIR=$(dirname "$(readlink -f "$0")")
avisar() { qs ipc call osd mensaje "$1" "$2" >/dev/null 2>&1; }
barra()  { qs ipc call barra refrescar grabacion >/dev/null 2>&1; }

parar() {   # para la grabación y devuelve el micro a como estaba
    kill -INT "$(cat "$PID")" 2>/dev/null
    for _ in $(seq 20); do kill -0 "$(cat "$PID")" 2>/dev/null || break; sleep 0.1; done
    rm -f "$PID"
    [ -f "$MUDO" ] && { wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1; rm -f "$MUDO"; }
    barra
}

if [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; then
    parar
    [ "$1" = cancelar ] && { avisar "Dictado cancelado" f036d; exit 0; }
    avisar "Transcribiendo…" f0d4f
    texto=$(python3 -I "$DIR/dictado.py" transcribir "$WAV")
    rm -f "$WAV"
    if [ -z "$texto" ] || [[ "$texto" == $'\0'* ]]; then
        notify-send -a Dictado "No entendí nada" "${texto#?}"; exit 1
    fi
    printf '%s' "$texto" | wl-copy
    printf '%s ' "$texto" | wtype -          # escribe como si fuera el teclado
    exit 0
fi

[ "$1" = cancelar ] && exit 0
# Cargar el modelo YA, mientras hablas (si no estaba cargado)
[ -S "$RUN/dictado.sock" ] || setsid -f python3 -I "$DIR/dictado.py" servir >/dev/null 2>&1
# Micro silenciado → activarlo solo para esto
if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
    touch "$MUDO"; wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0
fi
rm -f "$WAV"
pw-record --rate 16000 --channels 1 "$WAV" & echo $! > "$PID"
barra
avisar "Escuchando… (SUPER+ALT+D para terminar)" f036c
# Seguridad: si olvidas pararlo, se para solo a los 2 minutos
( sleep 120; [ -f "$PID" ] && [ "$(cat "$PID")" = "$!" ] && "$0" ) >/dev/null 2>&1 &
