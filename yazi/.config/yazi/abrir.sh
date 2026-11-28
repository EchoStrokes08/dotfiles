#!/usr/bin/env bash
# Opener de yazi: abre el archivo con su app por defecto.
#  - Si yazi está en el scratchpad de archivos (SUPER+SHIFT+E), primero lo esconde:
#    si no, la app nueva se abriría dentro del scratchpad, tapada por yazi.
#  - El tipo se averigua con gio (por extensión + contenido), que acierta donde `file`
#    falla (un .pptx no es «un zip», un .circ no es «un xml»).
#  - Si no hay app por defecto, o falla, sale un menú «Abrir con» (fuzzel).
#  abrir.sh --elegir ARCHIVO   fuerza el menú.
elegir=0
[ "$1" = "--elegir" ] && { elegir=1; shift; }
f="$1"
[ -e "$f" ] || exit 1

if hyprctl monitors -j 2>/dev/null | grep -q '"name": "special:archivos"'; then
    hyprctl eval 'hl.dispatch(hl.dsp.workspace.toggle_special("archivos"))' >/dev/null 2>&1
fi

mime=$(gio info -a standard::content-type "$f" 2>/dev/null | sed -n 's/.*standard::content-type: //p')

# Apps registradas para ese tipo (ids .desktop), sin repetir
apps() {
    gio mime "$mime" 2>/dev/null | grep -oE '[^[:space:]]+\.desktop' | awk '!v[$0]++'
}

nombre_app() {
    local d
    for d in ~/.local/share/applications /usr/share/applications; do
        [ -f "$d/$1" ] && { sed -n 's/^Name=//p' "$d/$1" | head -1; return; }
    done
    echo "${1%.desktop}"
}

lanzar() { setsid -f "$@" >/dev/null 2>&1; }

menu() {
    local lineas=() ids=() id op
    while read -r id; do
        [ -n "$id" ] || continue
        ids+=("$id"); lineas+=("$(nombre_app "$id")")
    done < <(apps)
    lineas+=("Neovim (terminal)" "VS Code" "LibreOffice" "Mostrar en Thunar")
    op=$(printf '%s\n' "${lineas[@]}" | fuzzel --dmenu --index \
        --prompt "Abrir $(basename "$f") con: " 2>/dev/null) || exit 0
    if [ "$op" -lt "${#ids[@]}" ]; then
        lanzar gtk-launch "${ids[$op]}" "$f"
        return
    fi
    case "${lineas[$op]}" in
        "Neovim (terminal)") lanzar kitty -e nvim "$f" ;;
        "VS Code")           lanzar code "$f" ;;
        "LibreOffice")       lanzar libreoffice "$f" ;;
        "Mostrar en Thunar") lanzar thunar "$(dirname "$f")" ;;
    esac
}

[ $elegir = 1 ] && { menu; exit; }

# ¿Hay app por defecto? gio open la usa (y entiende los subtipos); si falla, menú
if [ -n "$(xdg-mime query default "$mime" 2>/dev/null)" ] || [ -n "$(apps | head -1)" ]; then
    if gio open "$f" 2>/dev/null; then
        exit 0
    fi
fi
notify-send -a Archivos -i dialog-question "Sin programa para $(basename "$f")" "Tipo: ${mime:-desconocido}. Elige con qué abrirlo." 2>/dev/null
menu
