#!/usr/bin/env bash
# Portal cautivo: cuando una Wi-Fi pide iniciar sesión (universidad, hotel, aeropuerto), abre su página
# en el navegador sola y avisa al conectar. Lo arranca portal-cautivo.service (paquete «servicios»).
#   portal-cautivo.sh vigilar   bucle (lo usa el servicio)
#   portal-cautivo.sh abrir     abrir la página de acceso ahora
# El DNS cifrado se aparta solo mientras dura el portal: /etc/NetworkManager/dispatcher.d/90-portal-cautivo
set -uo pipefail
# página HTTP (sin https) que el portal intercepta y redirige a su inicio de sesión
URL=http://ping.archlinux.org/nm-check.txt

# ¿hay portal? Pide la página HTTP de prueba: si no llega «NetworkManager is online» es que el portal la
# intercepta. Imprime la dirección a abrir (la de su inicio de sesión si redirige) o nada si no hay portal.
# No depende de NetworkManager, que solo vuelve a comprobar cada 5 min.
sondear() {
    local r cuerpo codigo destino
    r=$(curl -s -m 5 -w '\n%{http_code} %{redirect_url}' "$URL" 2>/dev/null) || return 0
    codigo=$(tail -1 <<<"$r" | cut -d' ' -f1); destino=$(tail -1 <<<"$r" | cut -s -d' ' -f2-)
    cuerpo=$(head -1 <<<"$r")
    [ "$codigo" = 200 ] && [ "$cuerpo" = "NetworkManager is online" ] && return 0
    case "$codigo" in
        30[1278]) echo "${destino:-$URL}" ;;
        2??) echo "$URL" ;;
    esac
}

# Siempre una dirección http:// (sin s): el portal (p. ej. el controlador Cisco de la universidad)
# intercepta TODO el HTTPS antes de iniciar sesión y Firefox lo rechaza (MITM detectado / HSTS).
abrir() {
    local destino=${1:-$URL}
    logger -t portal-cautivo "$(red): portal cautivo → abriendo $destino"
    notify-send -a "Wi-Fi" -i network-wireless "Inicia sesión en la Wi-Fi" "$(red) pide autenticarse: abriendo la página de acceso" || true
    if command -v firefox >/dev/null; then firefox --new-window "$destino" >/dev/null 2>&1 &
    else xdg-open "$destino" >/dev/null 2>&1 & fi
}
red() { nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1; }
estado() { nmcli -t -f CONNECTIVITY general 2>/dev/null; }

vigilar() {
    local antes="" ahora abierto="" clave destino n=0
    while :; do
        ahora=$(estado); destino=""
        # NetworkManager tarda en darse cuenta del portal: mientras no diga «full», mirar nosotros
        if [ "$ahora" = portal ] || [ "$ahora" = limited ]; then
            destino=$(sondear)
            [ "$ahora" = portal ] && [ -z "$destino" ] && destino=$URL
        fi
        if [ -n "$destino" ]; then
            # una vez por red y conexión: no reabrir el navegador cada 5 s
            clave="$(nmcli -g GENERAL.CON-UUID device show "$(ip route show default | awk '{print $5; exit}')" 2>/dev/null)"
            if [ "$abierto" != "$clave" ]; then abierto=$clave; abrir "$destino"; fi
            # que NetworkManager se entere en cuanto inicies sesión (él solo mira cada 5 min)
            n=$(( (n + 1) % 3 )); [ "$n" = 0 ] && nmcli networking connectivity check >/dev/null 2>&1
            ahora=portal
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
    abrir) abrir "$(sondear)" ;;
    *) sed -n '2,6p' "$0"; exit 1 ;;
esac
