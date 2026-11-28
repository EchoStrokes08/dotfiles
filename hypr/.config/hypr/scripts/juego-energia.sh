#!/usr/bin/env bash
# Lo llama gamemode (~/.config/gamemode.ini) al empezar y al terminar un juego.
#   inicio      → perfil de energía «performance», GPU a reloj máximo (si estás en el grupo gamemode),
#                 aviso para juego-potencia (más vatios al procesador, ver ~/dotfiles/potencia),
#                 Spotify congelado (no, si está sonando), EasyEffects en bypass y, si WhatsApp (ZapZap) está
#                 abierto, un aviso pregunta qué hacer con él: pausarlo, cerrarlo o dejarlo (sin respuesta en
#                 45 s se queda abierto; nunca se toca sin preguntar)
#   fin         → todo como estaba (o ahorro de energía si sigues con batería)
#   descongelar → devuelve las apps congeladas sin salir del juego (p. ej. para contestar un WhatsApp)
umask 077
run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -d "$run" ] && [ -w "$run" ] || { echo "No hay directorio de sesión disponible" >&2; exit 1; }
estado="$run/juego-energia.perfil"
congeladas="$run/juego-congeladas"
origen="${2:-gamemode}"
case "$origen" in gamemode|escritorio) ;; *) echo "Origen de juego desconocido" >&2; exit 2 ;; esac
exec 9>"$run/juego-energia.lock"
flock -w 8 9 || exit 1
gpu=""
for d in /sys/class/drm/card[0-9]*; do
    [ -e "$d/device/power_dpm_force_performance_level" ] && { gpu="${d##*card}"; break; }
