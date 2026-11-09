#!/usr/bin/env bash
# Grabar la pantalla (SUPER+ALT+R): menú → región / pantalla, con o sin audio, o un GIF.
# Mientras graba hay un punto rojo con el tiempo en la barra; SUPER+ALT+R otra vez (o clic en él) para.
# Los vídeos van a ~/Videos/Grabaciones (y la ruta queda copiada).
#   grabar.sh                 menú (si ya graba: parar)
#   grabar.sh <modo>          region | pantalla | region-audio | pantalla-audio | gif
#   grabar.sh parar
# Usa wf-recorder (no gpu-screen-recorder: ese lo controla replay.sh con señales a todos sus procesos).
RUN=${XDG_RUNTIME_DIR:-/tmp}
PID=$RUN/grabar.pid; ESTADO=$RUN/grabar.estado      # estado: "modo archivo inicio"
DESTINO="$HOME/Videos/Grabaciones"
mkdir -p "$DESTINO"
barra() { qs ipc call barra refrescar grabacion >/dev/null 2>&1; }
grabando() { [ -f "$PID" ] && kill -0 "$(cat "$PID")" 2>/dev/null; }

parar() {
    grabando || { rm -f "$PID" "$ESTADO"; barra; return 1; }
    read -r modo archivo _ < "$ESTADO"
    kill -INT "$(cat "$PID")"
    for _ in $(seq 50); do grabando || break; sleep 0.1; done
    rm -f "$PID" "$ESTADO"; barra
    if [ "$modo" = gif ]; then
        qs ipc call osd mensaje "Creando el GIF…" f0d78 >/dev/null 2>&1
        gif="${archivo%.mp4}.gif"
        # paleta propia del clip: colores fieles; 12 fps y máx. 800 px de ancho para que no pese
        ffmpeg -loglevel error -y -i "$archivo" -vf "fps=12,scale='min(800,iw)':-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$gif" \
            && rm -f "$archivo" && archivo=$gif
    fi
    printf '%s' "$archivo" | wl-copy
    accion=$(notify-send -a Grabación -A abrir=Abrir -A carpeta="Ver carpeta" \
             "Grabación guardada" "$(basename "$archivo") · $(du -h "$archivo" | cut -f1) · ruta copiada")
    case "$accion" in
        abrir)   xdg-open "$archivo" ;;
        carpeta) thunar "$DESTINO" ;;
    esac
}

empezar() {   # empezar <modo>
    local modo=$1 geo="" region=() audio=() ext=mp4
    case "$modo" in
        region|region-audio|gif) geo=$(slurp -b 0e141988 -c ff3333ff -w 2) || exit 0; region=(-g "$geo") ;;   # borde rojo = grabar
    esac
    case "$modo" in
        *-audio) audio=(--audio="$(pactl get-default-sink).monitor") ;;            # lo que suena en el equipo
    esac
    archivo="$DESTINO/$(date +'%Y%m%d_%H%M%S')_grabacion.$ext"
    # codificación por la GPU (VAAPI): casi no gasta CPU
    setsid wf-recorder "${region[@]}" "${audio[@]}" -c h264_vaapi -d /dev/dri/renderD128 -f "$archivo" >/dev/null 2>&1 &
    echo $! > "$PID"
    echo "$modo $archivo $(date +%s)" > "$ESTADO"
    sleep 0.3; grabando || { notify-send -a Grabación "No se pudo empezar a grabar"; rm -f "$PID" "$ESTADO"; exit 1; }
    barra
}

case "${1:-}" in
    "")     if grabando; then parar
            elif [ -n "$(qs ipc call menu grabar 2>&1)" ]; then empezar region; fi ;;   # sin Quickshell: región
    parar)  parar ;;
    region|pantalla|region-audio|pantalla-audio|gif) grabando && parar || empezar "$1" ;;
    estado) grabando && cat "$ESTADO" || echo "no" ;;
    *)      sed -n '2,8p' "$0"; exit 1 ;;
esac
