# Manual de uso

Cómo se usa este escritorio en el día a día: qué es cada cosa, cómo moverse rápido y qué hacer cuando algo falla.
La lista completa de atajos y comandos está en el [README](../README.md#todos-los-comandos); este manual explica
**cuándo y para qué** usar cada uno.

**Nuevo centro del escritorio:** `SUPER+CTRL+ESPACIO`. [Perfiles, privacidad, checkpoints y diagnóstico](escritorio-avanzado.md).

> `SUPER` es la tecla Windows. Casi todo se hace con ella.

## Índice

1. [Ideas básicas](#1-ideas-básicas)
2. [Chuleta: los atajos que más se usan](#2-chuleta-los-atajos-que-más-se-usan)
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
18. [Copias de seguridad, memoria y salud del equipo](#18-copias-de-seguridad-memoria-y-salud-del-equipo)
19. [Texto, voz, recordatorios y tiempo de pantalla](#19-texto-voz-recordatorios-y-tiempo-de-pantalla)
20. [El móvil (KDE Connect)](#20-el-móvil-kde-connect)
21. [Teclado con capas, tema claro, filtros, sonido y escritorio](#21-teclado-con-capas-tema-claro-filtros-sonido-y-escritorio)
22. [Asistente, sesiones, notas, buscador y automatizaciones](#22-asistente-sesiones-notas-buscador-y-automatizaciones)

Apéndice A. [Todos los atajos](#apéndice-a-todos-los-atajos)

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

## 2. Chuleta: los atajos que más se usan

`SUPER+H` abre en pantalla **todos** los atajos, con buscador. La lista completa también está al final de este
manual (apéndice A).

| Atajo | Acción |
|---|---|
| `SUPER+Q` | Terminal |
| `SUPER+R` | Lanzador (apps, cálculos, web, emojis, archivos, recordatorios) |
| `SUPER+H` | Todos los atajos |
| `SUPER+ESPACIO` | Vista general de las ventanas |
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
| `SUPER+SHIFT+E` | Archivos (yazi) |
| `SUPER+D` | Dashboard |
| `SUPER+N` | Centro de control |
| `SUPER+SHIFT+V` | Portapapeles |
| `SUPER+K` | Wi-Fi y Bluetooth |
| `PRINT` | Captura de una región |
| `SUPER+SHIFT+X` | Copiar texto de la pantalla (OCR) |
| `SUPER+ALT+R` | Grabar la pantalla |
| `SUPER+ALT+D` | Dictar con la voz |
| `SUPER+ALT+T` | Traducir lo seleccionado |
| `SUPER+L` | Bloquear |
| `ALT+F4` | Menú de apagado |

## 3. Abrir apps

- **Lanzador** (`SUPER+R`): escribe parte del nombre, `↑↓` para elegir, `Enter` para abrir, `Esc` para cerrar.
  Sirve para mucho más que apps; lo escrito decide qué busca:

  | Escribe | Qué hace |
  |---|---|
  | `firefox`, `ffx` | Apps. También acciones: `blo` (bloquear), `apa` (apagar), `ocr`, `dictar`, `grabar`, `atajos`… |
  | `2*(3+4)` · `5 km a mi` · `30 °C a °F` · `100 USD a COP` | Calcula / convierte; `Enter` copia el resultado |
  | `g método simplex` · `yt …` · `w …` · `gh …` | Busca en Google / YouTube / Wikipedia / GitHub |
  | `:fuego` · `:corazon` · `:sigma` · `:≤` | Emojis y símbolos matemáticos: `Enter` los escribe donde estabas |
  | `/apuntes` (solo `/`: los recientes) | Busca archivos en tu carpeta personal y los abre |
  | `recordar 20m beber agua` · `recordar mañana 7:00 examen` | Recordatorio (ver sección 19) |
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
| `SUPER+SHIFT+E` | Archivos: yazi (gestor de archivos de teclado) |
| `SUPER+S` | El scratchpad libre «magic»: manda cualquier ventana con `SUPER+SHIFT+S` |

- La misma tecla lo muestra y lo esconde. Lo de debajo no se mueve.
- La primera vez la app se abre sola. Después sigue viva escondida: lo que tenías en la terminal o en las notas
  sigue ahí.
- Si Spotify ya estaba abierto en otro workspace, `SUPER+Y` lo trae en vez de abrir otro.
- En las notas, `Espacio w` guarda y `Espacio q` sale.

**Archivos con yazi** (`SUPER+SHIFT+E`, o `y` en la terminal). Tres columnas: carpeta de arriba · actual ·
vista previa (imágenes, PDF, videos y comprimidos se ven ahí mismo).

| Tecla | Qué hace |
|---|---|
| `↑↓` o `j` `k` | Moverse |
| `→` / `Enter` · `←` | Entrar / abrir con su app · subir |
| `Espacio` | Marcar (para copiar o mover varios) |
| `y` · `x` · `p` | Copiar · cortar · pegar |
| `d` · `a` · `r` | A la papelera · crear (termina en `/` para carpeta) · renombrar |
| `/` · `z` | Buscar en la carpeta · saltar a una carpeta (zoxide) |
| `.` | Mostrar / ocultar archivos ocultos |
| `q` · `F1` | Salir · ayuda con todas las teclas |

Con `y` en la terminal, al salir con `q` te quedas en la carpeta donde estabas en yazi.

**USB y discos externos**: se montan solos al conectarlos (en `/run/media/oscar/<nombre>`) y sale un aviso con
un botón para abrirlos en Thunar. Para expulsar: el icono que aparece en la bandeja mientras hay algo conectado,
o `udiskie-umount -a` en la terminal. Espera a que desaparezca antes de sacarlo.

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
| Red | Panel Wi-Fi/Bluetooth | Derecho = nmtui |
| Energía | Cambiar modo | |
| CPU / RAM | Abre btop | |
| Buds | Cambiar modo | Derecho = ANC / apagado · central = Buds Manager |
| Mando | Modo juego | |
| Campana | Centro de control | Derecho = No molestar |

**Dashboard** (`SUPER+D` o 3 dedos hacia abajo): reloj, **clima de Bogotá** (y la probabilidad de lluvia de las
próximas horas), workspaces, calendario, estado del sistema, tiempo de pantalla y la música que suena.
- **Calendario**: flechas o rueda cambian de mes y un clic en el título vuelve a hoy. Un **puntito** bajo un día =
  tienes algo en tu Google Calendar. Debajo, **«Próximo»**: tus eventos y recordatorios (clic en un recordatorio =
  borrarlo). 10 minutos antes de cada evento sale un aviso.
- **Tiempo de pantalla**: hoy por app y, debajo, **los últimos 7 días** (pasa el ratón por una barra).
- **Música**: con la **letra sincronizada** de la canción a la derecha (si lrclib.net la tiene).

**Barra**, además: unas **barras de colores** que bailan con la música (clic = dashboard), un **punto rojo con el
tiempo** mientras grabas la pantalla (clic = parar), un **micrófono rojo** mientras dictas, y la **batería del
móvil** cuando está conectado por KDE Connect.

**Centro de control** (`SUPER+N`): botones rápidos (Wi-Fi, Bluetooth…), volumen, brillo, música y el historial
de notificaciones. Clic derecho en Wi-Fi o Bluetooth abre su lista.

**Wi-Fi y Bluetooth** (`SUPER+K`): dos pestañas (`Tab` cambia). Mientras está abierto busca redes y dispositivos.
- `Enter` o clic: conectar / desconectar. Si la red tiene candado y no está guardada, pide la contraseña en la
  misma fila (el ojo la muestra). Si falla, lo dice en rojo ("Contraseña incorrecta"…).
- Bluetooth: clic en un dispositivo **nuevo** lo empareja, lo marca de confianza y lo conecta.
- `Supr`, clic derecho o la papelera: olvidar la red / el dispositivo. `Espacio`: encender / apagar la radio.

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
Los replays van a `~/Videos/Replays`. El modo automático pausa con batería, privacidad o perfil Mínimo.
El centro del escritorio permite volver a automático después de alternarlo manualmente.

**Grabar la pantalla** (`SUPER+ALT+R`): menú con *Región*, *Pantalla completa*, *con audio* (lo que suena en el
equipo) y *Región como GIF*. Mientras graba hay un **punto rojo con el tiempo** en la barra; para terminar,
`SUPER+ALT+R` otra vez o clic en el punto. Se guarda en `~/Videos/Grabaciones` y la ruta queda copiada.

**Copiar texto de la pantalla (OCR)** (`SUPER+SHIFT+X`, o *Copiar texto* en el menú de capturas): selecciona una
zona (borde azul) y su texto queda en el portapapeles. Sirve para PDFs escaneados, vídeos, fotos de la pizarra…
Funciona sin internet, en español e inglés.

## 13. Modos: juego, concentración, energía y No molestar

| Modo | Atajo | Qué hace |
|---|---|---|
| **Juego** | `SUPER+SHIFT+G` (o solo al abrir Roblox) | Quita animaciones y efectos y silencia notificaciones, para ganar rendimiento |
| **Concentración** | `SUPER+SHIFT+F` | Temporizador de 25, 50 o 90 min con No molestar; WhatsApp, Discord, Roblox y Steam se esconden y vuelven al terminar. Cuenta atrás en la barra (clic = +10 min o terminar) |
| **Energía** | `SUPER+SHIFT+P` | Ahorro → equilibrado → rendimiento |
| **Presentación** | Solo, al conectar un proyector/TV · `SUPER+ALT+P` | Menú: duplicar, extender, solo la externa o solo el portátil. Activa No molestar; al desconectar, todo vuelve |
| **Batería** | Solo, al desenchufar | Pasa a «ahorro» y quita blur y sombras. Al enchufar vuelve tu modo anterior y la apariencia normal. Si con batería eliges otro modo a mano, se respeta |
| **No molestar** | `SUPER+SHIFT+N` | Las notificaciones se guardan sin aparecer |
| **Luz nocturna** | `SUPER+ALT+N` | Pantalla cálida (menos luz azul). Se enciende sola a las 20:30 y se apaga a las 7:00 (horario en `~/.config/hypr/hyprsunset.conf`); el atajo la cambia a mano hasta el siguiente cambio de horario |

**Selector de color**: `SUPER+SHIFT+C` congela la pantalla con una lupa; haz clic en cualquier píxel y su color en hex (p. ej. `#f29718`) queda copiado. `Esc` cancela.

## 14. Sonido, brillo y audífonos

- Las teclas de volumen, micrófono, brillo y música funcionan siempre, incluso con la pantalla bloqueada, y
  muestran un aviso (OSD) en pantalla.
- El OSD también avisa cuando activas o desactivas Bloq Mayús.
- En el centro de control (`SUPER+N`): volumen general y de cada app, **micrófono** (clic en su icono lo
  silencia o activa) y, si hay más de una salida (altavoces, Buds, HDMI), un botón por cada una: clic = el
  sonido va por ahí.
- **Batería**: el botón **Conservar** del centro de control (encendido por defecto) hace que la batería pare
  de cargar en ~80 %: dura muchos más años. Apágalo solo cuando necesites el 100 % (un viaje) y vuelve a
  encenderlo después. El tooltip de la batería en la barra dice en qué modo está.
- **Luz noche** en el centro de control hace lo mismo que `SUPER+ALT+N`.
- **Audífonos**: Buds Manager pausa la música al quitarte un audífono y la reanuda al ponértelo (sensor de oreja).
  Si se **desconectan** solos (sin batería, te alejaste) mientras suena algo, la música se pausa para que no salga
  de golpe por los altavoces.
- **Redmi Buds**: `SUPER+SHIFT+B` cambia de modo (ANC → transparencia → apagado); `SUPER+B` abre Buds Manager.
  En la terminal, `buds status`, `buds battery`, etc. (`buds <comando> --help` para más).

## 15. Bloqueo, inactividad y apagado

- `SUPER+L` bloquea. Se desbloquea con tu contraseña.
- La contraseña se comprueba sola al escribir el último carácter, sin Enter. La pantalla aprende la longitud
  en cada desbloqueo correcto (la primera vez, o tras cambiar de contraseña, usa Enter). Si la nueva es más
  larga, fallará una vez a la longitud vieja: escríbela entera + Enter y ya queda aprendida.
  `sudo` en la terminal hace lo mismo y comparte la longitud aprendida (función en `~/.zshrc`).
- `ALT+F4` abre el menú de apagar / reiniciar / cerrar sesión.
- `SUPER+M` sale de Hyprland **sin preguntar**: cuidado.
- Si no tocas el equipo: a los 29,5 min baja el brillo, a los 30 se bloquea, a los 30,5 se apaga la pantalla y a
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
| Apps de los scratchpads | `scratchpads.lua` |
| Ciudad del clima | `~/.config/quickshell/Clima.qml` (lat, lon, lugar) |
| Calendarios de Google | `~/.config/calendario/url` (una dirección iCal secreta por línea; **no va al repo**) |
| Límites de tiempo por app | `~/.config/tiempo-pantalla/limites.json` |
| Modelo del dictado | `~/.config/dictado/modelo` (`small` o `base`) |
| Qué se apaga con batería | `bateria.lua` (y el perfil, en `~/.config/quickshell/Cargador.qml`) |
| Colores | No a mano: `SUPER+SHIFT+T` o `~/.config/hypr/scripts/tema.sh` |

**Si cambias o añades un atajo**: apúntalo en la tabla que toque del `README.md` (es la única lista: de ahí
la lee la chuleta `SUPER+H`) y ejecuta `~/dotfiles/docs/actualizar-atajos.py`, que lo copia al apéndice A.

**Cómo probar un cambio**:

1. No hace falta copiar el archivo antes: git guarda cada versión (`git diff` muestra qué cambiaste y
   `git checkout -- archivo` lo deja como en el último commit). Además snapper guarda `/home` cada hora
   (`snapper -c home list`; los archivos de cada snapshot están en `/home/.snapshots/N/snapshot/`).
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
| Sale un aviso rojo arriba tras editar la config | `hyprctl configerrors` dice el archivo y la línea; `git checkout -- archivo` lo deja como en el último commit |
| La pantalla de bloqueo se cuelga | `Ctrl+Alt+F3`, entra con tu usuario, ejecuta `~/.config/hypr/scripts/desbloqueo-emergencia.sh`, vuelve con `Ctrl+Alt+F1` y desbloquea |
| La barra, el lanzador o las notificaciones desaparecieron | Quickshell se cerró: en una terminal, `qs -d` lo vuelve a arrancar (los scripts usan fuzzel mientras tanto) |
| Todo en mayúsculas aunque Bloq Mayús parece apagado | Tienes dos teclados y uno quedó con Bloq Mayús activo: púlsalo en el otro teclado (el OSD avisa) |
| Una app abre en un workspace que no quieres | Mira su class con `SUPER+I` y ajusta o borra su regla en `reglas.lua` |
| Una ventana nueva tapa la terminal desde la que la abriste | Es el *swallow*: al cerrar la app vuelve la terminal. Para desactivarlo: `enable_swallow = false` en `sistema.lua` |
| Prefieres huecos aunque haya una sola ventana | Comenta las 4 líneas de *smart gaps* en `apariencia.lua` |
| Un gesto se siente lento o brusco | Añade `scale = 1.5` (o lo que te guste) a ese gesto en `entrada.lua` |
| Necesito el menú de arranque (otro sistema, volver a un snapshot) | Mantén **Esc** (o Shift) justo al encender: GRUB está oculto y espera solo 1 s |
| La Wi-Fi de un hotel/aeropuerto no abre su página de acceso | `dns-cifrado off`, entra, y luego `dns-cifrado on` |
| Aviso «⚠ Disco» | El SSD empieza a fallar: `respaldo ahora` con el disco TOSHIBA conectado, y piensa en cambiarlo |
| La barra/atajos de Quickshell no responden (`qs ipc call …` dice «Not ready to accept queries yet») | Pasa tras muchas recargas en caliente: `pkill -x qs; qs &` (o cerrar sesión y entrar). Si vuelve a pasar justo al arrancar, revisa que ningún archivo que lea un singleton falte |
| El dictado no escribe nada | ¿Micrófono correcto? Prueba `dictado.sh` dos veces y mira la notificación. La primera vez tarda más (carga el modelo) |
| El móvil no aparece en KDE Connect | Mismo Wi-Fi, app KDE Connect abierta en el móvil y el firewall abierto (sección 20) |
| No salen eventos en el dashboard | `~/.config/hypr/scripts/eventos.py --lista`: si no lista nada, revisa la dirección de `~/.config/calendario/url` |
| Reinstalar todo en otro equipo | `bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)` |

## 18. Copias de seguridad, memoria y salud del equipo

**Copias de seguridad.** Van al disco externo **TOSHIBA EXT**, carpeta `OSCAR/hyprland`, **cifradas** (en Windows
solo se ven archivos ilegibles: no los toques ni los borres). Lo demás del disco no se toca.

- **Son automáticas**: conecta el disco y, si la última copia tiene más de 20 h, empieza sola. Sale un aviso
  «Copiando… no desconectes» y otro «Copia de seguridad hecha» al terminar. Solo copia lo que cambió (segundos).
- Si pasan **7 días** sin copia, un aviso te lo recuerda una vez al día.
- Se guardan 7 copias diarias, 4 semanales y 12 mensuales; las más viejas se borran solas.
- **Qué se copia**: Documents, Projects, proyectos, Imágenes, Pictures, `~/.config`, `~/.local/share`
  (sin Steam ni cachés), llaves SSH/GPG, dotfiles y del sistema: `/etc` entero (incluye las contraseñas Wi-Fi),
  `/usr/local` y las listas de paquetes y servicios. Qué se excluye: `/etc/respaldo/excluir`.
- **La contraseña** está en `/etc/respaldo/clave` (`sudo cat /etc/respaldo/clave`). Apúntala **fuera** del
  portátil: si se pierde el portátil, sin ella el disco no sirve de nada.

| Comando | Qué hace |
|---|---|
| `respaldo estado` | Cuándo fue la última copia, cuántas hay y espacio libre |
| `respaldo ahora` | Copiar ya (aunque haya una reciente) |
| `respaldo lista` | Todas las copias con su fecha |
| `respaldo montar` | Abre las copias como carpetas en `/mnt/respaldo/snapshots/<fecha>/…`: copia de ahí lo que necesites; `Ctrl+C` cierra |
| `respaldo comprobar` | Lee todas las copias para asegurar que no hay nada dañado (tarda; una vez al mes) |

**Recuperar un archivo**: `respaldo montar` en una terminal, y en otra (o en Thunar) ve a
`/mnt/respaldo/snapshots/latest/home/oscar/…` y cópialo. Para algo de hace poco (horas) es más rápido snapper:
`snapper -c home list` y `/home/.snapshots/N/snapshot/oscar/…`.

**En otro equipo** (portátil nuevo, perdido o roto): instala `restic`, conecta el disco y
`restic -r "/ruta/al/disco/OSCAR/hyprland" mount /mnt` (te pide la contraseña). Para dejarlo todo como antes:
primero `instalar.sh` de los dotfiles, luego copiar de vuelta las carpetas.

**Si el disco no se monta** (pasa si se desconectó de Windows sin «Quitar hardware de forma segura»): el kernel
lo marca como «sucio». `sudo ntfsfix -d /dev/sdX1` (mira cuál con `lsblk -f`) quita la marca. Mejor aún: en
Windows, apaga el «Inicio rápido» y expúlsalo siempre antes de desconectarlo.

**Memoria llena.** Si la RAM y la swap se acaban, en vez de congelarse el equipo, **earlyoom** cierra UNA app y
avisa. Elige primero pestañas del navegador y apps web (WhatsApp, Discord, VS Code); nunca Hyprland, la barra,
kitty ni el audio. Si te cierra algo, es que tenías demasiado abierto. Configuración: `/etc/default/earlyoom`
(gestionado desde `instalar/sistema-base.sh`).

**Salud del SSD.** `smartd` lo vigila: si aparecen errores, se gasta la reserva o pasa de 75 °C, sale un aviso
«⚠ Disco». Verlo a mano: `sudo smartctl -a /dev/nvme0n1` (lo importante: *Percentage Used* = desgaste,
*Media and Data Integrity Errors* = 0). En noviembre de 2026: 7 % de desgaste, 0 errores.

**Firmware** (BIOS, SSD…): se comprueba solo cada semana. `fwupdmgr get-updates` para ver si hay y
`fwupdmgr update` para instalar (con el cargador puesto).

**DNS cifrado.** Las consultas DNS (qué web visitas) van cifradas a Quad9, que además bloquea dominios de malware.
`dns-cifrado estado` dice si está activo. En una Wi-Fi con página de acceso (hotel, aeropuerto) que no carga:
`dns-cifrado off`, entra, y `dns-cifrado on`.

**Arranque**: unos 20 s. De ellos ~9 s son de la BIOS antes de Linux: si quieres arañarlos, entra en la BIOS
(F2 al encender) y activa *Fast Boot* (o *Quick Boot*).

**Hibernación.** `systemctl hibernate` guarda la sesión en el disco (`/swap/swapfile`, 16 GB) y apaga del
todo: no gasta batería y al encender vuelve todo como estaba. `systemctl suspend-then-hibernate` suspende
y, a las 2 h, hiberna solo (el plazo está en `/etc/systemd/sleep.conf.d/hibernar.conf`). La suspensión
normal (tapa, 1 h de inactividad, «Suspender» del lanzador) sigue igual.

## 19. Texto, voz, recordatorios y tiempo de pantalla

**Dictar** (`SUPER+ALT+D`): pulsa, habla, vuelve a pulsar. El texto se escribe donde esté el cursor (y queda
copiado). Mientras escucha hay un micrófono rojo en la barra. Usa Whisper **en tu equipo**: la voz no sale a
internet. Tarda unos segundos por frase (modelo `small`, preciso); con `echo base > ~/.config/dictado/modelo` va
más rápido pero se equivoca más. Si el micrófono estaba silenciado, lo activa solo mientras grabas. Si te olvidas,
se para solo a los 2 minutos.

**Traducir** (`SUPER+ALT+T`): selecciona un texto con el ratón (en cualquier app) y pulsa. La traducción sale en una
notificación y queda copiada. Otro idioma → español; si ya está en español → inglés. Necesita internet.

**Recordatorios**: en el lanzador (`SUPER+R`) escribe `recordar` (o `rec`) + cuándo + qué:

| Ejemplo | Cuándo avisa |
|---|---|
| `recordar 20m beber agua` | En 20 minutos (también `1h`, `1h30`, `45 minutos`, `90s`) |
| `recordar 18:30 llamar a mamá` · `recordar 6pm …` | Hoy a esa hora (si ya pasó, mañana) |
| `recordar mañana 7:00 examen` | Mañana a esa hora |

Avisa con notificación y sonido. Se guardan en disco: si el equipo estaba apagado a esa hora, avisa al encender.
Los próximos se ven en el dashboard (clic en uno = borrarlo).

**Tiempo de pantalla**: el dashboard muestra hoy y los últimos 7 días. Para ponerte **límites**, edita
`~/.config/tiempo-pantalla/limites.json` (minutos al día por *class* de la ventana; `SUPER+I` te dice la class):

```
{
  "org.vinegarhq.Sober": 60,
  "vesktop": 60
}
```

Al llegar al límite sale un aviso, y otro cada 30 min de más. Mientras la pantalla está bloqueada no cuenta.

## 20. El móvil (KDE Connect)

Con KDE Connect el móvil Android y el portátil se hablan por el Wi-Fi: notificaciones del móvil en el escritorio,
portapapeles compartido, enviar archivos en los dos sentidos, batería del móvil en la barra, usar el móvil como
mando o ratón, y hacerlo sonar cuando no lo encuentras.

**Emparejar (una vez):**

1. Abre los puertos de KDE Connect en el firewall, **solo para la red local** (una vez, en una terminal):
   ```
   for r in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do for p in tcp udp; do sudo ufw allow from $r to any port 1714:1764 proto $p comment 'KDE Connect'; done; done
   ```
2. Instala **KDE Connect** en el móvil (Play Store o F-Droid) y conéctalo al mismo Wi-Fi.
3. En el portátil, abre KDE Connect (lanzador: `kde` → *KDE Connect*, o el icono del móvil en la bandeja),
   elige tu móvil y pulsa *Solicitar emparejamiento*; acepta en el móvil.
4. En el móvil, dale los permisos que pide cada función (notificaciones, archivos…).

**Uso**: la batería del móvil sale en la barra (clic = KDE Connect, clic derecho = hacerlo sonar). Enviar un
archivo: icono de la bandeja → *Enviar archivo*, o `~/.config/hypr/scripts/movil.sh enviar archivo.pdf`. En el
lanzador: *Buscar el móvil*.

## 21. Teclado con capas, tema claro, filtros, sonido y escritorio

### Bloq Mayús reconvertida (keyd)

La tecla Bloq Mayús está en el mejor sitio del teclado y casi no se usa. Ahora hace tres cosas:

- **Un toque** = `Esc` (cerrar menús, salir de modos en nvim).
- **Mantenida** = `Ctrl`: `Bloq Mayús+C` copia, `+T` abre pestaña, `+W` la cierra.
- **Mantenida + `H` `J` `K` `L`** = flechas ← ↓ ↑ →, y **`Y` `U` `I` `O`** = Inicio, Av Pág, Re Pág, Fin.
  Con Shift además selecciona texto. Sirve en cualquier app, sin mover la mano a las flechas.

Las mayúsculas fijas siguen existiendo: `Shift+Bloq Mayús`.

keyd trabaja por debajo de Hyprland (también en la TTY y el login) y junta los dos teclados en uno,
así que el Bloq Mayús ya no puede quedar activado en un teclado y no en el otro.

- Cambiar las capas: edita `~/dotfiles/keyd/default.conf`, cópialo con
  `sudo install -m644 ~/dotfiles/keyd/default.conf /etc/keyd/default.conf` y `sudo keyd reload`.
- Si el teclado hace algo raro: **Retroceso + Esc + Enter** a la vez apaga keyd.
- Quitarlo del todo: `sudo systemctl disable --now keyd`.

### Tema claro y oscuro

`SUPER+CTRL+T` cambia entre claro y oscuro. Es independiente de `SUPER+SHIFT+T` (Ayu o colores del
wallpaper): las cuatro combinaciones funcionan.

El escritorio es **siempre oscuro** salvo que lo cambies tú. Si algún día quieres que cambie solo
(claro a las 6:30, oscuro a las 18:00), `tema.sh auto on`; las horas están al principio de
`modulos/tema.lua`.

Cambian con el tema: Hyprland, toda la interfaz de Quickshell, kitty, btop, las apps GTK y lo que
pregunta al sistema (Firefox y las webs con modo oscuro automático). No cambian solos: nvim, VS Code,
Discord y Spotify, que tienen su tema Ayu oscuro fijo.

### Filtros de pantalla

`SUPER+ALT+S` abre el menú: **grises** (leer sin distracciones), **papel** (sepia de poco contraste,
lectura larga), **colores vivos** (juegos y vídeo) e **invertido** (un PDF blanco pasa a oscuro sin
cambiar los tonos). El filtro elegido se mantiene hasta que eliges «Ninguno», también tras reiniciar.
No aparecen en capturas ni grabaciones. Los filtros son archivos GLSL en `~/.config/hypr/shaders/`.

### Sonido de las bocinas

`SUPER+ALT+E`: **Música** (más cuerpo, menos sonido «a caja», más brillo y graves realzados), **Voz**
(clases, vídeos y llamadas: se entiende mejor y a volumen parejo) o **Sin efectos** (cierra
EasyEffects). Con audífonos los efectos se saltan solos. Para afinar un perfil de oído, abre
«Easy Effects» desde el lanzador, ajusta y guarda el perfil con el mismo nombre.

### Wallpapers con transición y widgets de escritorio

Los fondos cambian con una transición (awww): al elegir uno, el nuevo crece desde donde está el
cursor; la rotación automática entra con un barrido; con batería es un fundido corto.

En un workspace vacío aparecen sobre el fondo el reloj, la fecha, el clima, una frase del día y, a la
derecha, tus próximos eventos y recordatorios. Al abrir una ventana se desvanecen.
`qs ipc call escritorio toggle` los esconde.

### Anotar capturas

`SUPER+SHIFT+A` captura una región y abre el editor (satty). También puedes pulsar **Anotar** en el
aviso de cualquier captura. Dentro: flecha, línea, recuadro, texto, números (para pasos 1-2-3),
resaltador, difuminar y recortar. `Enter` copia, guarda (`…_anotada.png`) y sale; `Ctrl+Z` deshace.

### Historial de la terminal (atuin)

`Ctrl+R` abre el buscador: escribe cualquier parte del comando. Muestra cuándo lo corriste, cuánto
tardó y si falló. `Ctrl+R` otra vez cambia el filtro: todo el historial → esta sesión → esta carpeta.
`Enter` lo ejecuta, `Tab` lo deja en la línea para editarlo. Todo queda en este equipo.

---

## 22. Asistente, sesiones, notas, buscador y automatizaciones

### Asistente local (IA)

Funciona sin internet con ollama y el modelo `gemma3:4b` (unos 4 GB de RAM mientras responde; se
descarga de la memoria a los 10 minutos sin usarlo). Responde a unas 8 palabras por segundo.
Lee hasta 32 000 caracteres de texto (unas 10 páginas) con un contexto de 16 384 tokens; un texto
tan largo tarda 3-4 minutos en empezar a responder, porque corre solo en la CPU. Ambos límites
están al principio de `ia.py`.

- **Sobre un texto**: selecciónalo (o cópialo) y pulsa `SUPER+ALT+A`. Elige resumir, corregir
  ortografía, redactar mejor, explicar (sirve para errores de terminal) o traducir.
- **Pregunta suelta**: `SUPER+R` y escribe `ia cómo se calcula una máscara de subred`.
- En el panel: escribe otra pregunta sobre el mismo texto y `Enter`; con el campo vacío, `Enter` copia
  la respuesta y cierra; `Ctrl+Enter` la escribe donde estabas (útil tras «corregir»).

Es un modelo pequeño: redacta y resume bien, pero se equivoca con datos y cálculos. Compruébalo.
Otro modelo: `ollama pull qwen3:4b` y escribe su nombre en `~/.config/ia/modelo`.

### Sesiones de trabajo

`SUPER+ALT+Enter` abre el menú: **Universidad**, **Programar** y **Descanso**. Cada una abre sus apps
en su workspace; lo que ya estaba abierto no se duplica. Las sesiones de ejemplo son una suposición:
cámbialas en `~/.config/hypr/modulos/sesiones.lua` (qué apps, qué direcciones abre Firefox, en qué
workspace). La «clase» de una ventana se ve con `SUPER+I`.

### Notas rápidas

`SUPER+SHIFT+O`, escribe y `Enter`: se añade una línea con fecha y hora al final de
`~/Documents/notas.md` (el mismo archivo de `SUPER+O`). `SUPER+ALT+O` guarda lo que tengas
seleccionado. En el lanzador: `nota comprar cable`.

### Buscador universal

En el lanzador (`SUPER+R`), una letra y un espacio cambian dónde se busca: `v` ventanas, `n` dentro de
tus notas, `c` portapapeles, `t` pestañas de Firefox y `p` contraseñas.

Las contraseñas necesitan un gestor. La primera vez, `p algo` + `Enter` abre la guía: Bitwarden
(recomendado; también en el móvil) o `pass` (todo local). Después, `p gmail` + `Enter` escribe la
contraseña donde esté el cursor, sin pasar por el portapapeles.

### Móvil, Syncthing y Tailscale

- **Móvil** (`SUPER+ALT+M`, o clic en su batería en la barra): hacerlo sonar, enviarle lo copiado o un
  archivo, ver sus archivos. Antes hay que emparejarlo en la app KDE Connect.
- **Syncthing** (carpetas sincronizadas sin nube): abre http://127.0.0.1:8384, instala Syncthing en
  el móvil, escanea el código QR de «Acciones → Mostrar ID» y comparte una carpeta.
- **Tailscale** (entrar al portátil desde fuera): `sudo tailscale up --ssh` y abre el enlace que
  muestra para iniciar sesión; instala la app en el móvil con la misma cuenta. Desde otro equipo
  tuyo: `ssh oscar@orion`.

Los puertos de Syncthing y la interfaz de Tailscale se abren en el cortafuegos con el paso 16 de
`~/dotfiles/instalar/sistema-base.sh`. Sin eso Syncthing funciona igual, pero más lento (por relés).

### Automatizaciones

- **Resumen del día**: aparece solo la primera vez que usas el equipo cada día. A mano: «Resumen del
  día» en el lanzador.
- **Actualizaciones**: un paquete con el número en la barra cuando hay pendientes. Rojo = hay
  noticias de Arch sin leer (se muestran antes de actualizar). Clic = actualizar.
- **Pausas**: aviso tras 50 minutos seguidos. Cambiar el tiempo: `minutos` en `Pausas.qml`.
- **Lugares**: `~/.config/lugares.conf` dice qué hacer al conectarte a cada Wi-Fi (energía, volumen de
  las bocinas, No molestar). De serie: en casa no cambia nada y en cualquier otra red las bocinas se
  silencian. Añade la línea de tu universidad con el nombre exacto de su Wi-Fi.

---

## Apéndice A. Todos los atajos

<!-- atajos:inicio — NO editar a mano: sale del README con docs/actualizar-atajos.py -->

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
| `SUPER+SHIFT+N` | Alternar No molestar manual (respeta los motivos automáticos) |
| `SUPER+CTRL+ESPACIO` | Centro del escritorio: perfiles, privacidad, checkpoints, replay y diagnóstico |
| `SUPER+CTRL+P` | Privacidad: pausa replay, oculta títulos de la barra y activa No molestar |
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

<!-- atajos:fin -->
