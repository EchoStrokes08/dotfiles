#!/usr/bin/env bash
# Esperar confirmación del compositor. Nunca confundir «bloqueando» con «bloqueado».
set -u
runtime="${XDG_RUNTIME_DIR:?Falta XDG_RUNTIME_DIR}"
exec 9>"$runtime/hypr-bloquear.lock"
flock -w 10 9 || exit 1
pidof hyprlock >/dev/null && exit 0

timeout 2 qs ipc call bloqueo bloquear >/dev/null 2>&1 || true
limite=$((SECONDS + 6))
pendiente=0
while [ "$SECONDS" -lt "$limite" ]; do
    estado=$(timeout 1 qs ipc call bloqueo estado 2>/dev/null) || estado=ausente
    case "$estado" in
        bloqueado) exit 0 ;;
        bloqueando) pendiente=1 ;;
        libre|ausente) [ "$pendiente" = 1 ] || break ;;
    esac
    sleep 0.1
done
if [ "$pendiente" = 1 ]; then
    logger -t hypr-bloqueo 'Quickshell no confirmó un bloqueo seguro: usar recuperación TTY'
    timeout 2 notify-send -u critical 'Bloqueo sin confirmar' 'Usa la recuperación TTY; no suspendas hasta confirmar el bloqueo.' || true
    exit 1
fi
# Sin un bloqueo pendiente, hyprlock puede adquirirlo o recuperar uno abandonado.
exec hyprlock
