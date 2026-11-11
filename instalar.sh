#!/usr/bin/env bash
# instalar.sh: reinstala todo el escritorio (Hyprland + Ayu) en un Arch recién instalado.
#
# En un Arch nuevo (con internet y un usuario con sudo), UN solo comando:
#   bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)
# Si el repo ya está clonado:
#   ~/dotfiles/instalar.sh [--simular] [--sin-sistema] [--solo PASO]
#
#   --simular      muestra lo que haría, sin cambiar nada
#   --sin-sistema  no toca /etc, servicios, GRUB ni Plymouth (solo tu usuario)
#   --solo PASO    corre un único paso: repos paquetes aur flatpak dotfiles tema buds sistema base arranque apps
#
# Es idempotente: correrlo dos veces no rompe nada, salta lo que ya está hecho.
# Los archivos que estorben a stow se mueven a ~/.respaldo-dotfiles-FECHA/ (nunca se borran).
set -uo pipefail

REPO_URL="https://github.com/EchoStrokes08/dotfiles.git"
BUDS_URL="https://github.com/EchoStrokes08/Buds-Manager.git"
DOT="$HOME/dotfiles"
FECHA=$(date +%Y%m%d-%H%M%S)
RESPALDO="$HOME/.respaldo-dotfiles-$FECHA"
ARGS=("$@")

SIMULAR=0; SISTEMA=1; SOLO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --simular)     SIMULAR=1 ;;
        --sin-sistema) SISTEMA=0 ;;
        --solo)        SOLO="${2:?falta el nombre del paso}"; shift ;;
        -h|--help)     sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "Opción desconocida: $1 (usa --help)"; exit 1 ;;
    esac
    shift
done

if [ -n "$SOLO" ]; then
    case " $SOLO " in
        ' repos '|' paquetes '|' aur '|' flatpak '|' dotfiles '|' tema '|' buds '|' sistema '|' base '|' arranque '|' apps ') ;;
        *) echo "Paso desconocido: $SOLO"; exit 2 ;;
    esac
fi

# ── Utilidades ──────────────────────────────────────────────────────────
B=$'\e[1m'; NAR=$'\e[38;2;241;150;24m'; VER=$'\e[38;2;184;204;82m'; ROJ=$'\e[38;2;255;51;51m'; R=$'\e[0m'
AVISOS=()
paso()  { printf '\n%s==> %s%s\n' "$NAR$B" "$*" "$R"; }
ok()    { printf '%s  ✓ %s%s\n' "$VER" "$*" "$R"; }
aviso() { printf '%s  ! %s%s\n' "$ROJ" "$*" "$R"; AVISOS+=("$*"); }
run() {  # ejecuta el comando, o con --simular solo lo enseña
    if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s %s\n' "$B" "$R" "$*" >&2; return 0; fi
    "$@"
}
toca()  { [ -z "$SOLO" ] || [ "$SOLO" = "$1" ]; }
lista() { grep -Ev '^[[:space:]]*(#|$)' "$DOT/instalar/$1"; }

[ "$EUID" -ne 0 ] || { echo "Ejecútalo como tu usuario, SIN sudo (lo pedirá cuando haga falta)."; exit 1; }
command -v pacman >/dev/null || { echo "Esto es para Arch Linux (no encuentro pacman)."; exit 1; }

# ── 0. Traer el repo (cuando se ejecuta con curl en un equipo nuevo) ────
if [ ! -d "$DOT/.git" ]; then
    paso "Clonando los dotfiles en $DOT"
    run sudo pacman -S --needed --noconfirm git stow || exit 1
    run git clone "$REPO_URL" "$DOT" || exit 1
    [ "$SIMULAR" = 1 ] && { echo "  (con --simular no sigo: el repo aún no existe)"; exit 0; }
    exec bash "$DOT/instalar.sh" "${ARGS[@]}"     # seguir con la versión del repo
fi

# Registro de todo lo que pasa (para revisar errores después)
if [ "$SIMULAR" = 0 ]; then
    LOG="$HOME/instalar-$FECHA.log"
    exec > >(tee -a "$LOG") 2>&1
    if [ "$SISTEMA" = 1 ]; then
        sudo -v || exit 1
        # Mantener sudo vivo mientras dura la instalación
        while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
    fi
fi

# ── 1. Repos: multilib (Steam, Wine, drivers de 32 bits) y actualizar ───
paso_repos() {
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        ok "multilib ya activo"
    else
        run sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf || return 1
        ok "multilib activado"
    fi
    run sudo pacman -Syu --noconfirm
}

