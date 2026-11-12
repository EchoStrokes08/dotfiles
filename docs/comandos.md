# Comandos y atajos

Todo lo que se puede hacer con esta configuración: atajos de teclado de Hyprland, scripts, comandos IPC de Quickshell, terminal e instaladores.

> `SUPER` es la tecla Windows (se cambia en `hypr/.config/hypr/modulos/programas.lua`).
> Los atajos están en `hypr/.config/hypr/modulos/atajos.lua`, `submaps.lua`, `modo_juego.lua` y `tema.lua`.

## Índice

- [Atajos de teclado](#atajos-de-teclado)
  - [Apps](#apps)
  - [Ventanas](#ventanas)
  - [Workspaces y foco](#workspaces-y-foco)
  - [Ratón](#ratón)
  - [Sesión](#sesión)
  - [Notificaciones y portapapeles](#notificaciones-y-portapapeles)
  - [Capturas y replay](#capturas-y-replay)
  - [Wallpapers y tema](#wallpapers-y-tema)
  - [Audífonos, energía y modo juego](#audífonos-energía-y-modo-juego)
  - [Teclas multimedia](#teclas-multimedia)
  - [Submaps (modos de teclado)](#submaps-modos-de-teclado)
- [Scripts](#scripts)
- [Quickshell (IPC)](#quickshell-ipc)
- [Hyprland desde la terminal](#hyprland-desde-la-terminal)
- [Redmi Buds](#redmi-buds)
- [Terminal (zsh)](#terminal-zsh)
- [Neovim](#neovim)
- [Instalación y mantenimiento](#instalación-y-mantenimiento)

---

## Atajos de teclado

### Apps

| Atajo | Acción |
|---|---|
| `SUPER + Q` | Terminal (kitty) |
| `SUPER + E` | Gestor de archivos (thunar) |
| `SUPER + R` | Lanzador de apps (Quickshell) |
| `SUPER + D` | Dashboard (Quickshell) |
| `SUPER + W` | WhatsApp (ZapZap): va a la ventana si ya está abierta, si no la abre |
| `SUPER + G` | Roblox (Sober, con `gamemoderun`) |
| `SUPER + B` | Buds Manager (va a la ventana o la abre) |
| `SUPER + A` → letra | Modo «lanzar», ver [submaps](#submaps-modos-de-teclado) |

### Ventanas

| Atajo | Acción |
|---|---|
| `SUPER + C` | Cerrar ventana |
| `SUPER + V` | Alternar flotante |
| `SUPER + F` | Pantalla completa |
| `SUPER + P` | Pseudo-tiling |
| `SUPER + J` | Cambiar orientación de la división (solo dwindle) |
| `SUPER + TAB` | Cambiar layout del workspace: dwindle → master → scrolling → monocle |
| `SUPER + I` | Inspector: muestra class, título, tamaño… de la ventana y copia la class |
| `SUPER + SHIFT + R` | Modo redimensionar, ver [submaps](#submaps-modos-de-teclado) |

### Workspaces y foco

| Atajo | Acción |
|---|---|
| `SUPER + ←/→/↑/↓` | Mover el foco |
| `SUPER + 1…9, 0` | Ir al workspace 1–10 (el 0 es el 10) |
| `SUPER + SHIFT + 1…9, 0` | Mover la ventana al workspace 1–10 |
| `SUPER + rueda` | Workspace siguiente / anterior |
| `SUPER + S` | Mostrar/ocultar el scratchpad «magic» |
| `SUPER + SHIFT + S` | Mandar la ventana al scratchpad |

### Ratón

| Atajo | Acción |
|---|---|
| `SUPER + clic izquierdo` | Mover ventana |
| `SUPER + clic derecho` | Redimensionar ventana |

### Sesión

| Atajo | Acción |
|---|---|
| `SUPER + L` | Bloquear pantalla (hypridle → hyprlock) |
| `SUPER + M` | Salir de Hyprland |
| `ALT + F4` | Menú de apagado (wlogout) |

### Notificaciones y portapapeles

| Atajo | Acción |
|---|---|
| `SUPER + N` | Abrir/cerrar el panel de notificaciones (swaync) |
| `SUPER + SHIFT + N` | No molestar |
| `SUPER + SHIFT + V` | Historial del portapapeles (cliphist) |

### Capturas y replay

Las capturas se guardan en `~/Imágenes/screenshots` y se copian al portapapeles. Los replays van a `~/Videos/Replays`.

| Atajo | Acción |
|---|---|
| `IMPR` | Captura de una región |
| `SUPER + IMPR` | Captura de toda la pantalla |
| `SHIFT + IMPR` | Menú de capturas: región, pantalla, ventana, temporizador 5 s |
| `SUPER + SHIFT + IMPR` | Guardar los últimos 30 s (replay) |
| `SUPER + ALT + IMPR` | Encender/apagar el replay |

### Wallpapers y tema

| Atajo | Acción |
|---|---|
| `SUPER + SHIFT + W` | Selector de wallpapers con miniaturas |
| `SUPER + CTRL + W` | Wallpaper al azar |
| `SUPER + SHIFT + T` | Alternar colores: Ayu ↔ sacados del wallpaper |

### Audífonos, energía y modo juego

| Atajo | Acción |
|---|---|
| `SUPER + SHIFT + B` | Buds: siguiente modo (ANC → transparencia → apagado) |
| `SUPER + SHIFT + P` | Modo de energía: ahorro → equilibrado → rendimiento |
| `SUPER + SHIFT + G` | Modo juego on/off (quita animaciones, blur, sombras, huecos y activa No molestar). Se activa solo al abrir Roblox |

### Teclas multimedia

Funcionan también con la pantalla bloqueada. Volumen y brillo se repiten al mantener.

| Tecla | Acción |
|---|---|
| Subir / bajar volumen | ±5 % (máximo 100 %) |
| Silenciar | Silencia la salida |
| Silenciar micrófono | Silencia el micrófono |
| Subir / bajar brillo | ±5 % + OSD |
| Play/Pausa, Siguiente, Anterior | Control de música (playerctl) + OSD |
| `Bloq Mayús` | Muestra el estado en el OSD (la tecla sigue funcionando) |

### Submaps (modos de teclado)

**Redimensionar** — `SUPER + SHIFT + R`

| Tecla | Acción |
|---|---|
| `←/→/↑/↓` | Cambiar tamaño 30 px (mantener = repetir) |
| `Esc` o `Enter` | Salir del modo |

**Lanzar** — `SUPER + A` y luego **una** letra (cualquier otra tecla cancela)

| Letra | App |
|---|---|
| `F` | Firefox |
| `T` | Terminal |
| `E` | Gestor de archivos |
| `W` | WhatsApp |
| `G` | Roblox |
| `S` | Spotify |

Si te quedas atrapado en un submap:

```bash
hyprctl dispatch 'hl.dsp.submap("reset")'
```

---

## Scripts

Todos en `~/.config/hypr/scripts/`.

| Comando | Qué hace |
|---|---|
| `tema.sh ayu` | Paleta Ayu fija |
| `tema.sh wallpaper` | Colores sacados del wallpaper actual (matugen) |
| `tema.sh alternar` | Cambia entre los dos modos |
| `tema.sh aplicar [img]` | Regenera los colores en el modo actual |
| `tema.sh estado` | Dice el modo actual |
| `wallpaper.sh` | Menú de wallpapers |
| `wallpaper.sh aleatorio` | Wallpaper al azar |
| `capturas.sh` | Menú de capturas |
| `capturas.sh region\|pantalla\|ventana\|temporizador` | Captura directa |
| `replay.sh start` | Encendido manual del replay; privacidad impide grabar |
| `replay.sh auto` | Automático: con cargador y sin privacidad ni perfil Mínimo |
| `replay.sh stop` · `estado` | Apagado manual / consultar estado |
| `replay.sh save` | Guarda los últimos 30 s |
| `replay.sh toggle` | Enciende/apaga el replay |
| `modo-energia.sh` | Pasa al siguiente modo de energía |
| `inspector.sh` | Info de la ventana activa (para window rules) |
| `calendario.sh` | Abre/cierra el calendario (clic en la hora de waybar) |
| `conmutadores.sh <cosa> estado` | Imprime `on`/`off`. `<cosa>`: `wifi`, `bluetooth`, `replay`, `rendimiento` |
| `conmutadores.sh <cosa> on\|off` | Enciende/apaga esa cosa |
| `conmutadores.sh todos` | Estado de todas, una por línea |
| `tiempo-pantalla.py` | Demonio de tiempo de pantalla (lo arranca el autostart) |
| `tiempo-pantalla.py --hoy` | Resumen de hoy en la terminal |
| `modo-juego-waybar.sh` | Estado del modo juego en JSON (para waybar) |

---

## Quickshell (IPC)

Se llaman con `qs ipc call <objetivo> <función> [args]`. Sirven para atajos, scripts o probar cosas a mano.

| Comando | Qué hace |
|---|---|
| `qs ipc call dashboard toggle` | Abrir/cerrar el dashboard |
| `qs ipc call dashboard abrir` / `cerrar` | Abrir / cerrar |
| `qs ipc call dashboard irA <n>` | Ir al workspace `n` |
| `qs ipc call lanzador toggle` | Abrir/cerrar el lanzador |
| `qs ipc call lanzador buscar <texto>` | Abrir el lanzador con un texto ya escrito |
| `qs ipc call lanzador lanzar <texto>` | Abrir directamente el primer resultado |
| `qs ipc call barra refrescar <que>` | Refrescar un módulo de la barra: `buds`, `modo-juego`, `red`, `brillo`, `todo` |
| `qs ipc call osd brillo` | Mostrar el OSD de brillo |
| `qs ipc call osd bloqMayus` | Mostrar el estado de Bloq Mayús |
| `qs ipc call osd media` | Mostrar la canción actual |
| `qs ipc call osd mensaje <texto> <icono>` | Mensaje propio en el OSD |

Ver qué objetivos hay disponibles: `qs ipc show`.

---

## Hyprland desde la terminal

| Comando | Qué hace |
|---|---|
| `hyprctl reload` | Recargar la configuración |
| `hyprctl dispatch '<expresión Lua>'` | Ejecutar un dispatcher (en 0.57 son expresiones Lua) |
| `hyprctl dispatch 'modo_juego.alternar() or hl.dsp.no_op()'` | Alternar el modo juego |
| `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` | Ejemplo: ir al workspace 3 |
| `hyprctl activewindow -j` | Info de la ventana activa |
| `hyprctl clients` / `monitors` / `devices` | Ventanas, monitores, teclados y ratones |
| `loginctl lock-session` | Bloquear la pantalla |

---

## Redmi Buds

CLI en `~/.local/bin/buds` (repo aparte). Ayuda completa: `buds --help` o `buds <subcomando> --help`.

| Comando | Qué hace |
|---|---|
| `buds status` | Todo el estado |
| `buds battery` | Batería |
| `buds mode off\|anc\|transparency\|next\|toggle\|flip` | Modo de cancelación de ruido |
| `buds strength` | Intensidad del ANC o de la transparencia |
| `buds adaptive-anc` / `personalized-anc` / `adaptive-sound` | Opciones de ANC y sonido |
| `buds eq <preset>` | Ecualizador: `standard`, `voice`, `bass`, `treble`, `volume`, `custom`, `balanced` |
| `buds eq-band 62 +4` | Ajustar una banda |
| `buds eq-curve 4 3 2 0 0 0 1 2 2 1` | Las 10 bandas de una vez |
| `buds spatial on\|head\|off\|dolby\|xiaomi` | Audio espacial |
| `buds commute off\|airplane\|transit\|train` | Viaje inmersivo |
| `buds gesture` / `cycle` | Acciones de los gestos / modos de la pulsación larga |
| `buds atajos [tecla] [acción \| cmd:<comando>]` | Qué hace la PC con cada gesto |
| `buds auto [salida\|pausa\|reanudar\|bateria\|estuche\|ruido] [on\|off]` | Automatizaciones |
| `buds dormir 30` / `buds dormir off` | Temporizador para dormir |
| `buds mic calls\|any\|never` | Cuándo usar el micrófono de los audífonos |
| `buds hold on\|off\|status` | Mantener el control en esta PC |
| `buds exposicion` | Dosis de sonido de la semana |
| `buds find` | Hacer sonar los audífonos |
| `buds backup` / `restore` | Guardar / restaurar la configuración |
| `buds auto-answer` / `multipoint` / `ear-detection` | Opciones generales |
| `buds-manager` | App gráfica |
| `buds-tray` | Icono en la bandeja |

---

## Terminal (zsh)

| Comando | Qué hace |
|---|---|
| `ls` | `eza` con iconos, carpetas primero |
| `ll` | Lista detallada con estado de git |
| `la` | Igual, incluyendo ocultos |
| `lt` | Árbol de 2 niveles |
| `cat` | `bat` sin paginador |
| `..` / `...` | Subir uno / dos directorios |
| `rz` | Recargar zsh |
| `actualizar` | `yay -Syu` |
| `zplug-actualizar` | Actualizar los plugins de zsh |

---

## Neovim

`<leader>` = Espacio.

| Atajo | Modo | Acción |
|---|---|---|
| `Espacio w` | normal | Guardar |
| `Espacio q` | normal | Salir |
| `Espacio e` | normal | Explorador de archivos (netrw) |
| `Esc` | normal | Quitar el resaltado de búsqueda |
| `J` / `K` | visual | Mover la selección abajo / arriba |

---

## Instalación y mantenimiento

| Comando | Qué hace |
|---|---|
| `bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)` | Instalar todo en un Arch nuevo |
| `~/dotfiles/instalar.sh` | Reinstalar / completar (idempotente) |
| `~/dotfiles/instalar.sh --simular` | Mostrar lo que haría sin cambiar nada |
| `~/dotfiles/instalar.sh --sin-sistema` | Solo tu usuario (no toca `/etc`, servicios, GRUB ni Plymouth) |
| `~/dotfiles/instalar.sh --solo <paso>` | Un solo paso: `repos`, `paquetes`, `aur`, `flatpak`, `dotfiles`, `tema`, `buds`, `sistema`, `arranque`, `apps` |
| `~/dotfiles/instalar/actualizar-listas.sh` | Regenerar las listas de paquetes desde este sistema |
| `~/dotfiles/instalar/apps-ayu.sh` | Instalar Vesktop y spicetify con el tema Ayu (sin sudo) |
| `sudo ~/dotfiles/grub/install.sh` | Instalar el tema de GRUB |
| `~/.config/hypr/temas-arranque/instalar.sh` | Temas de SDDM y GRUB |
| `sudo ~/.config/hypr/temas-arranque/instalar-plymouth-osd.sh` | Plymouth con el tema Ayu Glass |
| `cd ~/dotfiles && stow <paquete>` | Enlazar un paquete de configuración (`hypr`, `quickshell`, `zsh`…) |


### Centro del escritorio

`SUPER+CTRL+ESPACIO` abre el centro; `SUPER+CTRL+P` alterna privacidad.
El perfil de la barra también es un botón. Dentro del centro, Alt+1…4 selecciona perfil.
Consulta la [guía completa](escritorio-avanzado.md) para checkpoints, deshacer, automatizaciones
combinadas y comandos de diagnóstico.


### Mesa de trabajo

| Atajo | Acción |
|---|---|
| `SUPER+ALT+ESPACIO` | Buscar, previsualizar, mover y aparcar ventanas |
| `SUPER+CTRL+V` | Biblioteca de plantillas de texto |
| `Ctrl+1…4`, dentro de la mesa | Ventanas / plantillas / reunión / rutinas |

Consulta la [guía de la mesa](mesa-de-trabajo.md) para las reuniones, micrófono, rutinas y comandos.


### Continuidad y acciones

| Atajo | Acción |
|---|---|
| `SUPER+CTRL+Enter` | Guardar y retomar proyectos y su próxima tarea |
| `SUPER+CTRL+O` | Previsualizar y aplicar un layout por tarea |
| `SUPER+ALT+C` | Capturar texto seleccionado y elegir una acción |

[Guía, alcance de la recuperación y privacidad](flujo-de-trabajo.md).
