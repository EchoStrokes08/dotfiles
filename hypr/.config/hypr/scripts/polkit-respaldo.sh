#!/usr/bin/env bash
# Respaldo del agente de polkit (la ventana de la contraseña de administrador).
# El agente normal lo dibuja Quickshell (Autorizacion.qml). Solo puede haber uno por sesión,
# así que hyprpolkitagent ya no arranca de entrada: este script lo lanza si Quickshell no tiene
# el suyo registrado (no cargó, se cayó…), para no quedarse nunca sin forma de autorizar.
#   polkit-respaldo.sh          espera a Quickshell al iniciar y luego vigila cada minuto
#   polkit-respaldo.sh estado   dice quién atiende ahora las peticiones

registrado() { [ "$(timeout 3 qs ipc call polkit registrado 2>/dev/null)" = "si" ]; }
respaldo_activo() { systemctl --user is-active --quiet hyprpolkitagent; }

if [ "${1:-}" = "estado" ]; then
    if registrado; then echo "quickshell"
    elif respaldo_activo; then echo "hyprpolkitagent"
    else echo "ninguno"; fi
    exit 0
fi

# Al iniciar: hasta 20 s para que Quickshell cargue y registre su agente
for _ in $(seq 20); do
    registrado && break
    sleep 1
done

while :; do
    if ! registrado && ! respaldo_activo; then
        systemctl --user start hyprpolkitagent
    fi
    sleep 60
done
