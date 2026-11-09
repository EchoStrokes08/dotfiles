#!/usr/bin/env bash
# OCR: seleccionas una zona de la pantalla y su TEXTO queda copiado (SUPER+SHIFT+X o menú de capturas).
# Sirve para PDFs escaneados, vídeos, fotos de la pizarra, imágenes con texto… Funciona sin internet.
#   ocr.sh            → español + inglés
#   ocr.sh eng        → otro idioma de tesseract (tesseract --list-langs)
# Truco: la zona se captura al doble de resolución (grim -s 2): tesseract acierta mucho más con letra grande.
IDIOMAS=${1:-spa+eng}

geo=$(slurp -b 0e141988 -c 36a3d9ff -w 2) || exit 0     # borde azul: se distingue de una captura normal
texto=$(grim -s 2 -g "$geo" - | tesseract stdin stdout -l "$IDIOMAS" 2>/dev/null \
        | sed -e 's/[[:space:]]*$//' | cat -s | sed -e '/./,$!d')   # sin espacios al final ni líneas vacías de más

if [ -z "${texto//[[:space:]]/}" ]; then
    notify-send -a OCR -u low "No encontré texto" "Prueba con una zona más grande o con más contraste"
    exit 1
fi
printf '%s' "$texto" | wl-copy
palabras=$(wc -w <<<"$texto")
notify-send -a OCR "Texto copiado ($palabras palabras)" "$(head -c 220 <<<"$texto")$( [ ${#texto} -gt 220 ] && echo '…')"
