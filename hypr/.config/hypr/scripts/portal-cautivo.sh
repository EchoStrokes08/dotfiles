#!/usr/bin/env bash
# Portal cautivo: cuando una Wi-Fi pide iniciar sesión (universidad, hotel, aeropuerto), abre su página
# en el navegador sola y avisa al conectar. Lo arranca portal-cautivo.service (paquete «servicios»).
#   portal-cautivo.sh vigilar   bucle (lo usa el servicio)
#   portal-cautivo.sh abrir     abrir la página de acceso ahora
# El DNS cifrado se aparta solo mientras dura el portal: /etc/NetworkManager/dispatcher.d/90-portal-cautivo
set -uo pipefail
# página HTTP (sin https) que el portal intercepta y redirige a su inicio de sesión
URL=http://ping.archlinux.org/nm-check.txt

abrir() {
    notify-send -a "Wi-Fi" -i network-wireless "Inicia sesión en la Wi-Fi" "$(red) pide autenticarse: abriendo la página de acceso" || true
    if command -v firefox >/dev/null; then firefox --new-window "$URL" >/dev/null 2>&1 &
    else xdg-open "$URL" >/dev/null 2>&1 & fi
}
red() { nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1; }
estado() { nmcli -t -f CONNECTIVITY general 2>/dev/null; }

vigilar() {
    local antes="" ahora abierto="" n=0
    while :; do
        ahora=$(estado)
        if [ "$ahora" = portal ]; then
            # una vez por red y conexión: no reabrir el navegador cada 5 s
            local clave; clave="$(nmcli -g GENERAL.CON-UUID device show "$(ip route show default | awk '{print $5; exit}')" 2>/dev/null)"
            if [ "$abierto" != "$clave" ]; then abierto=$clave; abrir; fi
            # mirar a menudo si ya iniciaste sesión (NetworkManager solo lo hace cada 5 min)
            n=$(( (n + 1) % 3 )); [ "$n" = 0 ] && nmcli networking connectivity check >/dev/null 2>&1
        elif [ "$ahora" = full ] && [ "$antes" = portal ]; then
            notify-send -a "Wi-Fi" -i network-wireless "Conectado a $(red)" "Sesión iniciada: ya hay internet" || true
        fi
        [ "$ahora" = none ] && abierto=""
        antes=$ahora
        sleep 5
    done
}

case "${1:-vigilar}" in
    vigilar) vigilar ;;
    abrir) abrir ;;
    *) sed -n '2,6p' "$0"; exit 1 ;;
esac
