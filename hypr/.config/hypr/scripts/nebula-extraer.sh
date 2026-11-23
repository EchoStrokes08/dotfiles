#!/usr/bin/env bash
# Nebula sin FUSE: extrae ~/.local/opt/nebula/Nebula.AppImage en ~/.local/opt/nebula/app y lanza desde ahí.
#   Por qué: un AppImage corre montado con FUSE. Al suspender, el sistema congela primero el proceso FUSE
#   y Nebula se queda esperando a leer su propio código: no se deja congelar y la suspensión se cancela
#   (pasó el 22-11-2026: «Freezing user space processes failed … task:nebula state:D»).
# Cuándo corre: solo, cada vez que cambia el .AppImage (nebula-extraer.path). Para actualizar Nebula
#   basta con reemplazar el .AppImage como siempre; si Nebula está abierta, ciérrala y ábrela de nuevo.
# A mano:  ~/.config/hypr/scripts/nebula-extraer.sh   (no hace nada si ya está extraída esa versión)
# Volver al AppImage: systemctl --user disable --now nebula-extraer.path y poner en nebula.desktop
#   Exec="…/Nebula.AppImage" %U
set -euo pipefail

DIR="$HOME/.local/opt/nebula"
APPIMAGE="$DIR/Nebula.AppImage"
APP="$DIR/app"
DESKTOP="$HOME/.local/share/applications/nebula.desktop"

[ -f "$APPIMAGE" ] || { echo "No existe $APPIMAGE" >&2; exit 1; }

# Huella del AppImage (tamaño + fecha): si ya extrajimos este mismo archivo, no se repite.
huella=$(stat -c '%s %Y' "$APPIMAGE")
if [ -x "$APP/AppRun" ] && [ "$(cat "$APP/.origen" 2>/dev/null)" = "$huella" ]; then
    extraida=0
else
    chmod +x "$APPIMAGE"
    # La copia anterior se guarda hasta la próxima actualización: si Nebula sigue abierta desde ella,
    # no se le borran archivos que aún puede necesitar.
    rm -rf "$DIR/app.anterior" "$DIR"/.extraer-*
    tmp=$(mktemp -d "$DIR/.extraer-XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    (cd "$tmp" && "$APPIMAGE" --appimage-extract >/dev/null)
    [ -x "$tmp/squashfs-root/AppRun" ] || { echo "La extracción no produjo AppRun" >&2; exit 1; }
    printf '%s\n' "$huella" > "$tmp/squashfs-root/.origen"
    [ -e "$APP" ] && mv "$APP" "$DIR/app.anterior"
    mv "$tmp/squashfs-root" "$APP"
    extraida=1
fi

# Lanzadores: el menú (.desktop) y ~/.local/bin/nebula apuntan a la versión extraída.
# Se revisan siempre, por si al reinstalar Nebula se regeneró el .desktop con la ruta del AppImage.
if [ -f "$DESKTOP" ]; then
    sed -i -E \
        -e "s|^Exec=.*|Exec=\"$APP/AppRun\" %U|" \
        -e "s|^TryExec=.*|TryExec=$APP/AppRun|" \
        "$DESKTOP"
fi
mkdir -p "$HOME/.local/bin"
ln -sfn "$APP/AppRun" "$HOME/.local/bin/nebula"

if [ "$extraida" = 1 ]; then
    version=$(sed -n 's/^X-AppImage-Version=//p' "$APP/nebula.desktop" 2>/dev/null || true)
    echo "Nebula extraída en $APP${version:+ (versión $version)}"
    command -v notify-send >/dev/null && notify-send -a Nebula -i nebula "Nebula actualizada" \
        "Lista para usar${version:+ (versión $version)}. Si estaba abierta, ciérrala y ábrela de nuevo." || true
fi
