#!/usr/bin/env bash
# Copia el tema activo (colores y wallpaper de tema.sh) al tema de SDDM, para que el
# inicio de sesión se vea como la pantalla de bloqueo. SDDM no puede leer tu carpeta
# personal, por eso lo hace root: sddm-tema@USUARIO.service lo llama al encender
# (antes de SDDM) y al apagar.   Uso: sudo sincronizar-sddm.sh USUARIO
set -uo pipefail
usuario="${1:?Uso: sincronizar-sddm.sh USUARIO}"
casa="$(getent passwd "$usuario" | cut -d: -f6)"
estado="$casa/.local/state/tema"
destino=/usr/share/sddm/themes/ayu-glass
[ -d "$destino" ] || { echo "No está instalado el tema $destino"; exit 0; }
[ -f "$estado/colores.css" ] || { echo "Sin $estado/colores.css: dejo el tema como está"; exit 0; }

color() {   # color NOMBRE PORDEFECTO
    local c
    c=$(grep -oP "@define-color\s+$1\s+\K#[0-9a-fA-F]{6}" "$estado/colores.css" | head -1)
    echo "${c:-$2}"
}
fondo=$(color fondo "#121519")
# claro si la luminosidad del fondo pasa de la mitad
r=$((16#${fondo:1:2})); g=$((16#${fondo:3:2})); b=$((16#${fondo:5:2}))
claro=false; [ $(( (r*299 + g*587 + b*114) / 1000 )) -gt 128 ] && claro=true

tmp=$(mktemp "$destino/.Tema.XXXXXX")
cat > "$tmp" <<QML
// Generado por sincronizar-sddm.sh desde $estado/colores.css — no editar aquí.
import QtQuick

QtObject {
    property color fondo:   "$fondo"
    property color texto:   "$(color texto "#edf0f5")"
    property color acento:  "$(color acento "#f19618")"
    property color acento2: "$(color acento2 "#36a3d9")"
    property color exito:   "$(color exito "#b8cc52")"
    property color aviso:   "$(color aviso "#e6c446")"
    property color peligro: "$(color peligro "#ff3333")"
    property color gris:    "$(color gris "#aab3c0")"
    property bool claro: $claro
}
QML
chmod 644 "$tmp" && mv -f "$tmp" "$destino/Tema.qml"

# Wallpaper: reducido a 1920x1080 (cargar uno de 4K en el login es lento)
if [ -f "$estado/wallpaper" ]; then
    tmp=$(mktemp "$destino/.fondo.XXXXXX")
    if command -v magick >/dev/null; then
        magick "$estado/wallpaper[0]" -resize 1920x1080^ -gravity center -extent 1920x1080 -quality 92 "jpg:$tmp"
    elif python3 -c "import PIL" 2>/dev/null; then
        python3 -I - "$estado/wallpaper" "$tmp" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
W, H = 1920, 1080; r = max(W / im.width, H / im.height)
im = im.resize((round(im.width * r), round(im.height * r)), Image.LANCZOS)
l = (im.width - W) // 2; t = (im.height - H) // 2
im.crop((l, t, l + W, t + H)).save(sys.argv[2], "JPEG", quality=92)
PY
    else
        cp -L "$estado/wallpaper" "$tmp"   # Qt reconoce el formato por el contenido
    fi && chmod 644 "$tmp" && mv -f "$tmp" "$destino/background.jpg" || rm -f "$tmp"
fi

# Tu foto, si tienes ~/.face
if [ -f "$casa/.face" ]; then
    install -m 644 "$casa/.face" "$destino/avatar"
else
    rm -f "$destino/avatar"
fi
echo "SDDM al día: fondo $fondo, acento $(color acento ?), claro=$claro"
