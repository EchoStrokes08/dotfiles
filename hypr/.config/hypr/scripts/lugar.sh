#!/usr/bin/env bash
# Reglas por lugar: al conectarte a una Wi-Fi, ajusta el equipo según dónde estés.
#   lugar.sh vigilar   -> se queda escuchando los cambios de red (lo arranca autostart.lua)
#   lugar.sh aplicar   -> aplica ahora la regla de la red actual
#   lugar.sh estado    -> «red · lugar»
# Reglas en ~/.config/lugares.conf, una por línea:
#     nombre de la Wi-Fi | lugar | energía | volumen | no molestar
#   energía:     ahorro · equilibrado · rendimiento · -   (- = no tocar)
#   volumen:     0-100 (de las bocinas; 0 = silenciadas) · -
#   no molestar: si · no · -
#   La línea con * vale para cualquier red que no esté en la lista.
# Solo actúa cuando CAMBIAS de red (no cada vez que se reconecta a la misma).
CONF="$HOME/.config/lugares.conf"
ULTIMA="${XDG_RUNTIME_DIR:-/tmp}/lugar-red"

red_actual() { nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{print substr($0,5); exit}'; }

regla() {   # regla <ssid> -> «lugar|energia|volumen|nomolestar» ("" si no hay)
    [ -f "$CONF" ] || return
    awk -F'|' -v s="$1" '
        function t(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        /^[ \t]*(#|$)/ { next }
        t($1) == s   { print t($2) "|" t($3) "|" t($4) "|" t($5); hecho = 1; exit }
        t($1) == "*" { comodin = t($2) "|" t($3) "|" t($4) "|" t($5) }
        END { if (!hecho && comodin != "") print comodin }' "$CONF"
}

aplicar() {
    local ssid=$1 r lugar energia volumen nm
    r=$(regla "$ssid"); [ -z "$r" ] && return
    IFS='|' read -r lugar energia volumen nm <<< "$r"
    case "$energia" in
        ahorro)      powerprofilesctl set power-saver ;;
        equilibrado) powerprofilesctl set balanced ;;
        rendimiento) powerprofilesctl set performance ;;
    esac
    # el volumen solo se toca si suenan las bocinas (con audífonos puestos no molestas a nadie)
    if [[ "$volumen" =~ ^[0-9]+$ ]] && [[ "$(pactl get-default-sink 2>/dev/null)" == alsa_output.* ]]; then
        if [ "$volumen" -eq 0 ]; then wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
        else wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ "$volumen%"; fi
    fi
    case "$nm" in
        si) qs ipc call notificaciones noMolestarSi >/dev/null 2>&1 ;;
        no) qs ipc call notificaciones noMolestarNo >/dev/null 2>&1 ;;
    esac
    qs ipc call barra refrescar todo >/dev/null 2>&1
    qs ipc call osd mensaje "Estás en: ${lugar:-$ssid}" f034e >/dev/null 2>&1
}

comprobar() {   # aplica solo si la red cambió desde la última vez
    local ssid; ssid=$(red_actual)
    [ -z "$ssid" ] && return
    [ "$ssid" = "$(cat "$ULTIMA" 2>/dev/null)" ] && return
    echo "$ssid" > "$ULTIMA"
    [ "$1" = silencio ] || aplicar "$ssid"
}

case "${1:-estado}" in
    vigilar)
        comprobar silencio                    # al iniciar sesión solo se apunta la red: no cambia nada
        nmcli monitor | while read -r linea; do
            case "$linea" in *": connected"*|*"is now the primary connection"*) sleep 2; comprobar ;; esac
        done ;;
    aplicar) s=$(red_actual); [ -n "$s" ] && { echo "$s" > "$ULTIMA"; aplicar "$s"; } ;;
    estado)  s=$(red_actual); echo "${s:-sin Wi-Fi} · $(regla "$s" | cut -d'|' -f1)" ;;
    *)       echo "uso: lugar.sh vigilar|aplicar|estado"; exit 1 ;;
esac
