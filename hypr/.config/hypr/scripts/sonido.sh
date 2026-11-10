#!/usr/bin/env bash
# Mejora de sonido de las bocinas del portátil con EasyEffects (SUPER+ALT+E = menú).
#   sonido.sh Portatil    -> perfil música: más cuerpo, menos "caja", más brillo + realce de graves
#   sonido.sh Voz         -> perfil voz: clases, vídeos y llamadas se entienden mejor y a volumen parejo
#   sonido.sh off         -> sin efectos (cierra EasyEffects: ni RAM ni CPU)
#   sonido.sh menu        -> menú de Quickshell          sonido.sh estado -> perfil elegido
#   sonido.sh restaurar   -> al iniciar sesión: vuelve a poner el último perfil
#   sonido.sh salida      -> lo llama Quickshell (Audifonos.qml) al cambiar la salida de audio:
#                            los perfiles son para las bocinas; con audífonos (Bluetooth o de cable)
#                            los efectos se saltan solos y vuelven al regresar a las bocinas.
# Perfiles: ~/.local/share/easyeffects/output/*.json (dotfiles/easyeffects). Para afinarlos de oído:
# abre "Easy Effects" desde el lanzador, mueve lo que quieras y guarda el perfil con el mismo nombre.

ESTADO="$HOME/.local/state/sonido"
perfil=$(cat "$ESTADO" 2>/dev/null || echo Portatil)

arrancar() {   # deja el servicio corriendo (sin ventana) y espera a que responda
    pgrep -x easyeffects >/dev/null && return
    setsid -f easyeffects --service-mode --hide-window >/dev/null 2>&1
    for _ in $(seq 30); do sleep 0.2; easyeffects -b 3 >/dev/null 2>&1 && break; done
}

en_bocinas() {   # ¿la salida actual son las bocinas internas? (no Bluetooth, no audífonos de cable)
    local s; s=$(pactl get-default-sink 2>/dev/null)
    case "$s" in alsa_output.*analog*) ;; *) return 1 ;; esac
    ! pactl list sinks 2>/dev/null | awk -v s="$s" '$1=="Name:"{ok=($2==s)} ok && /Active Port:/{print $3}' | grep -qi headphone
}

saltar_segun_salida() {   # bypass: 1 = saltar los efectos, 2 = aplicarlos
    pgrep -x easyeffects >/dev/null || return
    if en_bocinas; then easyeffects -b 2; else easyeffects -b 1; fi >/dev/null 2>&1
}

avisar() { qs ipc call osd mensaje "$1" f057e >/dev/null 2>&1 || notify-send -a Sonido -u low "$1"; }

case "$1" in
    Portatil|Voz)
        arrancar; easyeffects -l "$1" >/dev/null 2>&1; echo "$1" > "$ESTADO"; saltar_segun_salida
        [ "$1" = Voz ] && avisar "Sonido: perfil voz" || avisar "Sonido: perfil música" ;;
    off)
        echo off > "$ESTADO"; easyeffects -q >/dev/null 2>&1; avisar "Sonido: sin efectos" ;;
    restaurar)
        [ "$perfil" = off ] && exit 0
        arrancar; easyeffects -l "$perfil" >/dev/null 2>&1; saltar_segun_salida ;;
    salida)  saltar_segun_salida ;;
    menu)    qs ipc call menu sonido "$perfil" ;;
    estado)  echo "$perfil" ;;
    *)       echo "uso: sonido.sh Portatil|Voz|off|menu|estado|restaurar|salida"; exit 1 ;;
esac
