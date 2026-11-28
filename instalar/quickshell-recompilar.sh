#!/usr/bin/env bash
# quickshell-recompilar.sh: recompila el paquete quickshell de Arch contra el Qt instalado.
# Por qué: Quickshell usa APIs privadas de Qt. Si Qt se actualiza (p. ej. 6.12.0 → 6.12.1) y Arch aún no ha
# recompilado quickshell, el log avisa «built against Qt X but the system has updated» y se cae (SIGSEGV
# al ocultar ventanas, 26-nov). El guardián de scripts/shell.sh avisa cuando hace falta ejecutar esto.
# Uso (SIN sudo; lo pide él al instalar):  ~/dotfiles/instalar/quickshell-recompilar.sh [--simular]
# Usa el PKGBUILD oficial (gitlab.archlinux.org), misma versión: pacman lo ve como reinstalación y la
# siguiente versión del repositorio lo sustituye con normalidad. Después reinicia Quickshell.
set -uo pipefail

SIMULAR=0; [ "${1:-}" = "--simular" ] && SIMULAR=1
B=$'\e[1m'; NAR=$'\e[38;2;241;150;24m'; VER=$'\e[38;2;184;204;82m'; ROJ=$'\e[38;2;255;51;51m'; R=$'\e[0m'
paso()  { printf '\n%s==> %s%s\n' "$NAR$B" "$*" "$R"; }
ok()    { printf '%s  ✓ %s%s\n' "$VER" "$*" "$R"; }
aviso() { printf '%s  ! %s%s\n' "$ROJ" "$*" "$R"; }
run() { if [ "$SIMULAR" = 1 ]; then printf '  %s[simular]%s %s\n' "$B" "$R" "$*"; return 0; fi; "$@"; }

[ "$EUID" -ne 0 ] || { echo "Ejecútalo SIN sudo (lo pedirá cuando haga falta)."; exit 1; }
DIR="${XDG_CACHE_HOME:-$HOME/.cache}/orion/quickshell-pkg"

paso "PKGBUILD oficial de quickshell"
if [ -d "$DIR/.git" ]; then run git -C "$DIR" pull --ff-only -q && ok "actualizado"
else run mkdir -p "${DIR%/*}" && run git clone -q https://gitlab.archlinux.org/archlinux/packaging/packages/quickshell.git "$DIR" && ok "descargado"; fi

paso "Compilar contra Qt $(pacman -Q qt6-base 2>/dev/null | cut -d' ' -f2)"
[ "$SIMULAR" = 1 ] || cd "$DIR" || exit 1
run makepkg -sf --noconfirm --needed || { aviso "la compilación falló"; exit 1; }
paquete=$([ "$SIMULAR" = 1 ] || makepkg --packagelist 2>/dev/null | grep -v -- '-debug-' | head -n1)
ok "${paquete:-paquete listo}"

paso "Instalar"
run sudo pacman -U --noconfirm "${paquete:-quickshell.pkg.tar.zst}" && ok "instalado"

paso "Reiniciar Quickshell"
run ~/.config/hypr/scripts/shell.sh reiniciar && ok "listo"
