# dotfiles: Hyprland + Ayu Dark Glass

Mi escritorio en Arch Linux: Hyprland 0.57 con su configuración en Lua, y todo el sistema con la
paleta **Ayu**, desde el arranque (GRUB → Plymouth → SDDM) hasta las apps. Los colores pueden
cambiar solos según el wallpaper, gracias a matugen.

**¿Primera vez usándolo?** Lee el [manual de uso](docs/manual.md): explica cómo se maneja el escritorio
día a día. Abajo está la referencia completa de atajos y comandos.

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
                                        #   tema buds sistema base arranque apps)
```

Cuando instales algo nuevo, actualiza las listas y haz commit:

```bash
~/dotfiles/instalar/actualizar-listas.sh
```

## Qué hay

| Paquete (stow) | Qué configura |
|---|---|
| `hypr` | Hyprland en Lua, partido en módulos (`modulos/`), scripts, filtros de pantalla (`shaders/`), hyprlock, hypridle y los temas de arranque (`temas-arranque/`: SDDM, GRUB y Plymouth) |
| `tema` | Paletas Ayu (oscura y clara) y plantillas de matugen. `SUPER+SHIFT+T` cambia entre Ayu y los colores del wallpaper; `SUPER+CTRL+T` entre claro y oscuro (oscuro siempre, salvo que actives el horario con `tema.sh auto on`) |
| `swaync` · `swayosd` · `fuzzel` | De respaldo: Quickshell ya hace sus funciones (los scripts vuelven a fuzzel si Quickshell no responde) |
| `waybar` | La barra anterior, de respaldo (ya no arranca; ver `modulos/autostart.lua`) |
| `quickshell` | Todo el escritorio propio en QML: **barra** (workspaces, ventana, reloj, visualizador de audio, grabación, móvil, bandeja, Buds, volumen, red, brillo, batería, energía, CPU, RAM, modo juego, notificaciones), **dashboard** SUPER+D (reloj, clima, calendario con Google Calendar, sistema, tiempo de pantalla semanal, música con letra), **lanzador** SUPER+R (apps, cálculos, web, emojis, archivos, recordatorios), **chuleta** SUPER+H, **vista general** SUPER+ESPACIO, **OSD**, **notificaciones** y centro de control SUPER+N, **Wi-Fi/Bluetooth** SUPER+K, **pantalla de bloqueo**, selectores de **wallpapers**, **portapapeles** y menús, **widgets de escritorio** (reloj, clima, frase del día y lo próximo, solo con el workspace vacío), **asistente de IA local** SUPER+ALT+A, **nota rápida** SUPER+SHIFT+O, **resumen del día** y aviso de **actualizaciones** en la barra |
| `kitty` · `zsh` | Terminal, prompt starship, plugins de zsh, fzf, zoxide, atuin (historial) y fastfetch |
| `yazi` | Gestor de archivos en la terminal (SUPER+SHIFT+E o `y`), con el acento de la paleta |
| `lugares` | Reglas por lugar: qué cambia al conectarte a cada Wi-Fi (`~/.config/lugares.conf`) |
| `satty` | Editor de capturas (flechas, texto, difuminar) con la paleta Ayu |
| `easyeffects` | Perfiles de sonido para las bocinas del portátil (música y voz) |
| `keyd/` | Capas de teclado: Bloq Mayús = Esc / Ctrl / flechas en HJKL (va a `/etc/keyd`, no es de stow) |
| `udiskie` | Monta solos los USB y discos externos, con aviso |
| `gtk` | adw-gtk3 con colores Ayu e iconos Papirus-Ayu |
| `btop` · `nvim` · `vscode` · `firefox` · `vesktop` · `spicetify` | Apps con el tema Ayu |
| `wallpapers` | Mis fondos, en `~/Imágenes/wallpapers` |
| `instalar/` | Listas de paquetes y scripts de instalación (no es un paquete de stow) |
| `respaldo/` | Copias de seguridad automáticas al disco externo (restic; se instala con su `instalar.sh`) |

Buds Manager (para controlar los Redmi Buds desde Linux) vive en su propio repo,
[Buds-Manager](https://github.com/EchoStrokes08/Buds-Manager), y el instalador lo clona.

## Si la pantalla de bloqueo se cuelga

`Ctrl+Alt+F3`, entra con tu usuario y ejecuta `~/.config/hypr/scripts/desbloqueo-emergencia.sh`;
vuelve con `Ctrl+Alt+F1` y desbloquea con hyprlock (posible gracias a `allow_session_lock_restore`).

## Todos los comandos

Referencia completa. `SUPER` es la tecla Windows. Los atajos viven en `hypr/.config/hypr/modulos/`
(sobre todo `atajos.lua`); las funciones de Quickshell, en `quickshell/.config/quickshell/shell.qml`.

### Atajos de teclado

Esta es la lista **completa** y la única: la chuleta (`SUPER+H`) la lee de aquí, y `docs/actualizar-atajos.py`
la copia al apéndice A del manual. Al añadir un atajo: documentarlo aquí y ejecutar ese script.

#### Apps

| Atajo | Acción |
|---|---|
| `SUPER+Q` | Terminal (kitty) |
| `SUPER+E` | Archivos (Thunar) |
| `SUPER+R` | Lanzador: apps, acciones, calculadora, web, emojis, archivos y recordatorios (ver «El lanzador») |
| `SUPER+H` | Chuleta: todos estos atajos, con buscador |
| `SUPER+ESPACIO` | Vista general: todas las ventanas en miniatura (clic = ir · arrastrar = mover de workspace) |
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

#### Productividad

| Atajo | Acción |
|---|---|
| `SUPER+ALT+Enter` | Sesiones de trabajo: universidad / programar / descanso, cada app en su workspace (`modulos/sesiones.lua`) |
| `SUPER+ALT+A` | Asistente local (IA) sobre el texto seleccionado: resumir, corregir, redactar mejor, explicar, traducir o preguntar |
| `SUPER+SHIFT+O` | Nota rápida: una línea con fecha a `~/Documents/notas.md` |
| `SUPER+ALT+O` | Guardar en las notas el texto seleccionado |
| `SUPER+ALT+M` | Móvil: hacerlo sonar, enviarle lo copiado o un archivo, ver sus archivos |

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
| `SUPER+SHIFT+E` | Archivos: yazi en un scratchpad flotante (`SUPER+E` sigue siendo Thunar) |
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
| `SUPER+ALT+N` | Luz nocturna sí/no (automática 20:30–7:00, `hyprsunset.conf`) |
| `SUPER+SHIFT+C` | Selector de color: clic en un píxel → hex copiado |
| `SUPER+SHIFT+G` | Modo juego (también se activa solo con Roblox) |
| `SUPER+SHIFT+P` | Modo de energía: ahorro → equilibrado → rendimiento |
| `SUPER+SHIFT+T` | Colores: Ayu ↔ sacados del wallpaper |
| `SUPER+CTRL+T` | Tema claro ↔ oscuro |
| `SUPER+ALT+S` | Filtro de pantalla: ninguno / grises / papel / colores vivos / invertido |
| `SUPER+ALT+E` | Sonido de las bocinas: perfil música / voz / sin efectos (EasyEffects) |
| `SUPER+SHIFT+W` | Selector de wallpapers |
| `SUPER+CTRL+W` | Wallpaper al azar |
| `SUPER+SHIFT+V` | Historial del portapapeles |
| `SUPER+K` | Wi-Fi y Bluetooth (también: clic en la red de la barra, clic derecho en los botones del centro de control) |
| `SUPER+SHIFT+B` | Buds: cambiar de modo (ANC → transparencia → apagado) |
| `SUPER+ALT+P` | Pantalla externa: duplicar / extender / solo la externa / solo el portátil |

#### Capturas y grabación

| Atajo | Acción |
|---|---|
| `PRINT` | Captura de una región → `~/Imágenes/screenshots` + portapapeles |
| `SUPER+PRINT` | Captura de toda la pantalla |
| `SHIFT+PRINT` | Menú: región, pantalla, ventana activa, pantalla en 5 s o región y anotar |
| `SUPER+SHIFT+A` | Capturar una región y anotarla (satty): flechas, texto, números, resaltar, difuminar. `Enter` copia, guarda y sale |
| `SUPER+SHIFT+PRINT` | Guardar los últimos 30 s de pantalla y audio en `~/Videos/Replays` |
| `SUPER+ALT+PRINT` | Encender / apagar el replay |
| `SUPER+ALT+R` | Grabar pantalla: menú región / pantalla / con audio / GIF; otra vez = parar → `~/Videos/Grabaciones` |
| `SUPER+SHIFT+X` | Copiar texto de la pantalla (OCR): seleccionas una zona y su texto queda copiado |

#### Teclado con capas (keyd: funciona en todas las apps, la TTY y el login)

| Atajo | Acción |
|---|---|
| `Bloq Mayús` (un toque) | Esc |
| `Bloq Mayús` mantenida + tecla | Ctrl + tecla (`Bloq Mayús+C` = copiar) |
| `Bloq Mayús+H` `J` `K` `L` | Flechas ← ↓ ↑ → (con Shift, selecciona) |
| `Bloq Mayús+Y` `U` `I` `O` | Inicio · Av Pág · Re Pág · Fin |
| `Shift+Bloq Mayús` | Bloq Mayús de verdad (MAYÚSCULAS) |
| `Retroceso+Esc+Enter` | Emergencia: apaga keyd (el teclado vuelve a ser el normal) |

#### Texto y voz

| Atajo | Acción |
|---|---|
| `SUPER+ALT+D` | Dictar: pulsa, habla, vuelve a pulsar → el texto se escribe donde esté el cursor (Whisper, sin internet) |
| `SUPER+ALT+T` | Traducir lo seleccionado (otro idioma → español; español → inglés), queda copiado |

#### Teclas multimedia (funcionan también con la pantalla bloqueada)

| Tecla | Acción |
|---|---|
| Subir / bajar volumen | Cambia el volumen (máx. 100 %) y lo muestra el OSD |
| Silencio | Silencia o activa el sonido |
| Micrófono | Silencia o activa el micrófono |
| Subir / bajar brillo | Cambia el brillo y lo muestra el OSD |
| ⏮ anterior · ⏯ reproducir/pausa · ⏭ siguiente | Música, con la canción en el OSD |
| `Bloq Mayús` | Avisa en el OSD si queda activado en cualquier teclado |

### Con el ratón

| Dónde | Acción |
|---|---|
| Barra: número de workspace | Clic = ir · rueda = siguiente / anterior |
| Barra: barras de colores (solo con música) | Visualizador de audio · clic = dashboard |
| Barra: punto rojo con tiempo / micrófono rojo | Grabando la pantalla / dictando · clic = parar |
| Barra: móvil (solo si está conectado) | Batería del móvil · clic = KDE Connect · derecho = hacerlo sonar |
| Barra: reloj | Al pasar el ratón muestra la fecha · clic = dashboard |
| Barra: bandeja | Clic = abrir · clic derecho = menú · clic central = acción secundaria |
| Barra: Buds | Clic = cambiar modo · derecho = ANC / apagado · central = Buds Manager |
| Barra: volumen | Clic = silenciar · rueda = volumen |
| Barra: red | Clic = panel de Wi-Fi y Bluetooth · derecho = nmtui |
| Barra: brillo | Rueda = brillo |
| Barra: energía | Clic = cambiar modo |
| Barra: CPU / RAM | Clic = btop |
| Barra: concentración (solo en sesión) | Clic = +10 min o terminar |
| Barra: mando | Clic = modo juego |
| Barra: campana | Clic = centro de control · derecho = No molestar |
| Dashboard: píldoras de workspaces | Clic = ir a ese workspace |
| Dashboard: calendario | Flechas o rueda = mes · clic en el título = volver a hoy · puntito = hay eventos ese día |
| Dashboard: «Próximo» | Eventos de Google Calendar y recordatorios · clic en un recordatorio = borrarlo |
| Dashboard: últimos 7 días | Pasa el ratón por una barra: total y app principal de ese día |
| Centro de control: Wi-Fi / Bluetooth | Clic = encender/apagar · derecho = abrir su lista |
| Centro de control: Conservar · Luz noche | Batería hasta ~80 % · pantalla cálida |
| Centro de control: salidas de audio | Un botón por salida (altavoces, Buds, HDMI): clic = sonar por ahí |
| Vista general | Clic en ventana = ir · clic en hueco = ir al workspace · arrastrar = mover de workspace · `1`-`9` |
| Notificación | Clic = acción principal · botones = sus acciones · `×` = cerrar · el ratón encima pausa el tiempo |

### El lanzador (`SUPER+R`)

| Escribe | Resultado (Enter) |
|---|---|
| `firefox`, `ffx`, `blo`… | Apps (sin tildes, letras salteadas; las que más usas suben) y acciones: bloquear, apagar, atajos, OCR, dictar, grabar… |
| `2*(3+4)` · `5 km a mi` · `30 °C a °F` · `100 USD a COP` · `=…` | Calculadora y conversor (qalc): copia el resultado |
| `g …` · `yt …` · `w …` · `gh …` | Buscar en Google / YouTube / Wikipedia / GitHub |
| `:fuego` · `:corazon` · `:sigma` · `:≤` | Emojis y símbolos: los escribe y quedan copiados |
| `/apuntes` (solo `/` = recientes) | Archivos de tu carpeta personal: los abre |
| `recordar 20m beber agua` · `recordar 18:30 llamar` · `recordar mañana 7:00 examen` | Recordatorio (aviso con sonido; sobrevive a reinicios). Abreviado: `rec` |
| Cualquier cosa sin resultados | Buscarla en Google |

En el lanzador, el portapapeles y el selector de wallpapers: `↑↓` (o flechas) para moverse, `Enter` para elegir,
`Esc` o clic fuera para cerrar. En el portapapeles, `Supr` borra la entrada. En los menús, `1`-`9` eligen directo.
| `v texto` | Ventanas abiertas en cualquier workspace → ir a ella |
| `n texto` | Buscar dentro de tus notas (`~/Documents/*.md`) → abrir nvim en esa línea |
| `c texto` | Historial del portapapeles → copiarlo otra vez |
| `t texto` | Pestañas abiertas de Firefox → abrir esa dirección (para saltar a la pestaña ya abierta, en Firefox escribe `%` en la barra) |
| `p nombre` | Contraseñas (Bitwarden o pass) → la escribe donde esté el cursor. Primera vez: `claves.sh configurar` |
| `ia pregunta` | Preguntar al asistente local |
| `nota texto` | Apuntar una línea en `notas.md` |

### Atajos que se adaptan al layout (`modulos/layouts.lua`)

| Tecla | dwindle | master | scrolling |
|---|---|---|---|
| `SUPER++` / `SUPER+-` | División más grande / pequeña | Área principal más ancha / fina | Columna más ancha / estrecha |
| `SUPER+Z` | Llevar la ventana a la raíz | Cambiarla con la principal | Centrar la columna |
| `SUPER+X` | Invertir la división | Girar la orientación | Meter / sacar de la columna anterior |
| `SUPER+SHIFT++` / `SUPER+SHIFT+-` | — | Una ventana principal más / menos | — |

### Comportamiento automático

| Qué | Cómo funciona |
|---|---|
| Swallow | Una app gráfica abierta desde kitty (`mpv video.mp4`, `imv foto.png`) ocupa el sitio de la terminal; al cerrarla vuelve la terminal |
| Smart gaps | Una sola ventana en mosaico ocupa toda la pantalla, sin huecos ni borde (`apariencia.lua`) |
| Workspaces con propósito | Firefox abre en el 2; WhatsApp (ZapZap) y Discord en el 9 (`reglas.lua`) |
| Teclado | Mantener una tecla repite a los 300 ms, 40 veces/s (`entrada.lua`) |
| Touchpad | Tocar = clic; al hundirlo, 1 dedo = clic, 2 = derecho, 3 = central; se ignora mientras escribes |
| Cursor | Se esconde al teclear y tras 5 s quieto; vuelve al mover el ratón |
| Tema por hora | Apagado: siempre oscuro. Con `tema.sh auto on`, a las 6:30 pasa a claro y a las 18:00 a oscuro (`modulos/tema.lua`) |
| Wallpapers | Cambian con transición (awww): a mano, el nuevo crece desde el cursor; en la rotación de cada 10 min, un barrido; con batería, un fundido corto |
| Escritorio | Con el workspace vacío aparecen reloj, clima, frase del día y lo próximo (eventos y recordatorios); al abrir una ventana se van (`Escritorio.qml`) |
| Animaciones por tipo | Diálogos se despliegan (gnomed), PiP entra por la derecha, la barra baja, las notificaciones entran de lado, los scratchpads se esconden el doble de rápido de lo que entran (`animaciones.lua`, final de `reglas.lua`) |
| Sonido | El perfil de EasyEffects solo actúa en las bocinas; con audífonos (Bluetooth o cable) se salta solo (`sonido.sh`, `Audifonos.qml`) |
| Capturas | El aviso de cada captura trae el botón **Anotar** (abre satty) |
| Resumen del día | La primera vez que usas el equipo cada día (desde las 5:00): clima, eventos, recordatorios, batería y actualizaciones (`Resumen.qml`) |
| Actualizaciones | Cada 3 h se comprueba sin tocar el sistema; si hay, aparece un paquete con el número en la barra (rojo = hay noticias de Arch que leer antes). Clic = actualizar |
| Pausas | Tras 50 min seguidos de uso (sin una pausa de 3 min), aviso para descansar la vista. No avisa con No molestar (`Pausas.qml`) |
| Lugares | Al cambiar de Wi-Fi se aplica su regla de `~/.config/lugares.conf` (energía, volumen de las bocinas, No molestar). En una red desconocida, las bocinas se silencian |
| Sincronización | Syncthing corre de fondo (panel: http://127.0.0.1:8384) y Tailscale deja entrar al portátil desde tus otros equipos |
| Cargador | Al desenchufar: perfil «ahorro» y sin blur ni sombras. Al enchufar: vuelve el perfil anterior y la apariencia normal (`Cargador.qml` + `modulos/bateria.lua`; respeta el modo juego) |
| Disco (SSD) | smartd lo vigila y avisa en el escritorio si aparecen errores o pasa de 75 °C (`/etc/smartd.conf`) |
| Firmware | `fwupd-refresh.timer` busca actualizaciones de BIOS/SSD; instalarlas: `fwupdmgr update` |
| Caché de pacman | Cada semana deja solo la última versión de cada paquete |
| DNS | Cifrado (DNS-over-TLS, Quad9 + Cloudflare): el operador y la Wi-Fi no ven qué webs visitas. `dns-cifrado off` para Wi-Fi con página de acceso |
| Memoria | Si se acaba la RAM, earlyoom cierra una app (pestañas/apps web primero) y avisa |
| Recordatorios | `recordar …` en el lanzador: notificación crítica + sonido a su hora; si el equipo estaba apagado, al encender |
| Calendario | Tus eventos de Google Calendar en el dashboard (cada 15 min) y aviso 10 min antes de cada uno |
| Clima | Bogotá en el dashboard (Open-Meteo, cada 30 min; ubicación en `Clima.qml`) |
| Tiempo de pantalla | Límites diarios por app en `~/.config/tiempo-pantalla/limites.json` (minutos por class): aviso al llegar y cada 30 min de más. No cuenta con la pantalla bloqueada |
| Pantalla externa | Al conectarla: menú duplicar/extender + No molestar; al quitarla, todo vuelve (`presentacion.lua`) |
| Audífonos | Buds Manager pausa/reanuda por el sensor de oreja; si los audífonos se desconectan solos mientras suena algo, se pausa (`Audifonos.qml`) |
| Letras | La canción que suena, sincronizada, en el dashboard (lrclib.net) |
| Servidores de paquetes | reflector elige cada semana los más rápidos cerca de Colombia |
| Arranque | GRUB sin menú (1 s). **Esc o Shift** al encender lo muestra (con los snapshots para volver atrás) |
| USB | udiskie los monta en `/run/media/oscar/<nombre>` y avisa (botón para abrir en Thunar). Expulsar: icono de la bandeja o `udiskie-umount -a` |

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
| `SUPER` + 3 dedos ↑ | Vista general |
| `SUPER` + pellizco (2 dedos) | Lupa alrededor del cursor |

### Quickshell desde la terminal (`qs ipc call …`)

Sirven para atajos, scripts o pruebas. Lista en vivo: `qs ipc show`.

| Comando | Qué hace |
|---|---|
| `qs ipc call dashboard toggle` · `abrir` · `cerrar` | Dashboard |
| `qs ipc call dashboard irA 3` | Ir al workspace 3 |
| `qs ipc call ia abrir <accion> "pregunta"` · `estado` | Panel del asistente (lo normal es usar `ia.sh`) |
| `qs ipc call nota abrir` · `resumen mostrar` | Nota rápida / resumen del día |
| `qs ipc call actualizaciones refrescar` · `estado` · `pausas estado` | Volver a comprobar actualizaciones / minutos seguidos de uso |
| `qs ipc call escritorio toggle` · `estado` | Esconder / mostrar los widgets de escritorio |
| `qs ipc call menu shaders` · `sonido <perfil>` | Menús de filtro de pantalla y de sonido |
| `qs ipc call lanzador toggle` | Lanzador de apps |
| `qs ipc call lanzador buscar fire` | Abrir el lanzador con un texto ya escrito |
| `qs ipc call lanzador lanzar btop` | Abrir directamente el primer resultado |
| `qs ipc call wallpapers toggle` | Selector de wallpapers |
| `qs ipc call portapapeles toggle` | Historial del portapapeles |
| `qs ipc call portapapeles copiarId 204` | Copiar la entrada 204 de cliphist |
| `qs ipc call conexiones toggle` / `wifi` / `bluetooth` | Panel de Wi-Fi y Bluetooth (en esa pestaña) |
| `qs ipc call cargador estado` | ¿Con batería o cargador? (y el perfil que se restaurará) |
| `qs ipc call cargador simular bat` · `ac` | Probar el cambio sin desenchufar |
| `qs ipc call chuleta toggle` · `buscar captura` | Chuleta de atajos (con una búsqueda ya escrita) |
| `qs ipc call vista toggle` | Vista general |
| `qs ipc call recordatorios agregar "20m beber agua"` · `lista` · `borrar ID` | Recordatorios |
| `qs ipc call menu grabar` · `pantalla HDMI-A-1` | Menú de grabar / de pantalla externa |
| `qs ipc call conexiones estado` | Resumen: tarjeta Wi-Fi, redes vistas, Bluetooth, dispositivos |
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
| `qs ipc call barra refrescar buds` | Refrescar un módulo de la barra: `buds`, `modo-juego`, `red`, `brillo`, `grabacion` o `todo` |

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
| `tema.sh ayu` · `wallpaper` · `alternar` · `estado` | Colores fijos Ayu / del wallpaper / cambiar / ver modo, variante y si es automático |
| `tema.sh claro` · `oscuro` · `variante` | Tema claro / oscuro / cambiar |
| `tema.sh auto on` · `off` · `estado` | Claro de día y oscuro de noche, sí/no |
| `ia.sh` · `resumir` · `corregir` · `mejorar` · `explicar` · `traducir` · `preguntar [texto]` | Asistente local sobre la selección. Modelo en `~/.config/ia/modelo` |
| `nota.sh "texto"` · `seleccion` | Apuntar una línea / la selección en `notas.md` |
| `claves.sh configurar` | Guía para dejar listo el gestor de contraseñas (Bitwarden con `rbw`, o `pass`) |
| `lugar.sh estado` · `aplicar` | Red y lugar actuales / aplicar su regla ahora |
| `actualizaciones.sh` · `instalar` | Pendientes en JSON / actualizar en una terminal |
| `movil.sh menu` · `portapapeles` · `elegir` · `navegar` | Menú del móvil / enviar lo copiado / enviar archivo / ver sus archivos |
| `menu.sh "Título" '[…json…]'` | Abrir el menú de Quickshell con tus propias opciones |
| `buscar.py <tipo> <texto>` | El buscador del lanzador (ventanas, notas, portapapeles, pestanas, claves) |
| `sonido.sh Portatil` · `Voz` · `off` · `menu` · `estado` | Perfil de sonido de las bocinas (EasyEffects) |
| `tema.sh aplicar [imagen]` | Regenerar la paleta en el modo actual |
| `wallpaper.sh` · `aleatorio` · `poner <ruta>` | Selector / uno al azar / poner ese |
| `capturas.sh` · `region` · `pantalla` · `ventana` · `temporizador` · `anotar` | Menú / captura directa / región al editor |
| `capturas.sh editar <archivo>` | Abrir una captura ya hecha en el editor (satty) |
| `replay.sh start` · `save` · `toggle` | Replay: arrancar / guardar 30 s / encender-apagar |
| `conmutadores.sh todos` | Estado de Wi-Fi, Bluetooth, replay y rendimiento |
| `conmutadores.sh wifi on` · `off` · `estado` | Igual para `bluetooth`, `replay`, `rendimiento`, `conservacion` (batería hasta ~80 %), `luz` |
| `dns-cifrado.sh on` · `off` · `estado` | DNS cifrado (alias `dns-cifrado` en zsh) |
| `modo-energia.sh` | Siguiente modo de energía |
| `inspector.sh` | Datos de la ventana activa (lo que hace `SUPER+I`) |
| `bloquear.sh` | Bloquear (Quickshell; si no responde, hyprlock) |
| `desbloqueo-emergencia.sh` | Recuperar la sesión desde una TTY (ver más arriba) |
| `tiempo-pantalla.py --hoy` · `--semana` | Tiempo de pantalla de hoy por app / últimos 7 días (JSON) |
| `ocr.sh [idioma]` | Texto de una zona de la pantalla al portapapeles (por defecto `spa+eng`) |
| `dictado.sh` · `cancelar` | Empezar/terminar el dictado. Modelo en `~/.config/dictado/modelo` (`small` preciso · `base` rápido) |
| `traducir.sh [idioma]` | Traducir la selección (forzar destino: `en`, `fr`…) |
| `grabar.sh` · `region` · `pantalla` · `region-audio` · `pantalla-audio` · `gif` · `parar` · `estado` | Grabar pantalla |
| `eventos.py --lista` | Tus próximos eventos de Google Calendar (dirección en `~/.config/calendario/url`, privada) |
| `movil.sh estado` · `sonar` · `enviar archivo` · `app` | Móvil por KDE Connect |
| `tiempo-pantalla.py` | El demonio que lo mide (arranca solo) |
| `modo-juego-waybar.sh` · `calendario.sh` | Restos de waybar (se usan si vuelves a ella) |

### Instalación y mantenimiento

| Comando | Qué hace |
|---|---|
| `~/dotfiles/instalar.sh` | Instalar o reparar todo (ver «Instalar en un Arch nuevo») |
| `~/dotfiles/instalar.sh --simular` · `--sin-sistema` · `--solo PASO` | Simular / solo el usuario / un paso |
| `~/dotfiles/instalar/actualizar-listas.sh` | Regenerar las listas de paquetes desde este sistema |
| `~/dotfiles/instalar/apps-ayu.sh` | Instalar Vesktop y spicetify con el tema Ayu |
| `~/dotfiles/instalar/sistema-base.sh [--simular]` | Snapshots (snapper + GRUB), zram, firewall, USB/celular, visores, llavero, caché, hub USB, earlyoom, vigilancia del SSD, firmware, GRUB rápido, botón de conservación de batería y DNS cifrado |
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
| `dns-cifrado off` · `on` · `estado` | Apagar el DNS cifrado para una Wi-Fi con página de acceso / volver a encenderlo |
| `y [carpeta]` | yazi; al salir con `q` la terminal se queda en la carpeta donde estabas (`Q` no cambia) |
| `zplug-actualizar` | Actualizar los plugins de zsh |
| `Ctrl+R` | Historial con atuin: busca por texto; `Ctrl+R` otra vez cambia el filtro (todo → esta sesión → esta carpeta); `Enter` ejecuta, `Tab` lo deja para editar |
| `atuin stats` | Tus comandos más usados |
| `Ctrl+T` · `Alt+C` | Buscar archivos / carpetas (fzf) |
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

### Copias de seguridad (`respaldo`)

Cifradas con restic en el disco externo TOSHIBA EXT (`OSCAR/hyprland`). Automáticas al conectarlo; aviso si pasan
7 días sin copia. Instalar en un equipo nuevo: `~/dotfiles/respaldo/instalar.sh [UUID] [carpeta]`.

| Comando | Qué hace |
|---|---|
| `respaldo estado` · `ahora` · `lista` | Última copia y espacio · copiar ya · ver copias |
| `respaldo montar` | Explorar las copias en `/mnt/respaldo` (Ctrl+C cierra) |
| `respaldo comprobar` | Verificar que se pueden leer enteras |
| `sudo cat /etc/respaldo/clave` | La contraseña (apúntala fuera del portátil) |

### Cuando no tocas el equipo

| Tiempo | Qué pasa |
|---|---|
| 29 min 30 s | Baja el brillo (mueve el ratón y vuelve) |
| 30 min | Se bloquea |
| 30 min 30 s | Se apaga la pantalla |
| 1 h | Se suspende |
