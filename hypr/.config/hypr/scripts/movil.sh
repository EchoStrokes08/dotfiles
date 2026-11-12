#!/usr/bin/env bash
# Móvil vía KDE Connect (lo usa el módulo de la barra y el lanzador).
#   movil.sh estado     → «nombre|carga|cargando» del primer móvil emparejado y conectado ("" si ninguno)
#   movil.sh sonar      → hace sonar el móvil (para encontrarlo)
#   movil.sh enviar F…  → manda archivos al móvil
#   movil.sh app        → la ventana de KDE Connect (emparejar, ajustes)
#   movil.sh menu       → panel «PC + móvil» (SUPER+ALT+M, clic en el móvil de la barra); el menú, de respaldo
#   movil.sh portapapeles → manda al móvil lo que tengas copiado
#   movil.sh elegir     → eliges un archivo y lo manda
#   movil.sh navegar    → abre los archivos del móvil en Thunar
id=$(kdeconnect-cli -a --id-only 2>/dev/null | head -1)
dev=/modules/kdeconnect/devices/$id
prop() { busctl --user get-property org.kde.kdeconnect "$dev$1" "org.kde.kdeconnect.device$2" "$3" 2>/dev/null | cut -d' ' -f2- | tr -d '"'; }
case "${1:-estado}" in
    estado) [ -z "$id" ] && exit 0
            echo "$(prop "" "" name)|$(prop /battery .battery charge)|$(prop /battery .battery isCharging)" ;;
    sonar)  [ -n "$id" ] && kdeconnect-cli -d "$id" --ring || notify-send -a "KDE Connect" "No hay ningún móvil conectado" ;;
    enviar) shift; for f in "$@"; do kdeconnect-cli -d "$id" --share "$f"; done ;;
    app)    kdeconnect-app ;;
    portapapeles)
            [ -z "$id" ] && { notify-send -a "KDE Connect" "No hay ningún móvil conectado"; exit 1; }
            kdeconnect-cli -d "$id" --share-text "$(wl-paste -n)" && qs ipc call osd mensaje "Enviado al móvil" f011c ;;
    elegir) [ -z "$id" ] && { notify-send -a "KDE Connect" "No hay ningún móvil conectado"; exit 1; }
            f=$(zenity --file-selection --multiple --separator=$'\n' --title="Enviar al móvil") || exit 0
            while IFS= read -r a; do kdeconnect-cli -d "$id" --share "$a"; done <<< "$f"
            qs ipc call osd mensaje "Enviado al móvil" f011c ;;
    navegar) [ -n "$id" ] && thunar "sftp://$(busctl --user call org.kde.kdeconnect "$dev/sftp" org.kde.kdeconnect.device.sftp mountPoint 2>/dev/null | cut -d'"' -f2)" 2>/dev/null \
                || kdeconnect-app ;;
    menu)   # el panel «PC + móvil» de Quickshell (Movil.qml); este menú queda de respaldo
            qs ipc call movil toggle 2>/dev/null | grep -q "Not ready\|No running" || exit 0
            if [ -z "$id" ]; then
                ops='[{"icono":983324,"texto":"Emparejar un móvil","cmd":"~/.config/hypr/scripts/movil.sh app"}]'
                titulo="Móvil: ninguno conectado"
            else
                c="~/.config/hypr/scripts/movil.sh"
                ops=$(jq -cn --arg c "$c" '[
                    {icono:983196, texto:"Hacer sonar (encontrarlo)",   cmd:($c+" sonar")},
                    {icono:983367, texto:"Enviar lo copiado",           cmd:($c+" portapapeles")},
                    {icono:983572, texto:"Enviar un archivo…",          cmd:($c+" elegir")},
                    {icono:983627, texto:"Ver los archivos del móvil",  cmd:($c+" navegar")},
                    {icono:984211, texto:"Abrir KDE Connect",           cmd:($c+" app")}]')
                titulo="$(prop "" "" name) · batería $(prop /battery .battery charge) %"
            fi
            ~/.config/hypr/scripts/menu.sh "$titulo" "$ops" ;;
esac
