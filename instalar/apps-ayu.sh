#!/usr/bin/env bash
# Instala Vesktop (Discord con Vencord) y spicetify, y les pone el tema Ayu.
# Uso (SIN sudo; lo pide solo para Spotify):  ~/dotfiles/instalar/apps-ayu.sh
# Los temas ya están enlazados con stow: dotfiles/vesktop y dotfiles/spicetify.
set -euo pipefail
[ "$EUID" -ne 0 ] || { echo "Ejecútalo SIN sudo (yay no debe ir como root)"; exit 1; }

echo "==> Paquetes de AUR"
yay -S --needed --noconfirm vesktop-bin spicetify-cli

echo "==> Vesktop: activar el tema ayu.theme.css en Vencord"
mkdir -p ~/.config/vesktop/settings
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.config/vesktop/settings/settings.json")
s = json.load(open(p)) if os.path.exists(p) else {}
temas = s.setdefault("enabledThemes", [])
if "ayu.theme.css" not in temas:
    temas.append("ayu.theme.css")
json.dump(s, open(p, "w"), indent=4)
print("   enabledThemes:", temas)
PY

echo "==> Spotify (flatpak): permisos de escritura para spicetify"
SP=/var/lib/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify
PREFS=~/.var/app/com.spotify.Client/config/spotify/prefs
flatpak kill com.spotify.Client 2>/dev/null || true
sudo chmod a+wr "$SP"
sudo chmod a+wr -R "$SP/Apps"

echo "==> spicetify: tema Ayu"
spicetify config spotify_path "$SP" prefs_path "$PREFS" \
    current_theme Ayu color_scheme ayu inject_css 1 replace_colors 1
spicetify backup apply

echo
echo "Listo. Abre Vesktop desde fuzzel (SUPER+R) e inicia sesión."
echo "Spotify ya tiene el tema. Tras cada actualización de Spotify (flatpak update):"
echo "   sudo chmod a+wr $SP && sudo chmod a+wr -R $SP/Apps && spicetify backup apply"
