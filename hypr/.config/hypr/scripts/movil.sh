#!/usr/bin/env bash
# Móvil vía KDE Connect (lo usa el módulo de la barra y el lanzador).
#   movil.sh estado     → «nombre|carga|cargando» del primer móvil emparejado y conectado ("" si ninguno)
#   movil.sh sonar      → hace sonar el móvil (para encontrarlo)
#   movil.sh enviar F…  → manda archivos al móvil
#   movil.sh app        → la ventana de KDE Connect (emparejar, ajustes)
id=$(kdeconnect-cli -a --id-only 2>/dev/null | head -1)
dev=/modules/kdeconnect/devices/$id
prop() { busctl --user get-property org.kde.kdeconnect "$dev$1" "org.kde.kdeconnect.device$2" "$3" 2>/dev/null | cut -d' ' -f2- | tr -d '"'; }
case "${1:-estado}" in
    estado) [ -z "$id" ] && exit 0
            echo "$(prop "" "" name)|$(prop /battery .battery charge)|$(prop /battery .battery isCharging)" ;;
    sonar)  [ -n "$id" ] && kdeconnect-cli -d "$id" --ring || notify-send -a "KDE Connect" "No hay ningún móvil conectado" ;;
    enviar) shift; for f in "$@"; do kdeconnect-cli -d "$id" --share "$f"; done ;;
    app)    kdeconnect-app ;;
esac
