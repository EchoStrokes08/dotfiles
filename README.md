# dotfiles: Hyprland + Ayu Dark Glass

Mi escritorio en Arch Linux: Hyprland 0.57 con su configuración en Lua, y todo el sistema con la
paleta **Ayu**, desde el arranque (GRUB → Plymouth → SDDM) hasta las apps. Los colores pueden
cambiar solos según el wallpaper, gracias a matugen.

## Instalar en un Arch nuevo

Solo necesitas un Arch recién instalado, con internet y un usuario con sudo. Luego, **un solo comando**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)
```

Clona este repo en `~/dotfiles` y lo instala todo: paquetes de pacman, AUR y Flatpak, enlaces con
stow, servicios, temas de arranque y apps. Puedes correrlo varias veces sin romper nada. Los archivos
que estorben se mueven a `~/.respaldo-dotfiles-FECHA/`, nunca se borran.

```bash
~/dotfiles/instalar.sh --simular        # ver qué haría, sin tocar nada
~/dotfiles/instalar.sh --sin-sistema    # solo tu usuario: sin /etc, servicios ni arranque
~/dotfiles/instalar.sh --solo dotfiles  # un único paso (repos paquetes aur flatpak dotfiles
                                        #   tema buds sistema arranque apps)
```

Cuando instales algo nuevo, actualiza las listas y haz commit:

```bash
~/dotfiles/instalar/actualizar-listas.sh
```

## Qué hay

| Paquete (stow) | Qué configura |
|---|---|
| `hypr` | Hyprland en Lua, partido en módulos (`modulos/`), scripts, hyprlock, hypridle, hyprpaper y los temas de arranque (`temas-arranque/`: SDDM, GRUB y Plymouth) |
| `tema` | Paleta Ayu y plantillas de matugen. `SUPER+SHIFT+T` cambia entre Ayu y los colores del wallpaper |
| `swaync` · `swayosd` · `fuzzel` | De respaldo: Quickshell ya hace sus funciones (los scripts vuelven a fuzzel si Quickshell no responde) |
| `waybar` | La barra anterior, de respaldo (ya no arranca; ver `modulos/autostart.lua`) |
| `quickshell` | **Barra superior** (workspaces, ventana activa, reloj, bandeja, Buds, volumen, red, brillo, batería, energía, CPU, RAM, modo juego, notificaciones) , **dashboard** SUPER+D (reloj, espacios, calendario, sistema, tiempo de pantalla, música) , **lanzador de apps** SUPER+R, **OSD** de volumen/brillo/Bloq Mayús y **notificaciones** con centro de control SUPER+N , **pantalla de bloqueo** (hyprlock de respaldo) y selectores de **wallpapers**, **portapapeles** y **capturas**, en QML |
| `kitty` · `zsh` | Terminal, prompt starship, plugins de zsh, fzf, zoxide y fastfetch |
| `gtk` | adw-gtk3 con colores Ayu e iconos Papirus-Ayu |
| `btop` · `nvim` · `vscode` · `firefox` · `vesktop` · `spicetify` | Apps con el tema Ayu |
| `wallpapers` | Mis fondos, en `~/Imágenes/wallpapers` |
| `instalar/` | Listas de paquetes y scripts de instalación (no es un paquete de stow) |

Buds Manager (para controlar los Redmi Buds desde Linux) vive en su propio repo,
[Buds-Manager](https://github.com/EchoStrokes08/Buds-Manager), y el instalador lo clona.

## Si la pantalla de bloqueo se cuelga

`Ctrl+Alt+F3`, entra con tu usuario y ejecuta `~/.config/hypr/scripts/desbloqueo-emergencia.sh`;
vuelve con `Ctrl+Alt+F1` y desbloquea con hyprlock (posible gracias a `allow_session_lock_restore`).

## Todos los comandos

Referencia completa. `SUPER` es la tecla Windows. Los atajos viven en `hypr/.config/hypr/modulos/`
(sobre todo `atajos.lua`); las funciones de Quickshell, en `quickshell/.config/quickshell/shell.qml`.

### Atajos de teclado

#### Apps

| Atajo | Acción |
|---|---|
| `SUPER+Q` | Terminal (kitty) |
| `SUPER+E` | Archivos (Thunar) |
| `SUPER+R` | Lanzador de apps (Quickshell) |
| `SUPER+W` | WhatsApp (lo enfoca si ya está abierto) |
| `SUPER+G` | Roblox (Sober, con gamemode) |
| `SUPER+B` | Buds Manager (lo enfoca si ya está abierto) |
| `SUPER+D` | Dashboard: reloj, espacios, calendario, sistema, tiempo de pantalla y música |
| `SUPER+A`, luego una letra | Modo lanzar: `F` Firefox · `T` terminal · `E` archivos · `W` WhatsApp · `G` Roblox · `S` Spotify. Cualquier otra tecla cancela |

#### Ventanas

| Atajo | Acción |
|---|---|
| `SUPER+C` | Cerrar la ventana |
| `SUPER+V` | Flotante / en mosaico |
| `SUPER+F` | Pantalla completa |
| `SUPER+P` | Pseudo-mosaico |
| `SUPER+J` | Cambiar la dirección de la división (dwindle) |
| `SUPER+TAB` | Layout del workspace: dwindle → master → scrolling → monocle |
| `SUPER+flechas` | Mover el foco |
| `SUPER+SHIFT+flechas` | Mover la ventana en esa dirección (cambia su sitio en el layout; entra o sale de un grupo vecino) |
| `SUPER+ALT+flechas` | Intercambiar la ventana con su vecina |
| `SUPER+T` | Convertir la ventana en grupo (pestañas) / deshacerlo |
| `SUPER+.` / `SUPER+,` | Pestaña siguiente / anterior del grupo |
| `SUPER+SHIFT+.` / `SUPER+SHIFT+,` | Mover la pestaña a la derecha / izquierda |
| `SUPER+clic izquierdo` (arrastrar) | Mover la ventana |
| `SUPER+clic derecho` (arrastrar) | Redimensionar la ventana |
| `SUPER+SHIFT+R`, luego flechas | Modo redimensionar (mantener = repetir); `Esc` o `Enter` salen |
| `SUPER+I` | Inspector: class, título, workspace, tamaño y pid de la ventana; copia la class |

#### Workspaces y monitores

| Atajo | Acción |
|---|---|
| `SUPER+1` … `SUPER+0` | Ir al workspace 1-10 (el mismo otra vez = volver al anterior) |
| `SUPER+\|` (tecla a la izquierda del 1) | Saltar a la última ventana enfocada |
| `ALT+TAB` / `ALT+SHIFT+TAB` | Recorrer las ventanas del workspace (y traerla al frente) |
| `SUPER+SHIFT+1` … `SUPER+SHIFT+0` | Mover la ventana al workspace 1-10 |
| `SUPER+rueda del ratón` | Workspace siguiente / anterior |
| `SUPER+S` | Mostrar / ocultar el scratchpad (workspace especial «magic») |
| `SUPER+SHIFT+S` | Mandar la ventana al scratchpad |
| `SUPER+Return` | Terminal flotante (scratchpad; se abre sola la primera vez) |
| `SUPER+Y` | Música: Spotify en su scratchpad (si ya estaba abierto, lo trae) |
| `SUPER+O` | Notas: nvim con `~/Documents/notas.md` en un scratchpad flotante |
| `SUPER+CTRL+←/→` | Foco al otro monitor |
| `SUPER+CTRL+SHIFT+←/→` | Mandar la ventana al otro monitor |
| `SUPER+CTRL+ALT+←/→` | Mandar el workspace entero al otro monitor |

#### Sistema

| Atajo | Acción |
|---|---|
| `SUPER+L` | Bloquear la pantalla |
| `SUPER+M` | Salir de Hyprland (sin confirmar) |
| `ALT+F4` | Menú de apagado (wlogout) |
| `SUPER+N` | Centro de control (botones, volumen, brillo, música, notificaciones) |
| `SUPER+SHIFT+N` | No molestar |
| `SUPER+SHIFT+F` | Modo concentración: 25 / 50 / 90 min (con sesión: +10 min o terminar) |
| `SUPER+SHIFT+G` | Modo juego (también se activa solo con Roblox) |
| `SUPER+SHIFT+P` | Modo de energía: ahorro → equilibrado → rendimiento |
| `SUPER+SHIFT+T` | Colores: Ayu ↔ sacados del wallpaper |
| `SUPER+SHIFT+W` | Selector de wallpapers |
| `SUPER+CTRL+W` | Wallpaper al azar |
| `SUPER+SHIFT+V` | Historial del portapapeles |
| `SUPER+SHIFT+B` | Buds: cambiar de modo (ANC → transparencia → apagado) |

#### Capturas y grabación

| Atajo | Acción |
|---|---|
| `PRINT` | Captura de una región → `~/Imágenes/screenshots` + portapapeles |
| `SUPER+PRINT` | Captura de toda la pantalla |
| `SHIFT+PRINT` | Menú: región, pantalla, ventana activa o pantalla en 5 s |
| `SUPER+SHIFT+PRINT` | Guardar los últimos 30 s de pantalla y audio en `~/Videos/Replays` |
| `SUPER+ALT+PRINT` | Encender / apagar el replay |

#### Teclas multimedia (funcionan también con la pantalla bloqueada)

| Tecla | Acción |
|---|---|
| Volumen + / − / silencio | Cambia el volumen (máx. 100 %) y lo muestra el OSD |
| Micrófono | Silencia o activa el micrófono |
| Brillo + / − | Cambia el brillo y lo muestra el OSD |
| ⏮ ⏯ ⏭ | Música anterior / pausa / siguiente, con la canción en el OSD |
| `Bloq Mayús` | Avisa en el OSD si queda activado en cualquier teclado |

### Con el ratón

| Dónde | Acción |
|---|---|
| Barra: número de workspace | Clic = ir · rueda = siguiente / anterior |
| Barra: reloj | Al pasar el ratón muestra la fecha · clic = dashboard |
| Barra: bandeja | Clic = abrir · clic derecho = menú · clic central = acción secundaria |
| Barra: Buds | Clic = cambiar modo · derecho = ANC / apagado · central = Buds Manager |
| Barra: volumen | Clic = silenciar · rueda = volumen |
| Barra: red | Clic = nmtui |
| Barra: brillo | Rueda = brillo |
| Barra: energía | Clic = cambiar modo |
| Barra: CPU / RAM | Clic = btop |
| Barra: concentración (solo en sesión) | Clic = +10 min o terminar |
| Barra: mando | Clic = modo juego |
| Barra: campana | Clic = centro de control · derecho = No molestar |
| Dashboard: píldoras de workspaces | Clic = ir a ese workspace |
| Dashboard: calendario | Flechas o rueda = mes · clic en el título = volver a hoy |
| Notificación | Clic = acción principal · botones = sus acciones · `×` = cerrar · el ratón encima pausa el tiempo |

En el lanzador, el portapapeles y el selector de wallpapers: `↑↓` (o flechas) para moverse, `Enter` para elegir,
`Esc` o clic fuera para cerrar. En el portapapeles, `Supr` borra la entrada. En los menús, `1`-`9` eligen directo.

### Comportamiento automático

| Qué | Cómo funciona |
|---|---|
| Swallow | Una app gráfica abierta desde kitty (`mpv video.mp4`, `imv foto.png`) ocupa el sitio de la terminal; al cerrarla vuelve la terminal |
| Smart gaps | Una sola ventana en mosaico ocupa toda la pantalla, sin huecos ni borde (`apariencia.lua`) |
| Workspaces con propósito | Firefox abre en el 2; WhatsApp (ZapZap) y Discord en el 9 (`reglas.lua`) |

### Gestos del touchpad

| Gesto | Acción |
|---|---|
| 3 dedos ← → | Cambiar de workspace |
| 3 dedos ↑ | Mostrar / ocultar el scratchpad |
| 3 dedos ↓ | Dashboard |
| Abrir 3 dedos | Pantalla completa (otra vez = salir) |
| Juntar 3 dedos | Flotante ↔ mosaico |
| 4 dedos (cualquier dirección) | Mover la ventana |
| `SUPER` + 4 dedos | Redimensionar la ventana |
| `SUPER` + 3 dedos ↓ | Cerrar la ventana |
| `SUPER` + pellizco (2 dedos) | Lupa alrededor del cursor |

### Quickshell desde la terminal (`qs ipc call …`)

Sirven para atajos, scripts o pruebas. Lista en vivo: `qs ipc show`.

| Comando | Qué hace |
|---|---|
| `qs ipc call dashboard toggle` · `abrir` · `cerrar` | Dashboard |
| `qs ipc call dashboard irA 3` | Ir al workspace 3 |
| `qs ipc call lanzador toggle` | Lanzador de apps |
| `qs ipc call lanzador buscar fire` | Abrir el lanzador con un texto ya escrito |
| `qs ipc call lanzador lanzar btop` | Abrir directamente el primer resultado |
| `qs ipc call wallpapers toggle` | Selector de wallpapers |
| `qs ipc call portapapeles toggle` | Historial del portapapeles |
| `qs ipc call portapapeles copiarId 204` | Copiar la entrada 204 de cliphist |
| `qs ipc call menu capturas` · `concentracion` · `cerrar` | Menús |
| `qs ipc call notificaciones toggle` | Centro de control |
| `qs ipc call notificaciones noMolestar` · `noMolestarSi` · `noMolestarNo` | No molestar: alternar / activar / desactivar |
| `qs ipc call notificaciones borrar` | Borrar todas las notificaciones |
| `qs ipc call concentracion empezar 25` | Empezar una sesión de 25 min |
| `qs ipc call concentracion sumar 10` · `terminar` · `estado` | Añadir tiempo / terminar / ver lo que queda |
| `qs ipc call bloqueo bloquear` | Bloquear con la pantalla de Quickshell |
| `qs ipc call bloqueo probar` | Bloquear 12 s y soltar solo (para ver el diseño) |
| `qs ipc call bloqueo estado` | `libre`, `bloqueando` o `bloqueado` |
| `qs ipc call osd brillo` · `bloqMayus` · `media` | Mostrar en el OSD el brillo / Bloq Mayús / la canción |
| `qs ipc call osd mensaje "Hola" f04fe` | Aviso libre en el OSD (icono = código Nerd Font en hex) |
| `qs ipc call barra refrescar buds` | Refrescar un módulo de la barra: `buds`, `modo-juego`, `red`, `brillo` o `todo` |

### Hyprland desde la terminal

| Comando | Qué hace |
|---|---|
| `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'` | Cualquier acción de Hyprland (con config Lua se escribe en Lua) |
| `hyprctl dispatch 'modo_juego.alternar() or hl.dsp.no_op()'` | Alternar el modo juego |
| `hyprctl dispatch 'concentracion.empezar() or hl.dsp.no_op()'` · `terminar()` | Esconder / devolver las apps que distraen (sin temporizador) |
| `hyprctl dispatch 'hl.dsp.submap("reset")'` | Salir de un modo (submap) si te quedas atrapado |
| `hyprctl clients` · `activewindow -j` · `monitors` · `layers` · `binds -j` · `devices` | Inspeccionar ventanas, monitores, capas, atajos, teclados |
| `hyprctl configerrors` · `hyprctl reload` | Ver errores de la config / recargarla |

