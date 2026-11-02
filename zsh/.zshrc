# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob notify
unsetopt beep
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/oscar/.zshrc'

autoload -Uz compinit
compinit
bindkey "^[[3~" delete-char


#Node JS
export PATH=$HOME/.npm-global/bin:$PATH

# End of lines added by compinstall
export PATH=$HOME/.local/bin:$PATH

# Prompt bonito (colores Ayu), en dos líneas:
#   ~/ruta/actual          <- arriba, en cursiva y color menta
#   ✦ orion ❯              <- abajo, el nombre del equipo en morado
PROMPT=$'\n%F{#95E6CB}%{\e[3m%}%~%{\e[23m%}%f\n%F{#D2A6FF}✦ %B'"${(L)HOST}"$'%b%f %F{#E6B450}❯%f '
