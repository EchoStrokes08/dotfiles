#!/usr/bin/env bash
# Guarda en el historial (cliphist) lo que se copia, salvo lo que parece un secreto.
#   wl-paste --type text  --watch portapapeles-guardar.sh texto
#   wl-paste --type image --watch portapapeles-guardar.sh imagen
# No se guarda:
#   · lo que un gestor de contraseñas marca como secreto (x-kde-passwordManagerHint: Bitwarden, KeePassXC…)
#   · texto con forma de clave de API, token o clave privada (Google, Groq, OpenAI, GitHub, AWS, Slack, JWT)
# El contenido llega por la entrada estándar. «portapapeles-guardar.sh probar» lee un texto y dice si se guardaría.

SECRETO='(AQ\.[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,}|gsk_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

es_secreto() { grep -qE "(^|[^A-Za-z0-9_-])$SECRETO" <<<"$1"; }

case "${1:-texto}" in
    probar)
        es_secreto "$(cat)" && echo "secreto: no se guarda" || echo "se guarda" ;;
    imagen)
        exec cliphist store ;;
    *)
        # El gestor de contraseñas avisa con un tipo propio en el mismo portapapeles
        if wl-paste --list-types 2>/dev/null | grep -qx 'x-kde-passwordManagerHint' \
           && [ "$(wl-paste --type x-kde-passwordManagerHint 2>/dev/null)" = secret ]; then
            exit 0
        fi
        contenido=$(cat; printf x); contenido=${contenido%x}   # conserva los saltos de línea finales
        es_secreto "$contenido" && exit 0
        printf '%s' "$contenido" | cliphist store ;;
esac
