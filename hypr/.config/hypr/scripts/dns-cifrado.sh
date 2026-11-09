#!/usr/bin/env bash
# DNS cifrado (DNS-over-TLS con Quad9/Cloudflare, vía systemd-resolved).
#   dns-cifrado estado   → activo o no, y qué servidor se usa
#   dns-cifrado off      → usar el DNS del router (para Wi-Fi de hotel/aeropuerto con página de acceso)
#   dns-cifrado on       → volver al cifrado (hazlo en cuanto entres en esa Wi-Fi)
# Archivos: /etc/systemd/resolved.conf.d/dns-cifrado.conf (servidores) y
#           /etc/NetworkManager/conf.d/dns.conf (dns=none: NM no pasa el DNS del router)
set -euo pipefail
CONF=/etc/systemd/resolved.conf.d/dns-cifrado.conf
NM=/etc/NetworkManager/conf.d/dns.conf

recargar() {
    sudo systemctl restart systemd-resolved
    sudo nmcli general reload conf
    # reaplicar la conexión activa para que NM entregue (o no) el DNS del router a resolved
    local con; con=$(nmcli -t -f NAME connection show --active | grep -v '^lo$' | head -1)
    [ -n "$con" ] && sudo nmcli connection up "$con" >/dev/null
}

case "${1:-estado}" in
    on)
        [ -f "$CONF.apagado" ] && sudo mv "$CONF.apagado" "$CONF"
        printf '# DNS cifrado: NetworkManager NO pasa a resolved el DNS del router/operador (iría sin cifrar);\n# se usan solo los de %s. Para Wi-Fi con portal: dns-cifrado off\n[main]\ndns=none\n' "$CONF" \
            | sudo tee "$NM" >/dev/null
        recargar; sudo resolvectl revert "$(ip route show default | awk '{print $5; exit}')" 2>/dev/null || true
        echo "DNS cifrado: activado" ;;
    off)
        [ -f "$CONF" ] && sudo mv "$CONF" "$CONF.apagado"
        printf '# DNS cifrado APAGADO (dns-cifrado off): se usa el DNS del router a través de resolved\n[main]\ndns=systemd-resolved\n' \
            | sudo tee "$NM" >/dev/null
        recargar
        echo "DNS cifrado: APAGADO (usa el DNS del router). Vuelve con: dns-cifrado on" ;;
    estado)
        if [ -f "$CONF" ]; then echo "DNS cifrado: activado"; else echo "DNS cifrado: APAGADO"; fi
        # con el cifrado manda el servidor global; sin él, el de la conexión (el router)
        if [ -f "$CONF" ]; then resolvectl status | sed -n '/^Global/,/^Link/p' | grep -m1 'Current DNS Server'
        else resolvectl status | sed -n '/^Link/,$p' | grep -m1 'Current DNS Server'; fi | sed 's/.*: /Servidor: /' ;;
    *) sed -n '2,6p' "$0"; exit 1 ;;
esac
