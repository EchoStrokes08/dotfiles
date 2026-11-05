#!/usr/bin/env bash
# Bloquea la sesión con la pantalla de Quickshell y, si no lo consigue, con hyprlock.
# Lo llama hypridle (lock_cmd): SUPER+L, inactividad y antes de suspender.
#
# Por qué un script: "qs ipc call" devuelve éxito aunque Quickshell no tenga ese destino,
# así que no basta con "qs … || hyprlock": hay que COMPROBAR que el bloqueo se puso.

pidof hyprlock >/dev/null && exit 0           # ya hay un hyprlock: nada que hacer

qs ipc call bloqueo bloquear >/dev/null 2>&1
for _ in $(seq 20); do                        # hasta 2 s
    case "$(qs ipc call bloqueo estado 2>/dev/null)" in
        bloqueado|bloqueando) exit 0 ;;
    esac
    sleep 0.1
done

# Quickshell no respondió: respaldo
exec hyprlock