# ── 2. Paquetes oficiales ───────────────────────────────────────────────
paso_paquetes() {
    local disponibles faltan=() pk=()
    disponibles=$(pacman -Slq | sort -u)
    while read -r p; do
        if grep -qxF "$p" <<<"$disponibles"; then pk+=("$p"); else faltan+=("$p"); fi
    done < <(lista paquetes.txt)
    [ ${#faltan[@]} -eq 0 ] || aviso "No existen en los repos (¿renombrados?): ${faltan[*]}"
    run sudo pacman -S --needed --noconfirm "${pk[@]}" && ok "${#pk[@]} paquetes de pacman"
}

# ── 3. AUR con yay ──────────────────────────────────────────────────────
paso_aur() {
    if ! command -v yay >/dev/null; then
        local tmp; tmp=$(mktemp -d)
        run git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" || return 1
        if [ "$SIMULAR" = 1 ]; then run makepkg -si --noconfirm; else (cd "$tmp/yay-bin" && makepkg -si --noconfirm) || return 1; fi
        ok "yay instalado"
    fi
    mapfile -t aur < <(lista aur.txt)
    run yay -S --needed --noconfirm "${aur[@]}" && ok "${#aur[@]} paquetes del AUR"
}

# ── 4. Flatpak ──────────────────────────────────────────────────────────
paso_flatpak() {
    run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    mapfile -t fp < <(lista flatpak.txt)
    run sudo flatpak install -y --noninteractive flathub "${fp[@]}" && ok "${#fp[@]} apps de Flathub"
}

# ── 5. Dotfiles con stow ────────────────────────────────────────────────
STOW=(zsh kitty hypr waybar swaync swayosd fuzzel gtk tema btop nvim vscode wallpapers quickshell udiskie yazi satty lugares)
STOW_SIN_PLEGAR=(vesktop spicetify easyeffects)   # solo enlaza archivos: la app escribe caché en su carpeta

respaldar() {  # respaldar PAQUETE [opciones de stow]: aparta los archivos reales que estorban
    local pkg=$1; shift
    stow -n -v "$@" -d "$DOT" -t "$HOME" "$pkg" 2>&1 \
      | sed -nE 's/.*over existing target (.+) since .*/\1/p' \
      | while IFS= read -r f; do
            run mkdir -p "$RESPALDO/$(dirname "$f")"
            run mv "$HOME/$f" "$RESPALDO/$f"
            echo "  respaldado: ~/$f → $RESPALDO/"
        done
}

firefox_perfil() {  # ruta del perfil por defecto de Firefox (nombre aleatorio en cada equipo)
    local base ini p
    for base in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        ini="$base/profiles.ini"; [ -f "$ini" ] || continue
        p=$(awk -F= '/^\[Install/{i=1} i && /^Default=/{print $2; exit}' "$ini")
        [ -n "$p" ] && { echo "$base/$p"; return 0; }
    done
    return 1
}

paso_dotfiles() {
    local pkg
    for pkg in "${STOW[@]}"; do
        respaldar "$pkg"
        run stow -R -d "$DOT" -t "$HOME" "$pkg" && ok "stow $pkg"
    done
    for pkg in "${STOW_SIN_PLEGAR[@]}"; do
        respaldar "$pkg" --no-folding
        run stow -R --no-folding -d "$DOT" -t "$HOME" "$pkg" && ok "stow $pkg (sin plegar)"
    done

    # Firefox: el perfil se llama distinto en cada equipo → enlazar a mano en el que haya
    local src="$DOT/firefox/.config/mozilla/firefox/skxgxs8p.default-release" perfil
    if ! perfil=$(firefox_perfil) && [ "$SIMULAR" = 0 ] && command -v firefox >/dev/null; then
        echo "  creando el perfil de Firefox (arranque oculto)…"
        timeout 20 firefox --headless about:blank >/dev/null 2>&1
        perfil=$(firefox_perfil)
    fi
    if [ -n "${perfil:-}" ]; then
        if [ -e "$perfil/chrome" ] && [ ! -L "$perfil/chrome" ]; then
            run mkdir -p "$RESPALDO" && run mv "$perfil/chrome" "$RESPALDO/firefox-chrome"
        fi
        run ln -sfn "$src/chrome" "$perfil/chrome"
        run ln -sf "$src/user.js" "$perfil/user.js"
        ok "Firefox: userChrome en ${perfil##*/}"
    else
        aviso "Firefox: no encontré perfil. Ábrelo una vez y corre: ~/dotfiles/instalar.sh --solo dotfiles"
    fi
}

# ── 6. Paleta inicial (tema.sh necesita una sesión de Hyprland; aquí basta copiar Ayu)
paso_tema() {
    local st="$HOME/.local/state/tema"
    if [ -f "$st/modo" ]; then ok "paleta ya creada (modo $(cat "$st/modo"))"; return 0; fi
    run mkdir -p "$st"
    run cp "$HOME/.config/tema/ayu/"* "$st/"
    run sh -c "echo ayu > '$st/modo'"
    run ln -sfn "$HOME/Imágenes/wallpapers/galaxia.jpg" "$st/wallpaper"
    ok "paleta Ayu y fondo galaxia.jpg"
}

# ── 7. Buds Manager (repo aparte) ───────────────────────────────────────
paso_buds() {
    local dir="$HOME/proyectos/redmi-buds"
    if [ ! -d "$dir/.git" ]; then
        run mkdir -p "$HOME/proyectos"
        run git clone "$BUDS_URL" "$dir" || { aviso "No pude clonar Buds Manager"; return 1; }
    fi
    run "$dir/install.sh" && ok "Buds Manager"
}

# ── 8. Sistema: servicios, shell y apariencia GTK ───────────────────────
paso_sistema() {
    local s
    for s in NetworkManager.service bluetooth.service power-profiles-daemon.service sddm.service \
             systemd-timesyncd.service fstrim.timer reflector.timer; do
        run sudo systemctl enable --quiet "$s" && ok "servicio $s" || aviso "no pude activar $s"
    done
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]; then
        run sudo chsh -s /usr/bin/zsh "$USER" && ok "zsh como shell"
    else ok "zsh ya es tu shell"; fi
    run xdg-user-dirs-update
    # Las notificaciones las sirve Quickshell: que D-Bus no arranque swaync en su lugar
    run systemctl --user mask swaync.service && ok "swaync enmascarado (notificaciones en Quickshell)"
    # Lo que leen GTK4, los portales y Firefox (nwg-look guarda esto mismo)
    local g=org.gnome.desktop.interface
    { run gsettings set $g gtk-theme 'adw-gtk3-dark' &&
      run gsettings set $g icon-theme 'Papirus-Ayu' &&
      run gsettings set $g cursor-theme 'Bibata-Modern-Amber' &&
      run gsettings set $g cursor-size 24 &&
      run gsettings set $g color-scheme 'prefer-dark'; } && ok "tema GTK, iconos y cursor" \
      || aviso "gsettings falló (sin sesión gráfica): repite con --solo sistema dentro de Hyprland"
}

# ── 9. Arranque: SDDM, GRUB y Plymouth con el tema Ayu ──────────────────
paso_arranque() {
    local t="$DOT/hypr/.config/hypr/temas-arranque"
    if [ ! -d /boot/grub ]; then
        aviso "No uso GRUB en este equipo: salto los temas de GRUB/SDDM/Plymouth"
        return 0
    fi
    run sudo "$t/instalar.sh"               && ok "SDDM y GRUB"    || aviso "falló temas-arranque/instalar.sh"
    run sudo "$t/instalar-plymouth-osd.sh"  && ok "Plymouth"        || aviso "falló instalar-plymouth-osd.sh"
}

# ── 10. Apps: VS Code, Vesktop y Spotify ────────────────────────────────
paso_apps() {
    command -v code >/dev/null && run code --install-extension teabyii.ayu >/dev/null && ok "VS Code: Ayu"
    run "$DOT/instalar/apps-ayu.sh"
}

# ── Orden de los pasos ──────────────────────────────────────────────────
echo "${NAR}${B}Instalador de dotfiles: Hyprland + Ayu${R}  ($([ $SIMULAR = 1 ] && echo simulación || echo en serio))"
toca repos    && [ $SISTEMA = 1 ] && { paso "Repos";            paso_repos    || aviso "paso repos con errores"; }
toca paquetes && [ $SISTEMA = 1 ] && { paso "Paquetes";         paso_paquetes || aviso "paso paquetes con errores"; }
toca aur      && [ $SISTEMA = 1 ] && { paso "AUR";              paso_aur      || aviso "paso aur con errores"; }
toca flatpak  && [ $SISTEMA = 1 ] && { paso "Flatpak";          paso_flatpak  || aviso "paso flatpak con errores"; }
toca dotfiles &&                     { paso "Dotfiles (stow)";  paso_dotfiles || aviso "paso dotfiles con errores"; }
toca tema     &&                     { paso "Paleta";           paso_tema     || aviso "paso tema con errores"; }
toca buds     &&                     { paso "Buds Manager";     paso_buds     || aviso "paso buds con errores"; }
toca sistema  && [ $SISTEMA = 1 ] && { paso "Sistema";          paso_sistema  || aviso "paso sistema con errores"; }
toca base     && [ $SISTEMA = 1 ] && { paso "Sistema base";     run "$DOT/instalar/sistema-base.sh" $([ $SIMULAR = 1 ] && echo --simular) || aviso "paso base con errores"; }
toca arranque && [ $SISTEMA = 1 ] && { paso "Arranque";         paso_arranque || aviso "paso arranque con errores"; }
toca apps     &&                     { paso "Apps";             paso_apps     || aviso "paso apps con errores"; }

paso "Resumen"
if [ ${#AVISOS[@]} -eq 0 ]; then ok "Todo en orden"
else printf '%s  Revisa:%s\n' "$ROJ" "$R"; printf '   - %s\n' "${AVISOS[@]}"; fi
[ -d "$RESPALDO" ] && echo "  Archivos apartados: $RESPALDO"
[ "$SIMULAR" = 0 ] && echo "  Registro: $LOG" && echo "  Reinicia para entrar a Hyprland con todo listo."

# El resultado representa los avisos acumulados, también en simulación.
[ ${#AVISOS[@]} -eq 0 ]
