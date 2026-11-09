# Manual de uso

Cómo se usa este escritorio en el día a día: qué es cada cosa, cómo moverse rápido y qué hacer cuando algo falla.
La lista completa de atajos y comandos está en el [README](../README.md#todos-los-comandos); este manual explica
**cuándo y para qué** usar cada uno.

> `SUPER` es la tecla Windows. Casi todo se hace con ella.

## Índice

1. [Ideas básicas](#1-ideas-básicas)
2. [Chuleta: los 25 atajos que más se usan](#2-chuleta-los-25-atajos-que-más-se-usan)
3. [Abrir apps](#3-abrir-apps)
4. [Manejar ventanas](#4-manejar-ventanas)
5. [Workspaces y navegación](#5-workspaces-y-navegación)
6. [Layouts: cómo se reparten las ventanas](#6-layouts-cómo-se-reparten-las-ventanas)
7. [Grupos: ventanas en pestañas](#7-grupos-ventanas-en-pestañas)
8. [Scratchpads: apps que aparecen y desaparecen](#8-scratchpads-apps-que-aparecen-y-desaparecen)
9. [Gestos del touchpad](#9-gestos-del-touchpad)
10. [Barra, dashboard y notificaciones](#10-barra-dashboard-y-notificaciones)
11. [Portapapeles, wallpapers y colores](#11-portapapeles-wallpapers-y-colores)
12. [Capturas y grabación](#12-capturas-y-grabación)
13. [Modos: juego, concentración, energía y No molestar](#13-modos-juego-concentración-energía-y-no-molestar)
14. [Sonido, brillo y audífonos](#14-sonido-brillo-y-audífonos)
15. [Bloqueo, inactividad y apagado](#15-bloqueo-inactividad-y-apagado)
16. [Cambiar la configuración](#16-cambiar-la-configuración)
17. [Si algo falla](#17-si-algo-falla)

---

## 1. Ideas básicas

| Concepto | Qué es |
|---|---|
| **Mosaico (tiling)** | Las ventanas no se superponen: se reparten la pantalla solas. Abrir una ventana parte el hueco de la que tiene el foco. |
| **Flotante** | Una ventana libre, encima de las demás, como en Windows. `SUPER+V` alterna entre flotante y mosaico. |
| **Workspace** | Un escritorio virtual. Hay 10 (`SUPER+1` … `SUPER+0`). Solo existen mientras tienen ventanas. |
| **Layout** | La regla para repartir las ventanas de un workspace: dwindle, master, scrolling o monocle (sección 6). |
| **Grupo** | Varias ventanas en un mismo hueco, con pestañas arriba (sección 7). |
| **Scratchpad** | Un workspace especial que aparece *encima* del actual y se esconde con la misma tecla (sección 8). |
| **Foco** | La ventana que recibe el teclado. Sigue al ratón y lleva el borde de color. |

Regla para recordar los atajos de ventanas:

| Modificador | Con flechas significa |
|---|---|
| `SUPER` | mover el **foco** |
| `SUPER+SHIFT` | mover la **ventana** |
| `SUPER+ALT` | **intercambiar** la ventana con la vecina |
| `SUPER+CTRL` | cosas de **monitores** |

## 2. Chuleta: los 25 atajos que más se usan

| Atajo | Acción |
|---|---|
| `SUPER+Q` | Terminal |
| `SUPER+R` | Lanzador de apps |
| `SUPER+E` | Archivos |
| `SUPER+C` | Cerrar ventana |
| `SUPER+V` | Flotante ↔ mosaico |
| `SUPER+F` | Pantalla completa |
| `SUPER+flechas` | Mover el foco |
| `SUPER+SHIFT+flechas` | Mover la ventana |
| `SUPER+ALT+flechas` | Intercambiar con la vecina |
| `SUPER+1…0` | Ir a un workspace (el mismo otra vez = volver) |
| `SUPER+SHIFT+1…0` | Mandar la ventana a un workspace |
| `SUPER+\|` | Volver a la última ventana |
| `ALT+TAB` | Siguiente ventana del workspace |
| `SUPER+TAB` | Cambiar de layout |
| `SUPER+T` | Grupo (pestañas) |
| `SUPER+.` / `SUPER+,` | Pestaña siguiente / anterior |
| `SUPER+Return` | Terminal flotante |
| `SUPER+Y` | Música |
| `SUPER+O` | Notas |
| `SUPER+D` | Dashboard |
| `SUPER+N` | Centro de control |
| `SUPER+SHIFT+V` | Portapapeles |
| `PRINT` | Captura de una región |
| `SUPER+L` | Bloquear |
| `ALT+F4` | Menú de apagado |

## 3. Abrir apps

- **Lanzador** (`SUPER+R`): escribe parte del nombre, `↑↓` para elegir, `Enter` para abrir, `Esc` para cerrar.
- **Atajos directos**: `SUPER+Q` terminal, `SUPER+E` archivos, `SUPER+W` WhatsApp, `SUPER+B` Buds Manager,
  `SUPER+G` Roblox.
- **Modo lanzar** (`SUPER+A` y luego una letra): `F` Firefox, `T` terminal, `E` archivos, `W` WhatsApp,
  `G` Roblox, `S` Spotify. Cualquier otra tecla cancela.
- **«Enfocar o abrir»**: WhatsApp, Buds Manager, Firefox y Spotify no se abren dos veces. Si ya están abiertos,
  el atajo te lleva a su ventana.
- **Cada app en su sitio**: Firefox siempre abre en el workspace 2 y WhatsApp/Discord en el 9, y te llevan ahí.

## 4. Manejar ventanas

**Con el teclado** (lo más rápido):

| Quiero… | Atajo |
|---|---|
| Ir a la ventana de la izquierda/derecha/arriba/abajo | `SUPER+flechas` |
| Llevar la ventana hacia un lado (cambia la forma del reparto) | `SUPER+SHIFT+flechas` |
| Cambiar dos ventanas de sitio sin tocar el resto | `SUPER+ALT+flechas` |
| Hacerla más grande o más pequeña | `SUPER++` / `SUPER+-` |
| Ajustar el tamaño con precisión | `SUPER+SHIFT+R`, flechas (mantener = repetir), `Esc` para salir |
| Flotante ↔ mosaico | `SUPER+V` |
| Pantalla completa | `SUPER+F` |
| Cerrar | `SUPER+C` |

**Mover** frente a **intercambiar**: mover (`SHIFT`) saca la ventana de su rama y puede cambiar los tamaños de
todas; intercambiar (`ALT`) solo cambia dos ventanas de sitio. Si no sabes cuál usar, prueba intercambiar.

**Con el ratón**: `SUPER+arrastrar con clic izquierdo` mueve la ventana; `SUPER+arrastrar con clic derecho` la
redimensiona.

**Detalles automáticos**:
- Si una ventana está sola en su workspace, ocupa toda la pantalla, sin huecos ni borde (*smart gaps*).
- Si abres una app gráfica desde kitty (por ejemplo `mpv video.mp4`), ocupa el sitio de la terminal y, al
  cerrarla, la terminal vuelve (*swallow*).
- El cursor se esconde al escribir y tras 5 segundos quieto.

## 5. Workspaces y navegación

- `SUPER+número` va a ese workspace. Pulsar el número del workspace en el que ya estás **vuelve al anterior**:
  así se salta entre dos workspaces con una sola tecla.
- `SUPER+SHIFT+número` manda la ventana a ese workspace (tú te quedas donde estás).
- `SUPER+|` (la tecla a la izquierda del 1) salta a **la última ventana** que usaste, aunque esté en otro
  workspace. Ideal para ir y volver entre el navegador y la terminal.
- `ALT+TAB` / `ALT+SHIFT+TAB` recorren las ventanas del workspace y traen la elegida al frente (útil con
  flotantes).
- `SUPER+rueda del ratón` o 3 dedos en horizontal: workspace siguiente / anterior.
- En la barra, clic en un número de workspace para ir a él.

Organización sugerida: **1** terminal · **2** navegador · **3-8** lo que estés haciendo · **9** chats.

**Con un monitor externo**: se coloca a la derecha del portátil. `SUPER+CTRL+←/→` cambia el foco de monitor,
`SUPER+CTRL+SHIFT+←/→` manda la ventana y `SUPER+CTRL+ALT+←/→` manda el workspace entero.

## 6. Layouts: cómo se reparten las ventanas

`SUPER+TAB` cambia el layout **del workspace actual** (cada workspace recuerda el suyo hasta recargar la config).
Sale un aviso con el nombre.

| Layout | Cómo reparte | Bueno para |
|---|---|---|
| **dwindle** (por defecto) | Cada ventana nueva parte en dos el hueco de la enfocada | Uso general |
| **master** | Una ventana grande (principal) y las demás apiladas al lado | Programar: editor grande + terminales |
| **scrolling** | Columnas en una cinta infinita que se desplaza | Muchas ventanas sin que se hagan diminutas |
| **monocle** | Una ventana a la vez, a pantalla completa | Concentrarse en una cosa |

Las mismas teclas hacen «lo equivalente» en cada layout:

| Tecla | dwindle | master | scrolling |
|---|---|---|---|
| `SUPER++` / `SUPER+-` | División más grande / pequeña | Principal más ancha / fina | Columna más ancha / estrecha |
| `SUPER+Z` | Llevar la ventana a la raíz | Cambiarla con la principal | Centrar la columna |
| `SUPER+X` | Invertir la división | Girar la orientación | Meter / sacar de la columna anterior |
| `SUPER+SHIFT++` / `-` | — | Una principal más / menos | — |

En dwindle, `SUPER+J` cambia la división entre horizontal y vertical.

## 7. Grupos: ventanas en pestañas

Un grupo mete varias ventanas en un solo hueco, con una barra de pestañas arriba (como un navegador).

1. Enfoca una ventana y pulsa `SUPER+T`: se convierte en grupo.
2. Las ventanas que abras mientras el grupo tiene el foco entran solas en él.
3. Para meter una ventana que ya existe: llévala hacia el grupo con `SUPER+SHIFT+flechas`.
   Para sacarla, lo mismo hacia fuera.
4. `SUPER+.` / `SUPER+,` cambian de pestaña; `SUPER+SHIFT+.` / `,` reordenan.
5. `SUPER+T` otra vez deshace el grupo.

Con el ratón: clic en una pestaña para ir a ella, clic central para cerrarla, arrastrar una ventana sobre la
barra para meterla. Una ventana agrupada tiene el borde amarillo → naranja.

## 8. Scratchpads: apps que aparecen y desaparecen

| Tecla | Qué aparece |
|---|---|
| `SUPER+Return` | Una terminal flotante, centrada |
| `SUPER+Y` | Spotify |
| `SUPER+O` | Notas: nvim con `~/Documents/notas.md` |
| `SUPER+S` | El scratchpad libre «magic»: manda cualquier ventana con `SUPER+SHIFT+S` |

- La misma tecla lo muestra y lo esconde. Lo de debajo no se mueve.
- La primera vez la app se abre sola. Después sigue viva escondida: lo que tenías en la terminal o en las notas
  sigue ahí.
- Si Spotify ya estaba abierto en otro workspace, `SUPER+Y` lo trae en vez de abrir otro.
- En las notas, `Espacio w` guarda y `Espacio q` sale.

## 9. Gestos del touchpad

Regla: **3 dedos = navegar · 4 dedos = mover la ventana · con SUPER = lo delicado**.

| Gesto | Acción |
|---|---|
| 3 dedos ← → | Cambiar de workspace |
| 3 dedos ↑ | Scratchpad «magic» |
| 3 dedos ↓ | Dashboard |
| Abrir 3 dedos | Pantalla completa (otra vez = salir) |
| Juntar 3 dedos | Flotante ↔ mosaico |
| 4 dedos | Mover la ventana |
| `SUPER` + 4 dedos | Redimensionar |
| `SUPER` + 3 dedos ↓ | Cerrar la ventana |
| `SUPER` + pellizco | Lupa alrededor del cursor |

Los gestos siguen a los dedos: si sueltas a medias, se cancelan.

**Clics del touchpad**: tocar = clic. Al hundirlo, cuenta el número de dedos: 1 = clic, 2 = clic derecho,
3 = clic central. Mientras escribes, el touchpad se ignora.

## 10. Barra, dashboard y notificaciones

**Barra** (arriba). Casi todo se puede pulsar:

| Zona | Clic | Otros |
|---|---|---|
| Números de workspace | Ir | Rueda = siguiente / anterior |
| Reloj | Dashboard | Al pasar el ratón: la fecha |
| Volumen | Silenciar | Rueda = volumen |
| Brillo | — | Rueda = brillo |
| Red | Abre nmtui | |
| Energía | Cambiar modo | |
| CPU / RAM | Abre btop | |
| Buds | Cambiar modo | Derecho = ANC / apagado · central = Buds Manager |
| Mando | Modo juego | |
| Campana | Centro de control | Derecho = No molestar |

**Dashboard** (`SUPER+D` o 3 dedos hacia abajo): reloj, workspaces, calendario, estado del sistema, tiempo de
pantalla de hoy y la música que suena. En el calendario, flechas o rueda cambian de mes y un clic en el título
vuelve a hoy.

**Centro de control** (`SUPER+N`): botones rápidos (Wi-Fi, Bluetooth…), volumen, brillo, música y el historial
de notificaciones.

**Notificaciones**: clic = acción principal; `×` = cerrar; con el ratón encima no desaparecen.
`SUPER+SHIFT+N` activa No molestar.

**Tiempo de pantalla**: `~/.config/hypr/scripts/tiempo-pantalla.py --hoy` en la terminal muestra cuánto has
usado cada app hoy.

## 11. Portapapeles, wallpapers y colores

- **Portapapeles** (`SUPER+SHIFT+V`): historial de lo copiado, con imágenes. `Enter` copia la entrada elegida,
  `Supr` la borra.
- **Wallpapers**: `SUPER+SHIFT+W` abre el selector con miniaturas; `SUPER+CTRL+W` pone uno al azar.
  Los fondos están en `~/Imágenes/wallpapers`.
- **Colores**: `SUPER+SHIFT+T` cambia entre la paleta Ayu fija y los colores sacados del wallpaper. Se aplican
  a todo: bordes, barra, pestañas de grupos, terminal, btop…

## 12. Capturas y grabación

| Atajo | Acción |
|---|---|
| `PRINT` | Elegir una región |
| `SUPER+PRINT` | Toda la pantalla |
| `SHIFT+PRINT` | Menú: región, pantalla, ventana activa o con 5 s de espera |
| `SUPER+SHIFT+PRINT` | Guardar los **últimos 30 s** de pantalla y audio |
| `SUPER+ALT+PRINT` | Encender / apagar esa grabación continua (replay) |

Las capturas van a `~/Imágenes/screenshots` y además al portapapeles (se pueden pegar directamente).
Los replays van a `~/Videos/Replays`.

## 13. Modos: juego, concentración, energía y No molestar

| Modo | Atajo | Qué hace |
|---|---|---|
| **Juego** | `SUPER+SHIFT+G` (o solo al abrir Roblox) | Quita animaciones y efectos y silencia notificaciones, para ganar rendimiento |
| **Concentración** | `SUPER+SHIFT+F` | Temporizador de 25, 50 o 90 min con No molestar; WhatsApp, Discord, Roblox y Steam se esconden y vuelven al terminar. Cuenta atrás en la barra (clic = +10 min o terminar) |
| **Energía** | `SUPER+SHIFT+P` | Ahorro → equilibrado → rendimiento |
| **No molestar** | `SUPER+SHIFT+N` | Las notificaciones se guardan sin aparecer |

## 14. Sonido, brillo y audífonos

- Las teclas de volumen, micrófono, brillo y música funcionan siempre, incluso con la pantalla bloqueada, y
  muestran un aviso (OSD) en pantalla.
- El OSD también avisa cuando activas o desactivas Bloq Mayús.
- **Redmi Buds**: `SUPER+SHIFT+B` cambia de modo (ANC → transparencia → apagado); `SUPER+B` abre Buds Manager.
  En la terminal, `buds status`, `buds battery`, etc. (`buds <comando> --help` para más).

## 15. Bloqueo, inactividad y apagado

- `SUPER+L` bloquea. Se desbloquea con tu contraseña.
- `ALT+F4` abre el menú de apagar / reiniciar / cerrar sesión.
- `SUPER+M` sale de Hyprland **sin preguntar**: cuidado.
- Si no tocas el equipo: a los 29,5 min baja el brillo, a los 30 se bloquea, a los 30,5 se apaga la pantalla y a
- La contraseña se comprueba sola al escribir el último carácter, sin Enter. La pantalla aprende la longitud
  en cada desbloqueo correcto (la primera vez, o tras cambiar de contraseña, usa Enter). Si la nueva es más
  larga, fallará una vez a la longitud vieja: escríbela entera + Enter y ya queda aprendida.
  `sudo` en la terminal hace lo mismo y comparte la longitud aprendida (función en `~/.zshrc`).
  la hora se suspende.

## 16. Cambiar la configuración

Todo está en `~/dotfiles` (enlazado con stow, así que editar `~/.config/hypr/…` es editar el repo).

| Quiero cambiar… | Archivo (`~/.config/hypr/modulos/`) |
|---|---|
| Atajos | `atajos.lua` (los de scratchpads en `scratchpads.lua`; los de layouts en `layouts.lua`) |
| Terminal, lanzador, tecla principal | `programas.lua` |
| Bordes, huecos, transparencia, blur, pestañas de grupos | `apariencia.lua` |
| Animaciones | `animaciones.lua` |
| Teclado, touchpad, gestos, cursor | `entrada.lua` |
| Qué app va a qué workspace, ventanas flotantes | `reglas.lua` |
| Pantallas | `monitores.lua` |
| Programas al iniciar | `autostart.lua` |
| Colores | No a mano: `SUPER+SHIFT+T` o `~/.config/hypr/scripts/tema.sh` |

**Cómo probar un cambio**:

1. Antes de tocar un archivo, haz una copia: `cp archivo.lua archivo.lua.bak-FECHA`.
2. Guarda el archivo y recarga: `hyprctl reload`.
3. Comprueba errores: `hyprctl configerrors` (si sale vacío, todo bien). Un error en un módulo no rompe los demás.
4. Si va bien, haz commit en `~/dotfiles`.

**Herramientas útiles**:
- `SUPER+I`: datos de la ventana activa (class, título…) y copia su class. Es lo que necesitas para escribir una
  regla de ventana.
- `hyprctl getoption input:repeat_rate`: valor actual de una opción (con `:` en lugar de `.`).
- `hyprctl binds`: todos los atajos cargados.
- Nombres de funciones Lua de Hyprland: `/usr/share/hypr/stubs/hl.meta.lua`; argumentos, en la wiki
  (<https://wiki.hypr.land>).

## 17. Si algo falla

| Problema | Solución |
|---|---|
| Los atajos no responden: estás atrapado en un modo (submap) | `Esc`; si no, en una terminal: `hyprctl dispatch 'hl.dsp.submap("reset")'` |
| Sale un aviso rojo arriba tras editar la config | `hyprctl configerrors` dice el archivo y la línea; vuelve a la copia `.bak` si hace falta |
| La pantalla de bloqueo se cuelga | `Ctrl+Alt+F3`, entra con tu usuario, ejecuta `~/.config/hypr/scripts/desbloqueo-emergencia.sh`, vuelve con `Ctrl+Alt+F1` y desbloquea |
| La barra, el lanzador o las notificaciones desaparecieron | Quickshell se cerró: en una terminal, `qs -d` lo vuelve a arrancar (los scripts usan fuzzel mientras tanto) |
| Todo en mayúsculas aunque Bloq Mayús parece apagado | Tienes dos teclados y uno quedó con Bloq Mayús activo: púlsalo en el otro teclado (el OSD avisa) |
| Una app abre en un workspace que no quieres | Mira su class con `SUPER+I` y ajusta o borra su regla en `reglas.lua` |
| Una ventana nueva tapa la terminal desde la que la abriste | Es el *swallow*: al cerrar la app vuelve la terminal. Para desactivarlo: `enable_swallow = false` en `sistema.lua` |
| Prefieres huecos aunque haya una sola ventana | Comenta las 4 líneas de *smart gaps* en `apariencia.lua` |
| Un gesto se siente lento o brusco | Añade `scale = 1.5` (o lo que te guste) a ese gesto en `entrada.lua` |
| Reinstalar todo en otro equipo | `bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)` |
