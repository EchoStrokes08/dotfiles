# ~/.zshrc  (enlazado con stow desde ~/dotfiles/zsh)
#
# Orden importante:
#   1. opciones e historial   2. completado (compinit)   3. plugins
#   4. herramientas (fzf, zoxide)   5. alias y teclas   6. prompt (starship)
# Copia anterior: ~/dotfiles/zsh/.zshrc.bak-20261104

# ── 1. Opciones e historial ─────────────────────────────────────────────
HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=50000
setopt autocd extendedglob notify interactive_comments
setopt hist_ignore_all_dups   # no guardar comandos repetidos
setopt hist_ignore_space      # un comando que empieza con espacio no se guarda
setopt hist_reduce_blanks
setopt share_history          # el historial se comparte entre terminales abiertas
unsetopt beep
bindkey -e                    # teclas estilo emacs (Ctrl+A, Ctrl+E…)

export PATH=$HOME/.npm-global/bin:$HOME/.local/bin:$PATH
export EDITOR=nvim
export HOST_MIN=${(L)HOST}     # "orion" en minúsculas para el prompt
export BAT_THEME=ansi         # bat usa los 16 colores de kitty → sigue al tema
export MANPAGER="sh -c 'col -bx | bat -l man -p'"   # páginas man con colores
export MANROFFOPT="-c"

# ── 2. Completado ───────────────────────────────────────────────────────
autoload -Uz compinit
compinit -d ~/.cache/zcompdump
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # sin distinguir mayúsculas
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no                               # el menú lo pone fzf-tab
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --icons --color=always $realpath'

# ── 3. Plugins ──────────────────────────────────────────────────────────
# Gestor mínimo hecho a mano: si el plugin no está, lo clona de GitHub.
# En un Arch nuevo basta con abrir una terminal y se instalan solos.
ZPLUGINS=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins
plugin() {
  local repo=$1 nombre=${1:t}          # ${1:t} = la parte tras la última "/"
  if [[ ! -d $ZPLUGINS/$nombre ]]; then
    print -P "%F{3}zsh:%f instalando $nombre…"
    git clone --depth 1 -q https://github.com/$repo $ZPLUGINS/$nombre || return
  fi
  source $ZPLUGINS/$nombre/$nombre.plugin.zsh
}
# Actualizar todos los plugins: escribe  zplug-actualizar
zplug-actualizar() { for d in $ZPLUGINS/*(/); do print "→ ${d:t}"; git -C $d pull -q; done }

plugin Aloxaf/fzf-tab                           # Tab abre un menú fzf (va justo tras compinit)
plugin zsh-users/zsh-autosuggestions            # sugerencia gris del historial; → la acepta
plugin zsh-users/zsh-syntax-highlighting        # comando en verde si existe, rojo si no
plugin zsh-users/zsh-history-substring-search   # ↑/↓ buscan lo que ya escribiste (va el último)

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'

# ── 4. fzf y zoxide ─────────────────────────────────────────────────────
# Colores con números ANSI (0-15): fzf toma los de kitty, igual que bat.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--layout=reverse --border=rounded --height=50% --info=inline-right
  --prompt="❯ " --pointer="▶" --marker="✓"
  --color=fg:-1,bg:-1,hl:3,fg+:15,bg+:0,hl+:11,info:6,prompt:3,pointer:3,marker:2,spinner:5,header:4,border:8'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :200 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"
source <(fzf --zsh)            # Ctrl+R historial · Ctrl+T archivos · Alt+C carpetas

eval "$(zoxide init zsh --cmd cd)"   # cd aprende tus carpetas: "cd dot" → ~/dotfiles; cdi = menú

# ── 5. Alias y teclas ───────────────────────────────────────────────────
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git -h --group-directories-first'
alias la='eza -la --icons --git -h --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'      # en tuberías se porta como el cat normal
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias rz='exec zsh'                 # recargar zsh tras editar este archivo
alias actualizar='yay -Syu'

# y: abre yazi (gestor de archivos) y al salir con q te deja en la carpeta donde estabas
# (Q sale sin cambiar de carpeta). yazi escribe la carpeta final en un archivo temporal.
y() {
    local tmp="$(mktemp -t yazi-cwd.XXXXXX)" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

# sudo con envío automático: la contraseña se comprueba sola al escribir su último carácter.
# Comparte la longitud aprendida con la pantalla de bloqueo (~/.local/state/bloqueo/longitud;
# nunca se guarda la clave). Si cambias de contraseña: Enter una vez y la aprende. Si la nueva es
# más larga, fallará una vez a la longitud vieja y desde ahí espera Enter.
sudo() {
  local f=~/.local/state/bloqueo/longitud
  # sin terminal, opciones raras o ya autenticado (sudo recuerda 5 min) → el sudo de siempre
  if [[ ! -t 0 || ! -t 2 || $1 == -[kKSnvlAh]* ]] || command sudo -n true 2>/dev/null; then
    command sudo "$@"; return
  fi
  local n=0 auto=1 pw c intento
  [[ -r $f ]] && n=$(<$f)
  [[ $n == <-> ]] || n=0
  for intento in 1 2 3; do
    pw=""
    printf '[sudo] contraseña para %s: ' "$USER" >&2
    while read -rsk1 c; do
      case $c in
        $'\n'|$'\r') break ;;
        $'\x7f'|$'\b') pw=${pw%?} ;;      # Retroceso
        $'\x15') pw="" ;;                 # Ctrl+U
        *) pw+=$c; (( auto && n > 0 && ${#pw} == n )) && { auto=2; break } ;;
      esac
    done
    printf '\n' >&2
    [[ -z $pw ]] && continue
    if printf '%s\n' "$pw" | command sudo -S -p '' -v 2>/dev/null; then
      if (( ${#pw} != n )); then          # aprende la longitud nueva
        mkdir -p ${f:h} && chmod 700 ${f:h} && print ${#pw} > $f
      fi
      pw=""; command sudo "$@"; return
    fi
    (( auto == 2 )) && auto=0             # falló el envío automático: ¿contraseña nueva? → Enter
    print -P '%F{red}Contraseña incorrecta.%f' >&2
  done
  pw=""; return 1
}

bindkey '^[[3~'    delete-char            # Supr
bindkey '^[[H'     beginning-of-line      # Inicio
bindkey '^[[F'     end-of-line            # Fin
bindkey '^[[1;5C'  forward-word           # Ctrl+→
bindkey '^[[1;5D'  backward-word          # Ctrl+←
bindkey '^H'       backward-kill-word     # Ctrl+Retroceso
bindkey '^ '       autosuggest-accept     # Ctrl+Espacio acepta la sugerencia
bindkey '^[[A'     history-substring-search-up
bindkey '^[[B'     history-substring-search-down
bindkey '^[OA'     history-substring-search-up
bindkey '^[OB'     history-substring-search-down

# ── 6. Prompt y bienvenida ──────────────────────────────────────────────
eval "$(starship init zsh)"          # config: ~/.config/starship.toml

# fastfetch solo en una kitty interactiva (no en scripts ni dentro de nvim)
[[ -o interactive && $TERM == xterm-kitty && -z $NVIM ]] && fastfetch
