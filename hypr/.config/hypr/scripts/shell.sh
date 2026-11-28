#!/bin/bash
# Arranca Quickshell con la escala de interfaz elegida en «Más › Apariencia» (ORION 5.10) y lo vigila.
#   shell.sh            arrancar (autostart.lua) y dejar el guardián en marcha
#   shell.sh reiniciar  cerrar la instancia actual y volver a abrirla con la escala guardada
#   shell.sh parar      cerrarlo sin que el guardián lo vuelva a abrir (lo reabre `shell.sh`)
# La escala vive en ~/.local/state/quickshell/preferencias.json («escala»: 1, 1.1 o 1.25).
#
# Guardián: si Quickshell muere (p. ej. el SIGSEGV del 26-nov al abrir un juego) se vuelve a abrir a los
# 2 s. Si es Quickshell quien se relanza (su gestor de caídas), el guardián cierra la ventana «Quickshell
# has crashed» en cuanto el informe está guardado (~/.cache/quickshell/crashes) y deja un aviso. Con más
# de 4 caídas en 3 minutos deja de insistir y avisa, para no entrar en un bucle de caídas.
# También avisa una vez si Qt se actualizó después que Quickshell: usa APIs privadas de Qt y sin
# recompilarlo es propenso a caerse (`instalar/quickshell-recompilar.sh`).
run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
detenido="$run/orion-shell.detenido"
PREF="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/preferencias.json"

vivo() { pgrep -u "$(id -u)" -x 'qs|quickshell' -r R,S,D,I,T,t >/dev/null; }   # sin zombis

aviso() {  # sin servidor de notificaciones (Quickshell caído) se usa el aviso de Hyprland
    notify-send -u critical -a "Quickshell" "$1" "$2" 2>/dev/null ||
        hyprctl notify 0 15000 0 "$1: $2" >/dev/null 2>&1
}

lanzar() {
    local escala
    escala=$(python3 -I -c 'import json,sys
try: v=float(json.load(open(sys.argv[1])).get("escala",1))
except Exception: v=1
print(v if v in (1,1.1,1.25) else 1)' "$PREF" 2>/dev/null) || escala=1
    (
        if [ "$escala" = 1.0 ] || [ "$escala" = 1 ]; then unset QT_SCALE_FACTOR; else export QT_SCALE_FACTOR="$escala"; fi
        # Traducciones de entradas .desktop y Qt, manteniendo los formatos de la sesión.
        if locale -a | grep -iq '^es_MX\.utf8$'; then
            if [ -n "${LC_ALL:-}" ]; then export LANG="$LC_ALL"; unset LC_ALL; fi
            export LC_MESSAGES=es_MX.UTF-8 LANGUAGE=es_MX:es
        fi
        exec setsid -f qs 9>&- 8>&- </dev/null >/dev/null 2>&1
    )
}

parar() {
    pkill -u "$(id -u)" -x 'qs|quickshell'
    local i=0
    while vivo && [ $i -lt 30 ]; do sleep 0.1; i=$((i+1)); done
}

qt_desfasado() {  # ¿se actualizó qt6-base (o declarative) después de instalar/actualizar quickshell?
    local log=/var/log/pacman.log qt qs
    [ -r "$log" ] || return 1
    qt=$(grep -nE '\] (upgraded|installed) qt6-(base|declarative) ' "$log" | tail -n1 | cut -d: -f1)
    qs=$(grep -nE '\] (upgraded|installed|reinstalled) quickshell(-git)? ' "$log" | tail -n1 | cut -d: -f1)
    [ -n "$qt" ] && [ -n "$qs" ] && [ "$qt" -gt "$qs" ]
}

reporteros() {  # la ventana de «Quickshell has crashed» es otro proceso quickshell con este entorno
    local p
    for p in $(pgrep -u "$(id -u)" -x 'qs|quickshell'); do
        tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -q '^__QUICKSHELL_CRASH_LOG_FD=' && echo "$p"
    done
}

caidas=()
demasiadas() {  # registra una caída; verdadero si ya son más de 4 en 3 minutos
    local ahora t
    ahora=$(date +%s)
    caidas=($(for t in "${caidas[@]}"; do [ $((ahora - t)) -lt 180 ] && echo "$t"; done) "$ahora")
    [ "${#caidas[@]}" -gt 4 ] || return 1
    aviso "Quickshell se cae una y otra vez" "No se vuelve a abrir solo. Revisa ~/.cache/quickshell/crashes y ábrelo con ~/.config/hypr/scripts/shell.sh"
    touch "$detenido"; caidas=()
}

guardian() {
    exec 8>"$run/orion-shell.guardian.lock"
    flock -n 8 || exit 0                       # ya hay un guardián
    local avisado_qt="" p informe i crashes="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/crashes"
    while :; do
        sleep 2 8>&-                          # el hijo no hereda el bloqueo del guardián
        for p in $(reporteros); do
            informe=$(ls -td "$crashes"/*/ 2>/dev/null | head -n1)
            i=0; while [ ! -s "${informe}report.txt" ] && [ $i -lt 20 ]; do sleep 0.5; i=$((i+1)); done
            kill "$p" 2>/dev/null
            if demasiadas; then parar; else
                aviso "Quickshell se reinició solo" "Se cerró por un error y ya vuelve a estar en marcha. Informe: ${informe%/}"
            fi
        done
        [ -e "$detenido" ] && continue
        if [ -z "$avisado_qt" ] && qt_desfasado; then
            avisado_qt=1
            aviso "Quickshell necesita recompilarse" "Qt se actualizó después que Quickshell y eso provoca caídas. Ejecuta ~/dotfiles/instalar/quickshell-recompilar.sh"
        fi
        (
            flock -w 10 9 || exit 1
            vivo && exit 1
            [ -e "$detenido" ] && exit 1
            exit 0
        ) 9>"$run/orion-shell.lock" || continue
        demasiadas && continue
        { flock -w 10 9 && ! vivo && lanzar; } 9>"$run/orion-shell.lock"
    done
}

case "${1:-}" in
    __guardian) guardian ;;
    reiniciar)
        { flock -w 10 9; rm -f "$detenido"; parar; lanzar; } 9>"$run/orion-shell.lock" ;;
    parar)
        { flock -w 10 9; touch "$detenido"; parar; } 9>"$run/orion-shell.lock" ;;
    "")
        { flock -w 10 9; rm -f "$detenido"; vivo || lanzar; } 9>"$run/orion-shell.lock" ;;
    *) echo "uso: $0 [reiniciar|parar]" >&2; exit 2 ;;
esac
# El guardián vive aparte (setsid) para no morir con quien llamó a este script
[ "${1:-}" = parar ] || [ "${1:-}" = __guardian ] || setsid -f "$0" __guardian </dev/null >/dev/null 2>&1
exit 0
