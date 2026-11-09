#!/usr/bin/env bash
# respaldo: copias de seguridad CIFRADAS (restic) en el disco externo (TOSHIBA EXT → OSCAR/hyprland).
#
#   respaldo              copia si el disco está conectado y la última tiene más de 20 h (lo usan el timer y el udev)
#   respaldo ahora        copia ya, aunque haya una reciente
#   respaldo estado       última copia, número de copias y espacio en el disco
#   respaldo lista        todas las copias (snapshots)
#   respaldo montar       abre las copias como carpetas en /mnt/respaldo para sacar archivos (Ctrl+C cierra)
#   respaldo comprobar    verifica que las copias se pueden leer enteras
#
# Configuración: /etc/respaldo/config (disco y carpeta) · contraseña: /etc/respaldo/clave
#                /etc/respaldo/excluir (qué NO copiar)
# Se instala con ~/dotfiles/respaldo/instalar.sh (copia este archivo a /usr/local/bin/respaldo).
# SIN la contraseña las copias no se pueden abrir: guárdala también fuera del portátil.
set -uo pipefail
[ "$EUID" -eq 0 ] || exec sudo "$0" "$@"

source /etc/respaldo/config          # UUID, CARPETA, USUARIO
CASA=$(getent passwd "$USUARIO" | cut -d: -f6)
export RESTIC_PASSWORD_FILE=/etc/respaldo/clave
ESTADO=/var/lib/respaldo
mkdir -p "$ESTADO/sistema"

# Aviso en el escritorio (systembus-notify lo pasa a las notificaciones de Quickshell)
avisar() { dbus-send --system / net.nuetzlich.SystemNotifications.Notify "string:$1" "string:$2" 2>/dev/null; echo "$1: $2"; }

ultima() { cat "$ESTADO/ultima" 2>/dev/null || echo 0; }
hace() { local s=$(( $(date +%s) - $(ultima) )); [ "$(ultima)" = 0 ] && echo "nunca" && return
         [ $s -lt 7200 ] && echo "hace $((s/60)) min" || { [ $s -lt 172800 ] && echo "hace $((s/3600)) h" || echo "hace $((s/86400)) días"; }; }

# ¿Dónde está montado el disco? (udiskie lo monta solo al conectarlo; esperamos hasta 60 s)
montaje() {
    local i m
    for i in $(seq 60); do
        m=$(findmnt -no TARGET -S "UUID=$UUID" 2>/dev/null | head -1)
        [ -n "$m" ] && { echo "$m"; return 0; }
        [ -e "/dev/disk/by-uuid/$UUID" ] || return 1     # ni siquiera está conectado
        sleep 1
    done
    return 1
}

repo() {
    local m; m=$(montaje) || { echo "El disco no está conectado (o no se montó)."; exit 1; }
    export RESTIC_REPOSITORY="$m/$CARPETA"
}

recordatorio() {   # sin disco: avisar una vez al día si la última copia tiene más de 7 días
    local hoy; hoy=$(date +%F)
    if [ $(( $(date +%s) - $(ultima) )) -gt $((7*86400)) ] && [ "$(cat "$ESTADO/aviso" 2>/dev/null)" != "$hoy" ]; then
        avisar "Copia de seguridad" "Última copia: $(hace). Conecta el disco TOSHIBA para hacer una."
        echo "$hoy" > "$ESTADO/aviso"
    fi
}

copiar() {
    repo
    if [ ! -f "$RESTIC_REPOSITORY/config" ]; then
        mkdir -p "$RESTIC_REPOSITORY"
        restic init || { avisar "Copia de seguridad" "No se pudo crear el repositorio"; exit 1; }
    fi

    # Foto del sistema: con esto se reinstala lo mismo (ver ~/dotfiles/instalar.sh)
    pacman -Qqen > "$ESTADO/sistema/paquetes-repo.txt"
    pacman -Qqem > "$ESTADO/sistema/paquetes-aur.txt"
    flatpak list --app --columns=application > "$ESTADO/sistema/flatpak.txt" 2>/dev/null
    systemctl list-unit-files --state=enabled --no-legend > "$ESTADO/sistema/servicios.txt"
    lsblk -f > "$ESTADO/sistema/discos.txt"

    local rutas=() r
    for r in "$CASA/Documents" "$CASA/Projects" "$CASA/proyectos" "$CASA/Imágenes" "$CASA/Pictures" \
             "$CASA/.config" "$CASA/.local/share" "$CASA/.ssh" "$CASA/.gnupg" "$CASA/dotfiles" \
             /etc /usr/local "$ESTADO/sistema"; do
        [ -e "$r" ] && rutas+=("$r")
    done

    avisar "Copia de seguridad" "Copiando… no desconectes el disco TOSHIBA"
    local salida codigo
    restic backup --json --quiet --tag auto --exclude-caches \
           --exclude-file=/etc/respaldo/excluir "${rutas[@]}" >"$ESTADO/salida.json" 2>"$ESTADO/errores.log"
    codigo=$?
    salida=$(tail -1 "$ESTADO/salida.json")
    # 0 = bien · 3 = hecha, pero algún archivo no se pudo leer (p. ej. uno borrado a mitad) · otro = falló
    if [ $codigo -ne 0 ] && [ $codigo -ne 3 ]; then
        avisar "Copia de seguridad FALLÓ" "$(tail -1 "$ESTADO/errores.log")"
        exit 1
    fi
    date +%s > "$ESTADO/ultima"

    restic forget --quiet --prune --tag auto --keep-daily 7 --keep-weekly 4 --keep-monthly 12 >/dev/null 2>&1

    local nuevos cambiados mb
    nuevos=$(jq -r '.files_new // 0' <<<"$salida"); cambiados=$(jq -r '.files_changed // 0' <<<"$salida")
    mb=$(jq -r '((.data_added // 0) / 1048576 * 10 | floor) / 10' <<<"$salida")
    avisar "Copia de seguridad hecha" "$nuevos archivos nuevos, $cambiados cambiados (+$mb MB). Ya puedes desconectar el disco."
    [ $codigo -eq 3 ] && echo "Aviso: algunos archivos no se pudieron leer (ver $ESTADO/errores.log)"
    return 0
}

case "${1:-auto}" in
    auto)
        if ! montaje >/dev/null; then recordatorio; exit 0; fi
        [ $(( $(date +%s) - $(ultima) )) -lt $((20*3600)) ] && { echo "Última copia $(hace): nada que hacer."; exit 0; }
        copiar ;;
    ahora)     copiar ;;
    estado)
        echo "Última copia: $(hace)"
        if repo 2>/dev/null; then
            echo "Copias guardadas: $(restic snapshots --json 2>/dev/null | jq length)"
            df -h --output=avail,size "$(montaje)" | tail -1 | awk '{print "Disco: " $1 " libres de " $2}'
        else echo "Disco: no conectado"; fi ;;
    lista)     repo; restic snapshots ;;
    montar)    repo; mkdir -p /mnt/respaldo
               echo "Abre /mnt/respaldo/snapshots/latest/ (o una fecha) y copia lo que necesites. Ctrl+C para cerrar."
               restic mount /mnt/respaldo ;;
    comprobar) repo; restic check --read-data ;;
    *)         sed -n '2,12p' "$0"; exit 1 ;;
esac