### Scripts (`~/.config/hypr/scripts/`)

| Comando | Qué hace |
|---|---|
| `tema.sh ayu` · `wallpaper` · `alternar` · `estado` | Colores fijos Ayu / del wallpaper / cambiar / ver el modo |
| `tema.sh aplicar [imagen]` | Regenerar la paleta en el modo actual |
| `wallpaper.sh` · `aleatorio` · `poner <ruta>` | Selector / uno al azar / poner ese |
| `capturas.sh` · `region` · `pantalla` · `ventana` · `temporizador` | Menú / captura directa |
| `replay.sh start` · `save` · `toggle` | Replay: arrancar / guardar 30 s / encender-apagar |
| `conmutadores.sh todos` | Estado de Wi-Fi, Bluetooth, replay y rendimiento |
| `conmutadores.sh wifi on` · `off` · `estado` | Igual para `bluetooth`, `replay`, `rendimiento` |
| `modo-energia.sh` | Siguiente modo de energía |
| `inspector.sh` | Datos de la ventana activa (lo que hace `SUPER+I`) |
| `bloquear.sh` | Bloquear (Quickshell; si no responde, hyprlock) |
| `desbloqueo-emergencia.sh` | Recuperar la sesión desde una TTY (ver más arriba) |
| `tiempo-pantalla.py --hoy` | Tiempo de pantalla de hoy por app |
| `tiempo-pantalla.py` | El demonio que lo mide (arranca solo) |
| `modo-juego-waybar.sh` · `calendario.sh` | Restos de waybar (se usan si vuelves a ella) |