done
gpu_nivel() {  # sin el grupo, pkexec pediría contraseña en mitad del juego: mejor no tocar
    [ -n "$gpu" ] && id -nG | grep -qw gamemode && timeout 2 pkexec /usr/lib/gamemode/gpuclockctl "$gpu" set "$1" >/dev/null 2>&1
}
gpu_inicio() {
    [ -n "$gpu" ] || return 0
    local previo
    previo=$(cat "/sys/class/drm/card$gpu/device/power_dpm_force_performance_level" 2>/dev/null)
    case "$previo" in
        auto|low|high|profile_standard|profile_min_sclk|profile_min_mclk|profile_peak)
            if gpu_nivel high; then printf '%s %s\n' "$gpu" "$previo" > "$run/juego-energia.gpu"; fi ;;
    esac
}
gpu_fin() {
    local dispositivo previo
    if read -r dispositivo previo < "$run/juego-energia.gpu" 2>/dev/null; then
        # Si cambió la numeración del dispositivo no se modifica otra tarjeta.
        if [ "$dispositivo" = "$gpu" ]; then gpu_nivel "$previo"; fi
        rm -f "$run/juego-energia.gpu"
    fi
}
con_bateria() {
    for f in /sys/class/power_supply/{ADP0,ADP1,AC,AC0,ACAD}/online; do
        [ -r "$f" ] && { [ "$(cat "$f")" = 0 ]; return; }
    done
    return 1
}
scopes() {  # cada app flatpak vive en su scope de systemd: congelarlo para todos sus procesos a la vez
    systemctl --user list-units --type=scope --state=running --no-legend --plain "$@" 2>/dev/null |
        while read -r u _; do echo "$u"; done
}
congelar() {  # $@ = scopes
    local u
    for u in "$@"; do systemctl --user freeze "$u" 2>/dev/null && echo "$u" >> "$congeladas"; done
}
congelar_spotify() {  # si estás escuchando música, se respeta
    [ "$(timeout 2 playerctl -p spotify status 2>/dev/null)" = Playing ] && return 0
    mapfile -t s < <(scopes 'app-flatpak-com.spotify.Client-*')
    congelar "${s[@]}"
}
pregunta="$run/juego-pregunta"
preguntar_whatsapp() {  # en segundo plano: el juego arranca sin esperar la respuesta
    local salida id accion pid i=0
    mapfile -t z < <(scopes 'app-flatpak-com.rtosta.zapzap-*')
    [ "${#z[@]}" -gt 0 ] && command -v notify-send >/dev/null || return 0
    salida=$(mktemp "$run/juego-pregunta.XXXXXX") || return 0
    # Crítica: es la única que se muestra con el No molestar del modo juego (Notificaciones.qml)
    notify-send -p -u critical -a "Modo juego" -i com.rtosta.zapzap \
        -A pausar="Pausar" -A cerrar="Cerrar" -A dejar="Dejar abierto" \
        "¿Qué hago con WhatsApp mientras juegas?" \
        "Pausar libera procesador y memoria y vuelve tal cual al terminar. Si no eliges, se queda abierto." \
        > "$salida" 2>/dev/null &
    pid=$!
    cerrar_aviso() {
        id=$(head -n1 "$salida" 2>/dev/null)
        [[ $id =~ ^[0-9]+$ ]] && timeout 2 gdbus call --session --dest org.freedesktop.Notifications \
            --object-path /org/freedesktop/Notifications \
            --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null 2>&1
        kill "$pid" 2>/dev/null
    }
    trap 'cerrar_aviso; rm -f "$salida"; exit 0' TERM INT
    while kill -0 "$pid" 2>/dev/null && [ $i -lt 90 ]; do sleep 0.5 & wait $!; i=$((i+1)); done
    kill -0 "$pid" 2>/dev/null && cerrar_aviso
    accion=$(sed -n 2p "$salida"); rm -f "$salida"
    exec 9>"$run/juego-energia.lock"; flock -w 8 9 || return 0
    [ -e "$run/juego-activo" ] || return 0          # el juego ya terminó: no se toca nada
    mapfile -t z < <(scopes 'app-flatpak-com.rtosta.zapzap-*')
    case "$accion" in
        pausar) congelar "${z[@]}" ;;
        cerrar) for u in "${z[@]}"; do systemctl --user stop "$u" 2>/dev/null; done ;;  # SIGTERM: cierre normal
    esac
}
cancelar_pregunta() {
    local pid
    read -r pid < "$pregunta" 2>/dev/null && [[ $pid =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null
    rm -f "$pregunta"
}
descongelar() {
    local u
    [ -r "$congeladas" ] && while read -r u; do systemctl --user thaw "$u" 2>/dev/null; done < "$congeladas"
    rm -f "$congeladas"
}
easyeffects_bypass() {  # 1 = efectos apagados (el sonido sigue pasando), 2 = efectos otra vez
    pgrep -x easyeffects >/dev/null && timeout 3 easyeffects -b "$1" >/dev/null 2>&1
}
case "${1:-}" in
    inicio)
        touch "$run/juego-energia.$origen"
        [ -e "$run/juego-activo" ] && exit 0
        previo=$(powerprofilesctl get 2>/dev/null)
        case "$previo" in performance|balanced|power-saver) printf '%s\n' "$previo" > "$estado" ;; esac
        powerprofilesctl set performance || echo "No se pudo activar el perfil de rendimiento" >&2
        touch "$run/juego-activo"
        gpu_inicio
        congelar_spotify
        cancelar_pregunta
        preguntar_whatsapp 9>&- </dev/null >/dev/null 2>&1 &
        echo $! > "$pregunta"
        easyeffects_bypass 1 ;;
    fin)
        rm -f "$run/juego-energia.$origen"
        # GameMode y el compositor pueden detectar el mismo juego. Se restaura al salir de ambos.
        if [ -e "$run/juego-energia.gamemode" ] || [ -e "$run/juego-energia.escritorio" ]; then exit 0; fi
        [ -e "$run/juego-activo" ] || exit 0
        previo=$(cat "$estado" 2>/dev/null); rm -f "$estado" "$run/juego-activo"
        if con_bateria; then previo=power-saver; fi
        powerprofilesctl set "${previo:-balanced}"
        gpu_fin
        cancelar_pregunta
        descongelar
        easyeffects_bypass 2 ;;
    descongelar) descongelar ;;
    *) echo "uso: $0 inicio|fin|descongelar" >&2; exit 2 ;;
esac
exit 0
