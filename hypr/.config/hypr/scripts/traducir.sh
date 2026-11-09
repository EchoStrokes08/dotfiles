#!/usr/bin/env bash
# Traducir (SUPER+ALT+T): traduce el texto SELECCIONADO (basta con marcarlo con el ratón; si no hay
# selección, usa el portapapeles). Otro idioma → español; si ya está en español → inglés.
# La traducción sale en una notificación y queda copiada. Usa translate-shell (necesita internet).
#   traducir.sh [idioma]   forzar el idioma de destino (en, fr, pt…)
texto=$(wl-paste -p -n 2>/dev/null); [ -z "${texto//[[:space:]]/}" ] && texto=$(wl-paste -n 2>/dev/null)
if [ -z "${texto//[[:space:]]/}" ]; then
    notify-send -a Traducir -u low "Nada que traducir" "Selecciona un texto con el ratón y vuelve a pulsar SUPER+ALT+T"; exit 1
fi
texto=${texto:0:4000}

destino=$1
if [ -z "$destino" ]; then
    origen=$(trans -b -id "$texto" 2>/dev/null | awk -F'\t' 'NR==1{print $1}')   # código del idioma detectado
    [ "$origen" = es ] && destino=en || destino=es
fi
traduccion=$(trans -b -no-autocorrect ":$destino" "$texto" 2>/dev/null)
if [ -z "$traduccion" ]; then
    notify-send -a Traducir "No se pudo traducir" "¿Hay internet?"; exit 1
fi
printf '%s' "$traduccion" | wl-copy
notify-send -a Traducir "→ $destino (copiado)" "$traduccion"