### Instalación y mantenimiento

| Comando | Qué hace |
|---|---|
| `~/dotfiles/instalar.sh` | Instalar o reparar todo (ver «Instalar en un Arch nuevo») |
| `~/dotfiles/instalar.sh --simular` · `--sin-sistema` · `--solo PASO` | Simular / solo el usuario / un paso |
| `~/dotfiles/instalar/actualizar-listas.sh` | Regenerar las listas de paquetes desde este sistema |
| `~/dotfiles/instalar/apps-ayu.sh` | Instalar Vesktop y spicetify con el tema Ayu |
| `sudo ~/.config/hypr/temas-arranque/instalar.sh` | Temas de SDDM y GRUB |
| `sudo ~/.config/hypr/temas-arranque/instalar-plymouth-osd.sh` | Plymouth (pantalla de arranque) |
| `systemctl --user unmask swaync` | Volver a swaync (y cerrar Quickshell) |

### Terminal (zsh)

| Comando / tecla | Qué hace |
|---|---|
| `ls` · `ll` · `la` · `lt` | Listar con iconos / detalle + git / con ocultos / en árbol |
| `cat archivo` | Con colores (bat) |
| `cd algo` · `cdi` | Ir a una carpeta que ya visitaste (zoxide) / elegirla en un menú |
| `..` · `...` | Subir una / dos carpetas |
| `rz` | Recargar zsh |
| `actualizar` | `yay -Syu` |
| `zplug-actualizar` | Actualizar los plugins de zsh |
| `Ctrl+R` · `Ctrl+T` · `Alt+C` | Buscar en el historial / archivos / carpetas (fzf) |
| `Tab` | Completar con menú y vista previa (fzf-tab) |
| `↑` / `↓` | Buscar en el historial lo que ya escribiste |
| `→` o `Ctrl+Espacio` | Aceptar la sugerencia gris |
| `Ctrl+←/→` · `Ctrl+Retroceso` | Saltar / borrar palabras |
| `Inicio` · `Fin` · `Supr` | Principio / final de línea / borrar |
| `fastfetch` | Resumen del sistema |

### Neovim

| Tecla | Qué hace |
|---|---|
| `Espacio w` · `Espacio q` | Guardar / salir |
| `Espacio e` | Explorador de archivos |
| `Esc` | Quitar el resaltado de búsqueda |
| `J` / `K` (en modo visual) | Mover la selección abajo / arriba |
| `:lua vim.pack.update()` | Actualizar plugins |

### Redmi Buds (`buds`)

`buds status` · `battery` · `mode off|anc|transparency|next|toggle` · `strength` · `adaptive-anc` ·
`personalized-anc` · `adaptive-sound` · `auto-answer` · `multipoint` · `ear-detection` · `eq` · `eq-band` ·
`eq-curve` · `gesture` · `cycle` · `spatial` · `commute` · `find` · `backup` · `restore` · `hold on|off|status` ·
`auto` · `exposicion` · `dormir 30|off` · `mic` · `atajos`. Detalle de cada uno: `buds <comando> --help`.
`buds-manager` abre la app.

### Cuando no tocas el equipo

| Tiempo | Qué pasa |
|---|---|
| 29 min 30 s | Baja el brillo (mueve el ratón y vuelve) |
| 30 min | Se bloquea |
| 30 min 30 s | Se apaga la pantalla |
| 1 h | Se suspende |
