# Manual de usuario · Tu escritorio, de principio a fin

**Arch Linux · Hyprland · Quickshell · Ayu**

[Inicio](../README.md) · **Uso diario** · [Manual técnico](manual-tecnico.md) · [Guía de estudio](guia-estudio.md)

Un escritorio para estudiar, programar, comunicarte y retomar lo que estabas haciendo.
Aquí encontrarás cómo usar cada herramienta, qué guarda y cómo salir de un problema.
`SUPER` es la tecla Windows; `Return` y `Enter` se refieren a la tecla Intro.


## Tu primera sesión en cinco minutos

1. Abre una terminal con **SUPER+Q** y el navegador desde **SUPER+R**, escribiendo `firefox`.
2. Usa **SUPER+1** y **SUPER+2** para cambiar de espacio; **SUPER+ESPACIO** muestra las ventanas.
3. Abre **SUPER+N** para ajustar sonido y brillo; su pestaña **Conexiones** conecta Wi-Fi o Bluetooth.
4. Busca cualquier función en **SUPER+R**. Si olvidas una tecla, consulta **SUPER+H**.
5. Escribe «empezar» en el lanzador (**SUPER+R**) para lanzar una rutina y abre **SUPER+D** para consultar tu día.
6. Al alejarte, **SUPER+L** bloquea. Guarda tu trabajo antes de cerrar sesión.

> **Para empezar:** aprende seis teclas: Q, R, E, N, H y L con SUPER.
> Las funciones de móvil, calendario, IA, respaldo externo y conservación de batería necesitan
> configuración o hardware compatible. keyd está desactivado; las apps de respaldo no arrancan
> junto a Quickshell. El agente requiere Ollama y sus modelos; su configuración se explica en el capítulo 27.

## Encuentra lo que necesitas

- [Tu primera sesión en cinco minutos](#tu-primera-sesión-en-cinco-minutos)
- [1. Ideas básicas](#1-ideas-básicas)
- [2. Chuleta: los atajos que más se usan](#2-chuleta-los-atajos-que-más-se-usan)
- [3. Abrir apps](#3-abrir-apps)
- [4. Manejar ventanas](#4-manejar-ventanas)
- [5. Workspaces y navegación](#5-workspaces-y-navegación)
- [6. Layouts: cómo se reparten las ventanas](#6-layouts-cómo-se-reparten-las-ventanas)
- [7. Grupos: ventanas en pestañas](#7-grupos-ventanas-en-pestañas)
- [8. Scratchpads: apps que aparecen y desaparecen](#8-scratchpads-apps-que-aparecen-y-desaparecen)
- [9. Gestos del touchpad](#9-gestos-del-touchpad)
- [10. Barra, Brújula y centro de control](#10-barra-brújula-y-centro-de-control)
- [11. Portapapeles, wallpapers y colores](#11-portapapeles-wallpapers-y-colores)
- [12. Capturas y grabación](#12-capturas-y-grabación)
- [13. Modos: juego, concentración, energía y No molestar](#13-modos-juego-concentración-energía-y-no-molestar)
- [14. Sonido, brillo y audífonos](#14-sonido-brillo-y-audífonos)
- [15. Bloqueo, inactividad y apagado](#15-bloqueo-inactividad-y-apagado)
- [16. Cambiar la configuración](#16-cambiar-la-configuración)
- [17. Si algo falla](#17-si-algo-falla)
- [18. Copias de seguridad, memoria y salud del equipo](#18-copias-de-seguridad-memoria-y-salud-del-equipo)
- [19. Texto, voz, recordatorios y tiempo de pantalla](#19-texto-voz-recordatorios-y-tiempo-de-pantalla)
- [20. El móvil (KDE Connect)](#20-el-móvil-kde-connect)
- [21. Teclado con capas, tema claro, filtros, sonido y escritorio](#21-teclado-con-capas-tema-claro-filtros-sonido-y-escritorio)
- [22. Asistente, sesiones, notas, buscador y automatizaciones](#22-asistente-sesiones-notas-buscador-y-automatizaciones)
- [Tres recorridos para el día a día](#tres-recorridos-para-el-día-a-día)
- [23. Los cuatro centros](#23-los-cuatro-centros)
- [24. Lanzador: hacer](#24-lanzador-hacer)
- [25. Brújula: ver](#25-brújula-ver)
- [26. Centro de control: ajustar](#26-centro-de-control-ajustar)
- [27. Agente: pedir](#27-agente-pedir)
- [28. Herramientas que conviene conocer](#28-herramientas-que-conviene-conocer)
- [Apéndice A. Todos los atajos](#apéndice-a-todos-los-atajos)

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
| `SUPER+O` | Agente: preguntas, memoria y acciones del escritorio |
| `SUPER+CTRL+SHIFT+O` | Notas en un scratchpad |
| `SUPER+SHIFT+E` | Archivos (yazi) |
| `SUPER+D` | Brújula: tu día |
| `SUPER+N` | Centro de control |
| `SUPER+SHIFT+V` | Portapapeles |
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
barra para meterla. Una ventana agrupada tiene el borde del segundo color del tema (`acento2`), distinto del de una ventana normal.

## 8. Scratchpads: apps que aparecen y desaparecen

| Tecla | Qué aparece |
|---|---|
| `SUPER+Return` | Una terminal flotante, centrada |
| `SUPER+Y` | Spotify |
| `SUPER+CTRL+SHIFT+O` | Notas: nvim con `~/Documents/notas.md` |
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

**USB y discos externos**: se montan solos al conectarlos (en `/run/media/<usuario>/<nombre>`) y sale un aviso con
un botón para abrirlos en Thunar. Para expulsar: el icono que aparece en la bandeja mientras hay algo conectado,
o `udiskie-umount -a` en la terminal. Espera a que desaparezca antes de sacarlo.

## 9. Gestos del touchpad

Regla: **3 dedos = navegar · 4 dedos = mover la ventana · con SUPER = lo delicado**.

| Gesto | Acción |
|---|---|
| 3 dedos ← → | Cambiar de workspace |
| 3 dedos ↑ | Scratchpad «magic» |
| 3 dedos ↓ | Brújula › Hoy |
| Abrir 3 dedos | Pantalla completa (otra vez = salir) |
| Juntar 3 dedos | Flotante ↔ mosaico |
| 4 dedos | Mover la ventana |
| `SUPER` + 4 dedos | Redimensionar |
| `SUPER` + 3 dedos ↓ | Cerrar la ventana |
| `SUPER` + pellizco | Lupa alrededor del cursor |

Los gestos siguen a los dedos: si sueltas a medias, se cancelan.

**Clics del touchpad**: tocar = clic. Al hundirlo, cuenta el número de dedos: 1 = clic, 2 = clic derecho,
3 = clic central. Mientras escribes, el touchpad se ignora.

## 10. Barra, Brújula y centro de control

**Barra** (arriba). Casi todo se puede pulsar:

| Zona | Clic | Otros |
|---|---|---|
| Números de workspace | Ir | Rueda = siguiente / anterior |
| Reloj | Brújula › Hoy | Al pasar el ratón: la fecha |
| Volumen | Silenciar | Rueda = volumen |
| Brillo | — | Rueda = brillo |
| Red | Panel Wi-Fi/Bluetooth | Derecho = nmtui |
| Energía | Cambiar modo | |
| CPU / RAM (solo por encima del 85 %) | Abre btop | |
| Buds | Cambiar modo | Derecho = ANC / apagado · central = Buds Manager |
| Mando (solo con el modo juego activo) | Modo juego | |
| Campana | Centro de control | Derecho = No molestar |

**Brújula › Hoy** (`SUPER+D`, clic en el reloj o 3 dedos hacia abajo; antes era el dashboard): reloj, **clima de Bogotá** (y la probabilidad de lluvia de las
próximas horas), la frase del asistente, ideas para hoy, calendario, estado del sistema y tiempo de pantalla.
Las otras dos pestañas: **Línea de tiempo** (el día, las reglas automáticas y la sesión anterior) y **Salud**.
- **Calendario**: flechas o rueda cambian de mes y un clic en el título vuelve a hoy. Un **puntito** bajo un día =
  tienes algo en tu Google Calendar (evento o tarea). Clic en un día = elegirlo. Debajo, **«＋ Nuevo evento o
  tarea»** lo crea en tu Google Calendar / Google Tasks ese día (hora vacía = todo el día; el botón de la duración
  cambia con clic). Debajo, **«Próximo»**: eventos, tareas ☐ y recordatorios (clic en un recordatorio = borrarlo; en
  una tarea = marcarla hecha). 10 minutos antes de cada evento sale un aviso.
  También desde el lanzador: `evento mañana 15:00 dentista`, `evento viernes clase`, `tarea 20/11 entregar informe`.
- **Tiempo de pantalla**: hoy por app y, debajo, **los últimos 7 días** (pasa el ratón por una barra).

**Barra**, además: unas **barras de colores** que bailan con la música (clic = centro de control, con los controles de la música), un **punto rojo con el
tiempo** mientras grabas la pantalla (clic = parar), un **micrófono rojo** mientras dictas, y la **batería del
móvil** cuando está conectado por KDE Connect.

**Centro de control** (`SUPER+N`): todo lo que se ajusta. Arriba, botones rápidos (Wi-Fi, Bluetooth…) y los
cuatro **perfiles** (cristal, lectura, mínimo, rendimiento). Debajo, cuatro pestañas:
- **Inicio**: volumen (general y por app), micrófono, brillo, música y las notificaciones con «No molestar».
- **Conexiones**: Wi-Fi y Bluetooth (también con clic derecho en sus botones o clic en la red de la barra).
- **Móvil**: batería y acciones del móvil (sonar, abrir lo copiado, enviar archivo, sus archivos, SMS) y
  «Avisos y respuestas». Sin conexión, un botón para abrir KDE Connect.
- **Más**: checkpoints de ventanas, privacidad, juego automático, diagnóstico y replay.

**Wi-Fi y Bluetooth** (centro de control › pestaña **Conexiones**, o clic en la red de la barra): dos pestañas (`Tab` cambia). Mientras está a la vista busca redes y dispositivos.
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
  Los fondos están en `~/Imágenes/wallpapers`; la rotación automática cambia el fondo cada
  **17,5 minutos** y su temporizador vuelve a empezar al recargar Hyprland.
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
Centro de control › Más › **Juego automático** lo devuelve a automático después de alternarlo a mano.

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
| **No molestar** | `SUPER+SHIFT+N` | Silencia avisos ordinarios; las notificaciones críticas mantienen su política habitual |
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
- `SUPER+M` abre el mismo menú de apagado que `ALT+F4` (ya no sale sin preguntar).
- Si no tocas el equipo, **enchufado**: a los 8 min baja el brillo, a los 10 se bloquea, a los 15 se apaga la
  pantalla y a la hora se suspende. **Con batería**: 3, 5 y 6 min, y se suspende a los 15. Cambia solo al enchufar o
  desenchufar (`~/.config/hypr/hypridle.conf` y `hypridle-bateria.conf`).

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
| Crear eventos y tareas en Google | `~/.config/calendario/cliente.json` (credencial OAuth «App de escritorio» de Google Cloud con Calendar API y Tasks API activadas) y `token.json` (lo crea `gcal.py conectar`). **Ninguno va al repo** |
| Límites de tiempo por app | `~/.config/tiempo-pantalla/limites.json` |
| Modelo del dictado | `~/.config/dictado/modelo` (`small` o `base`) |
| Qué se apaga con batería | `bateria.lua` (y el perfil, en `~/.config/quickshell/Cargador.qml`) |
| Colores | No a mano: `SUPER+SHIFT+T` o `~/.config/hypr/scripts/tema.sh` |

**Si cambias o añades un atajo**: actualiza el apéndice A de este manual. La chuleta
`SUPER+H` y la búsqueda de atajos del lanzador leen esa misma fuente; no hay que generar otra copia.

**Cómo probar un cambio**:

1. Revisa `git status --short` y `git diff` en `~/dotfiles`; guarda una copia de los cambios
   pendientes antes de experimentar. Los enlaces de Stow apuntan al repositorio: guardar un archivo
   puede cambiar la sesión activa. Git solo recupera contenido que hayas guardado en su historial.
2. Guarda el archivo y recarga con `hyprctl reload` para Lua; Quickshell recarga QML al guardar.
3. Consulta `hyprctl configerrors`. Una salida vacía confirma que no reporta errores de configuración;
   comprueba también la función que cambiaste.
4. Revisa el diff antes de hacer un commit. Consulta el manual técnico para validación y reversión.

**Herramientas útiles**:
- `SUPER+I`: datos de la ventana activa (class, título…) y copia su class. Es lo que necesitas para escribir una
  regla de ventana.
- `hyprctl getoption input:repeat_rate`: valor actual de una opción (con `:` en lugar de `.`).
- `hyprctl binds`: todos los atajos cargados.
- Nombres de funciones Lua de Hyprland: `/usr/share/hypr/stubs/hl.meta.lua`; argumentos, en la wiki
  (<https://wiki.hypr.land>).

## 17. Si algo falla

Al fallar una recarga de Quickshell aparece un aviso persistente con **Ver detalle** y **Reintentar**.
La interfaz anterior continúa activa; el aviso desaparece cuando la configuración vuelve a cargar.
No molestar no oculta este error. Si Quickshell no llega a arrancar, consulta el diagnóstico desde
terminal del manual técnico antes de iniciar otra instancia.

Los controles rápidos distinguen **Activado**, **Desactivado**, **Aplicando…**, **No disponible** y
**Reintentar**. El estado cambia cuando el servicio confirma la orden. Un error muestra el motivo;
puedes volver a pulsar el control o **Consultar** para comprobar servicios que se hayan recuperado.
Los otros botones siguen utilizables mientras termina una orden.

Brújula muestra la última sincronización de la agenda y permite **Reintentar**. Si no hay conexión,
conserva la copia anterior identificada como desactualizada. «Agenda sin configurar» significa que
falta la dirección iCal, no que no tengas eventos. Los modos de teclado aparecen en la barra:
**Redimensionar** permite cambiar el tamaño con flechas y salir con Esc/Enter; **Lanzar** muestra
sus teclas al pasar el ratón. También puedes pulsar el indicador para salir del modo.

| Problema | Solución |
|---|---|
| Los atajos no responden: estás atrapado en un modo (submap) | `Esc`; si no, en una terminal: `hyprctl dispatch 'hl.dsp.submap("reset")'` |
| Sale un aviso rojo arriba tras editar la config | `hyprctl configerrors` dice el archivo y la línea; revisa el diff y recupera solo el cambio que causó el error (manual técnico, sección 12) |
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
| No salen eventos en Brújula › Hoy | `~/.config/hypr/scripts/eventos.py --lista`: si no lista nada, revisa la dirección de `~/.config/calendario/url` |
| No deja crear eventos o tareas («No se pudo guardar») | `~/.config/hypr/scripts/gcal.py estado`. Si `conectado` es `false` o la sesión caducó: `gcal.py conectar`. Si la app de Google Cloud sigue «En prueba», la sesión caduca cada 7 días: publícala |
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
- **La contraseña** está en `/etc/respaldo/clave`. Guárdala de forma segura **fuera** del
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

**Si el disco no se monta:** consulta `lsblk -f` y el error de montaje. Si es NTFS y quedó
pendiente una sesión de Windows, expúlsalo correctamente desde Windows y revisa su Inicio rápido.
No ejecutes reparaciones sobre un dispositivo elegido por suposición; identifica antes el volumen.

**Memoria llena.** Si la RAM y la swap se acaban, en vez de congelarse el equipo, **earlyoom** cierra UNA app y
avisa. Elige primero pestañas del navegador y apps web (WhatsApp, Discord, VS Code); intenta evitar Hyprland, la barra,
kitty y el audio según sus reglas de preferencia. Si te cierra algo, es que tenías demasiado abierto. Configuración: `/etc/default/earlyoom`
(gestionado desde `instalar/sistema-base.sh`).

**Salud del SSD.** `smartd` lo vigila: si aparecen errores, se gasta la reserva o pasa de 75 °C, sale un aviso
«⚠ Disco». Verlo a mano: `sudo smartctl -a /dev/nvme0n1` (lo importante: *Percentage Used* = desgaste,
*Media and Data Integrity Errors* = 0). Los valores actuales se consultan en el equipo; no son constantes del proyecto.

**Firmware** (BIOS, SSD…): se comprueba solo cada semana. `fwupdmgr get-updates` para ver si hay y
`fwupdmgr update` para instalar (con el cargador puesto).

**DNS cifrado.** Las consultas DNS usan DNS-over-TLS con Quad9 y Cloudflare de respaldo. Esto protege el transporte de las consultas; no oculta por sí solo todo el tráfico ni la identidad de los sitios visitados.
`dns-cifrado estado` dice si está activo. En una Wi-Fi con página de acceso (hotel, aeropuerto) que no carga:
`dns-cifrado off`, entra, y `dns-cifrado on`.

**Arranque:** GRUB usa un menú oculto con espera de 1 s. Mantén Esc o Shift al encender
para elegir otra entrada o consultar los snapshots disponibles.

**Hibernación:** el instalador prepara un swapfile de 16 GiB para `systemctl hibernate` y un plazo
de 2 h para `systemctl suspend-then-hibernate`. Guarda tu trabajo antes de probarlo: la configuración
no demuestra que la recuperación funcione en cada máquina. La suspensión normal sigue independiente.

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
Los próximos se ven en Brújula › Hoy, en «Próximo» (clic en uno = borrarlo).

**Tiempo de pantalla**: Brújula › Hoy muestra hoy y los últimos 7 días. Para ponerte **límites**, edita
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

**Uso**: la batería del móvil sale en la barra (clic = panel del móvil, clic derecho = hacerlo sonar).

### PC + móvil como uno solo

- **Centro de control › Móvil** (SUPER+N): batería y acciones (hacerlo sonar, abrir en el móvil
  lo copiado, enviarle un archivo, ver sus archivos, SMS).
- **Avisos y respuestas**: los avisos del móvil, y los de WhatsApp, Telegram o SMS se contestan
  desde el PC. También el botón *Responder* de sus notificaciones. Debajo, lo que suena en el
  móvil, los interruptores de «uno solo» (portapapeles compartido, avisos en los dos sentidos,
  pausar la música al entrar una llamada) y **Instalar mandos**: órdenes fijas del PC en el móvil
  (diapositivas, música, bloquear, suspender, concentración, captura).

Si no llegan avisos: en la app del móvil, este PC → *Sincronizar notificaciones*, y concede el
acceso a notificaciones en Android.

## 21. Teclado con capas, tema claro, filtros, sonido y escritorio

### Bloq Mayús reconvertida (keyd)

**Desactivado** desde el 10-11-2026. Convertía Bloq Mayús en Esc (toque), Ctrl (mantenida) y
flechas con H J K L. Cómo activarlo y configurarlo: paso 15 de `instalar/sistema-base.sh` y
`keyd/default.conf`.

### Tema claro y oscuro

`SUPER+CTRL+T` cambia entre claro y oscuro. Es independiente de `SUPER+SHIFT+T` (Ayu o colores del
wallpaper): las cuatro combinaciones funcionan.

El escritorio es **siempre oscuro** salvo que lo cambies tú. Si algún día quieres que cambie solo
(claro a las 6:30, oscuro a las 18:00), `tema.sh auto on`; las horas están al principio de
`modulos/tema.lua`.

Cambian con el tema: Hyprland, toda la interfaz de Quickshell, kitty, btop, las apps GTK, el
bloqueo de respaldo, Firefox (al reiniciarlo) y lo que pregunta al sistema (webs con modo oscuro
automático). No cambian solos: nvim, VS Code, Discord, Spotify y yazi, con su tema Ayu fijo.

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

Funciona con Ollama local y el modelo indicado en `~/.config/ia/modelo` (en este repositorio,
`gemma3:4b`). El modelo debe estar descargado antes de usarlo sin internet. La velocidad y el
consumo dependen del equipo, del modelo y de la longitud del texto.
Lee hasta 32 000 caracteres de texto (unas 10 páginas) con un contexto de 16 384 tokens; un texto
largo puede tardar considerablemente en empezar a responder. Ambos límites
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
en su workspace; lo que ya estaba abierto no se duplica. Para elegir qué apps abre cada una
y en qué espacio, usa Mesa → Rutinas → **Apps** (ver «Rutinas para empezar con menos pasos»). Las de
serie están en `~/.config/hypr/modulos/sesiones.lua` (ahí también se cambian las direcciones que abre
Firefox). La «clase» de una ventana se ve con `SUPER+I`.

### Notas rápidas

`SUPER+SHIFT+O`, escribe y `Enter`: se añade una línea con fecha y hora al final de
`~/Documents/notas.md` (el mismo archivo de `SUPER+CTRL+SHIFT+O`). `SUPER+ALT+O` guarda lo que tengas
seleccionado. En el lanzador: `nota comprar cable`.

### Contraseñas desde el lanzador

`p algo` + Enter la primera vez abre la guía para elegir gestor: Bitwarden (recomendado; también
en el móvil) o `pass` (todo local). Después, `p gmail` escribe la contraseña donde esté el
cursor, sin pasar por el portapapeles.

### Syncthing y Tailscale

- **Syncthing** (carpetas sincronizadas sin nube): abre http://127.0.0.1:8384, instala Syncthing en
  el móvil, escanea el código QR de «Acciones → Mostrar ID» y comparte una carpeta.
- **Tailscale** (entrar al portátil desde fuera): `sudo tailscale up --ssh` y abre el enlace que
  muestra; instala la app en el móvil con la misma cuenta. Desde otro equipo: `ssh oscar@orion`.

Sus puertos se abren con el paso 16 de `instalar/sistema-base.sh`.

### Automatizaciones

- **Resumen del día**: la primera vez que usas el equipo cada día se abre sola Brújula › Hoy. A mano:
  «Resumen del día» en el lanzador o SUPER+D.
- **Actualizaciones**: un paquete con el número en la barra cuando hay pendientes. Rojo = hay
  noticias de Arch sin leer (se muestran antes de actualizar). Clic = actualizar.
- **Pausas** y **lugares**: ver la sección 28.

---

## Tres recorridos para el día a día

**Preparar una tarde de estudio.** Abre el lanzador (SUPER+R), escribe «empezar» y elige «Empezar a estudiar».
Revisa las apps abiertas y añade un recordatorio con `recordar 50m revisar apuntes` en el lanzador.
Antes de dejarlo, «Guardar proyecto» en el lanzador con el próximo paso.

**Preparar una reunión.** En el lanzador, «Reunión temporizada»: elige la duración y comienza.
Comprueba el micrófono con sus botones explícitos. Si necesitas enseñar una ventana, selecciónala
en tu aplicación de videollamada: la privacidad del escritorio no oculta su contenido compartido.
Al terminar, finaliza la reunión; el silencio que necesiten otros modos se conserva.

**Retomar el día anterior.** Abre Brújula con SUPER+D. Si buscas tus apps de antes del reinicio,
revisa Línea de tiempo › Sesión anterior. Para continuar una tarea, pulsa **Retomar** en Hoy o
escribe el nombre del proyecto en el lanzador. Cuando necesites un archivo, búscalo desde SUPER+R con `d tema`.

## 23. Los cuatro centros

Todo lo que no es una ventana normal vive en uno de cuatro sitios, cada uno con un verbo:

| Centro | Atajo | Para | Qué reúne |
|---|---|---|---|
| **Lanzador** | SUPER+R | Hacer | Apps, acciones, proyectos, plantillas, rutinas, cálculos, búsqueda en todo |
| **Brújula** | SUPER+D | Ver | Tu día, la línea de tiempo y la salud del equipo |
| **Centro de control** | SUPER+N | Ajustar | Botones rápidos, perfiles, sonido, avisos, Wi-Fi y Bluetooth, móvil, privacidad |
| **Agente** | SUPER+O | Pedir | Una conversación que consulta y actúa por ti |

Desde un centro no se salta a otro: si algo se hace, se hace donde estás. Mesa de trabajo y Flujo
(organizar ventanas, acciones sobre una selección) son modos del lanzador.

## 24. Lanzador: hacer

Escribe y pulsa Enter. Sin prefijo busca apps, acciones (apagar, capturas, filtros…), **proyectos**
por su nombre y, con 3 letras o más, también en tus documentos, notas, historial y línea de tiempo.
Con el campo vacío, los chips de debajo muestran los prefijos más usados; **más** los enseña todos.

| Prefijo | Qué hace | Ejemplo |
|---|---|---|
| `=` | Calcular o convertir (Enter copia) | `= 5 km a mi` |
| `g` `yt` `w` `gh` | Buscar en Google, YouTube, Wikipedia, GitHub | `g método simplex` |
| `/` | Archivos (solo `/` = recientes) | `/apuntes` |
| `:` | Emojis y símbolos | `:fuego`, `:≤` |
| `pl` | Plantillas de texto (Enter copia con fecha y hora) | `pl reunión` |
| `recordar` · `evento` · `tarea` | Recordatorio, evento o tarea de Google | `recordar 20m agua` |
| `v` `n` `c` `t` | Ventanas, notas, portapapeles, pestañas de Firefox | `v firefox` |
| `d` `h` `l` `a` `s` | Documentos, historial, línea de tiempo, atajos, ajustes | `s lectura` |
| `p` | Contraseñas (las escribe donde está el cursor) | `p correo` |
| `ia` · `nota` | Preguntar al asistente local · apuntar una línea | `nota llamar al banco` |

**Ajustes** (`s`): cada opción concreta, lista para Enter: perfiles, privacidad, tema, energía,
replay, sonido, filtros, Wi-Fi, reglas automáticas, funciones del móvil.

### Proyectos: retomar donde lo dejaste

**Guardar proyecto** (acción del lanzador o SUPER+CTRL+Enter) recuerda un nombre, el siguiente
paso, una carpeta, hasta doce archivos o webs y las apps compatibles (terminal, Firefox, Code,
Thunar) con sus espacios. Después, escribe su nombre en el lanzador: **Retomar «X»** las vuelve a
abrir en su sitio y aplica su perfil. Brújula › Hoy muestra el último con un botón **Retomar**.

No guarda documentos sin guardar, pestañas ni el estado interno de las apps, y no abre nada solo
al iniciar sesión. Con la privacidad activa se ocultan sus detalles.

### Plantillas y rutinas

**Plantillas** (`pl`, o Mesa › Plantillas para crearlas y editarlas): textos reutilizables. Al
copiarlas, `{{fecha}}`, `{{hora}}` y `{{usuario}}` se sustituyen. No es un gestor de contraseñas:
lo copiado pasa por el historial del portapapeles.

**Rutinas**: escribe «empezar» y elige una.

| Rutina | Qué prepara |
|---|---|
| Empezar a estudiar | Apps de la universidad, perfil Lectura y 25 min de concentración |
| Empezar a programar | Apps de programar, perfil Cristal y 50 min de concentración |
| Empezar a descansar | Apps de descanso y fin de la concentración |

Antes guarda un checkpoint de tus ventanas. Qué apps abre cada una se elige en Mesa › Rutinas.

### Mesa de trabajo y Flujo

Acciones del lanzador que abren un panel para tareas más largas:

- **Mesa de trabajo › Ventanas**: buscar una ventana, ir a ella, **aparcarla** (se esconde sin
  cerrarse y se recupera luego), pasarla a flotante o moverla a otro espacio.
- **Mesa › Reunión**: 15 a 90 min con No molestar, replay en pausa, títulos ocultos y sin
  suspensión. Al terminar solo se retira lo que puso la reunión. No toca micrófono ni cámara.
- **Organizar por tarea** (SUPER+CTRL+O): reparte las ventanas del espacio para comparar,
  programar, investigar o concentrarte, con vista previa y **Volver al layout anterior**.
- **Acciones de selección** (SUPER+ALT+C): marca un texto y elige: copiarlo limpio, guardarlo
  como nota o plantilla, cambiar mayúsculas, resumir, explicar o traducir con la IA local, o
  abrirlo si es una dirección.

## 25. Brújula: ver

**SUPER+D**, clic en el reloj o tres dedos hacia abajo. Tres pestañas (**Ctrl+1…3**):

- **Hoy**: reloj, clima, la frase del asistente, el último proyecto, las ideas para hoy, el
  calendario con «Próximo», el estado del equipo y el tiempo de pantalla. Se abre sola la primera
  vez que usas el equipo cada día.
- **Línea de tiempo**: *El día* (qué tuviste delante y cuándo, ←/→ cambia de día), *Reglas
  automáticas* y *Sesión anterior*.
- **Salud**: copias, disco, espacio, snapshots, actualizaciones, servicios, temperatura y batería,
  cada una con su acción.

### Ideas para hoy

Salen de tus datos con reglas fijas: reservar un bloque de concentración si ayer te distrajiste
más de hora y media, retomar el proyecto, abrir la sesión que sueles usar a esta hora, los
eventos que quedan, hacer la copia si tiene más de 5 días o descansar si ayer pasaste más de
9 h delante. La IA local solo redacta la frase de bienvenida (una vez al día).

### Reglas automáticas

Adaptan el escritorio a lo que haces y, al terminar, todo vuelve como estaba (salvo lo que
cambiaste a mano). De serie: **Jugar**, **Programar**, **Estudiar**, **Pantalla externa** y
**Ahorro de batería**. Cada una tiene su interruptor y otro de arriba las pausa todas.
**Editar reglas** abre `~/.config/hypr/brujula.json` (formato en el manual técnico).

### La línea de tiempo y tu privacidad

Guarda cada ventana que miras más de 4 s (app y título), se borra a los 30 días y alimenta la
búsqueda («¿dónde vi lo de las VLAN?»). Con la privacidad activa o en una reunión solo guarda la
app; la navegación privada y los gestores de contraseñas nunca guardan título; con la pantalla
bloqueada no registra nada. Las capturas periódicas están apagadas de serie y, si las activas, se
guardan cifradas.

### Sesión anterior, reabrir y fin de jornada

- **Sesión anterior**: tras reiniciar, una notificación ofrece **Restaurar todo** o **Elegir…**.
  Las apps vuelven a su espacio; las flotantes, con su tamaño y posición.
- **SUPER+SHIFT+Z** reabre la última ventana cerrada en su sitio (repetirlo, la anterior).
- **Fin de jornada** (23:00 de serie): **Cerrar el día** guarda la sesión, silencia, enciende la
  luz nocturna y baja el brillo; por la mañana todo vuelve.

### Actualizar con seguridad

Desde Salud, el lanzador o la barra. Antes comprueba batería, espacio y noticias de Arch, y avisa
de los paquetes delicados; durante, snap-pac hace snapshots; después resume `.pacnew`, servicios
fallidos y si hay que reiniciar. **Deshacer la última actualización** revierte `/` al snapshot
anterior (pide escribir `DESHACER`). Si el sistema no arranca: GRUB › «Arch Linux snapshots».

## 26. Centro de control: ajustar

**SUPER+N** o clic en la campana. Arriba, diez botones rápidos (clic derecho en Wi-Fi o Bluetooth:
su lista) y los cuatro **perfiles**:

| Perfil | Cómo se ve |
|---|---|
| Cristal | Blur, sombras y animaciones (el habitual) |
| Lectura | Paneles opacos y sin blur |
| Mínimo | Sin animaciones, blur ni sombras |
| Rendimiento | Sin efectos ni huecos, borde fino |

Debajo, cuatro pestañas:

- **Inicio**: volumen general y por app, micrófono, brillo, música y las notificaciones con
  **No molestar**.
- **Conexiones**: Wi-Fi y Bluetooth (ver la sección 10).
- **Móvil**: batería y acciones (sonar, abrir lo copiado, enviar archivo, sus archivos, SMS) y
  **Avisos y respuestas**. Sin conexión, un botón para abrir KDE Connect.
- **Más**: checkpoints, privacidad, juego automático, diagnóstico y replay.

### Varios modos a la vez

Batería, juego, concentración, reunión, privacidad y las reglas por lugar se suman sin pisarse:
salir de uno no quita el silencio que otro todavía necesita. La batería quita blur y sombras; el
juego quita efectos y huecos y silencia; la privacidad oculta títulos, silencia, pausa el replay
**y apaga la nube del agente**. El perfil visual no cambia el modo de energía del procesador.

### Checkpoints

**Guardar checkpoint** recuerda en qué espacio está cada ventana; **Restaurar espacios** las
devuelve (solo las que siguen abiertas) y **Deshacer restauración** vuelve atrás. Duran la sesión:
no reabren apps ni guardan documentos.

### Replay

Graba en memoria los últimos 30 s para guardarlos si pasa algo que valga la pena. En
**Automático** solo graba con el **modo juego** activo; **Guardar ahora** (o SUPER+SHIFT+PRINT)
guarda lo último y SUPER+ALT+PRINT lo enciende o apaga a mano. La privacidad siempre lo para.

## 27. Agente: pedir

**SUPER+O**. Escribe o dicta (Ctrl+Espacio) lo que necesitas: consulta tu agenda, la línea de
tiempo, la salud del equipo, tus archivos y el móvil; abre apps y sesiones; navega por internet
con su propio navegador; y propone acciones que confirmas con **Sí, hazlo** o **No**.

| Quiero | Ejemplo |
|---|---|
| Preparar el día | `¿Qué tengo mañana y cuánta batería me queda?` |
| Encontrar algo | `¿Qué estuve leyendo sobre el método de dos fases?` |
| Ponerme a estudiar | `Abre la sesión universidad y concentración de 50 minutos` |
| Recordar algo | `Recuérdame en 45 minutos tomar agua` |
| Responder desde el móvil | `Contéstale a María que llego a las 3` |

### Modelos

**Ajustes** (arriba a la derecha) elige modelo, esfuerzo y navegador:

- **Auto** usa el mejor disponible: Gemini 4 Hydrogen y, si falla, los modelos de Groq.
- **Google** muestra todos los modelos de conversación de tu cuenta, ordenados del que mejor
  responde al que peor (se prueban una vez al día; el selector indica si alguno va lento o falla).
  Cada uno usa tu clave principal y, si se agota, la de respaldo.
- **Groq**: GPT-OSS y Qwen, también con dos claves.
- **Local**: el modelo de este equipo, privado pero lento. Es el que se usa siempre con la
  **privacidad activa**.

Si un modelo falla, el chat avisa de cada cambio. Las claves viven fuera de dotfiles, en
`~/.local/share/brujula/claves/`.

### Permisos

**Amplio** (de serie) hace sin preguntar las consultas, aperturas, sesiones, concentración,
recordatorios y ediciones de tus documentos (guardando el original). Pide confirmación para
comandos generales, borrados, instalaciones, cambios de configuración, envíos y acciones dentro
de webs. Nunca obtiene permisos de administrador por su cuenta. Lee siempre la propuesta.

### Memoria y conversaciones

Busca por significado en tus documentos, la línea de tiempo (60 días) y el historial de Firefox
(90 días), y cita sus fuentes con fichas que se abren con un clic. No indexa el portapapeles.
Guarda tus últimas 100 conversaciones a la izquierda (Hoy, Ayer…); **Ctrl+L** empieza otra.
Borrar una conversación no borra lo indexado. La privacidad no borra datos ya indexados: revisa
qué compartes si muestras la pantalla.

| Si… | Prueba |
|---|---|
| Responde en local y lento | ¿Está la privacidad activa? (centro de control › Más) |
| Falla la nube | Mira el aviso del chat; el selector dice qué modelos fallan |
| No encuentra recuerdos | `~/.config/hypr/scripts/memoria.py estado` |
| Error de Ollama | `systemctl status ollama` y `ollama list` |

## 28. Herramientas que conviene conocer

### Terminal

Kitty copia al seleccionar; **Ctrl+Shift+T** pestaña nueva, **Ctrl+Shift+W** la cierra,
**Ctrl+Shift+±/0** cambia el tamaño de letra. En Zsh: escribe una carpeta para entrar en ella,
`cdi` elige entre las recientes, **Ctrl+T** busca archivos, **Alt+C** carpetas, **Ctrl+R** el
historial (Atuin) y **→** acepta la sugerencia gris.

| Orden | Resultado |
|---|---|
| `ll`, `la`, `lt` | Listas con detalle, ocultos o en árbol |
| `cat archivo` | Con colores (bat) |
| `y [carpeta]` | Yazi; al salir te deja en la carpeta elegida |
| `rz` | Recarga la shell |

### Neovim

`i` escribe, Esc vuelve. **Espacio w** guarda, **Espacio q** sale, **Espacio e** abre el
explorador, `/texto` busca. El portapapeles del sistema está integrado.

### Pausas y lugares

Tras **50 min** seguidos sin una pausa de 3 min llega un aviso para descansar (espera si hay No
molestar). En `~/.config/lugares.conf` puedes poner reglas por red Wi-Fi (energía, volumen, No
molestar); una línea por red, con `*` para las demás.

### Qué recuperar con qué

| Situación | Herramienta |
|---|---|
| Moví ventanas de espacio | Centro de control › Más › Restaurar espacios |
| Quiero el reparto anterior | Organizar › Volver al layout anterior |
| Seguir mañana | Guardar proyecto y retomarlo desde el lanzador |
| Reinicié | Brújula › Sesión anterior |
| Cerré una ventana sin querer | SUPER+SHIFT+Z |
| Borré o cambié un archivo | Snapshot de `/home` o copia de restic |
| Una actualización rompió algo | Salud › Deshacer la última actualización, o GRUB › snapshots |

Nada de esto recupera lo que no guardaste dentro de una app.

## Apéndice A. Todos los atajos

La lista completa de atajos, gestos y prefijos del lanzador está en [Atajos y referencia rápida](atajos.md).
Dentro del escritorio: **SUPER+H** (chuleta) o `a texto` en el lanzador.

## ORION: apariencia y espacio útil (fase 2)

En **Centro de control → Más → Apariencia**, el estado dice «Color actual» y los botones
explican la acción: **Usar Ayu**, **Seguir fondo** o **Fijar acento**. Fijar conserva los
acentos aunque rote el wallpaper; Seguir fondo lo reactiva. Claro/oscuro es independiente.
**Reducir movimiento de la interfaz** se guarda como preferencia y no depende del cargador.
El selector de wallpapers también ofrece **Cambiar colores** sin confundir estado y acción.

**Hoy** muestra agenda y calendario juntos: elegir un día filtra eventos, tareas y recordatorios.
**Hoy** vuelve a la fecha actual. **+ Evento** y **+ Tarea** indican que guardan en Google
Calendar y Tasks. Las sugerencias y el cierre se despliegan con **Más de tu día**.
**Salud** prioriza avisos; **Ver todas** muestra la rutina y **Mantenimiento** conserva las
acciones de actualizar y deshacer. Sus métricas son compactas, sin anillos.

El centro conserva Wi-Fi y Bluetooth con una flecha para ver dispositivos. El mezclador y las
salidas de audio se despliegan bajo demanda, la música tiene vista compacta/ampliada y los avisos
conservan su área. **Perfil visual** cambia efectos/espacio; **Energía alta**, en Más, cambia el
rendimiento energético. La estrella fija hasta dos controles frecuentes en Inicio.

La flecha de la **bandeja** muestra aplicaciones con sus iconos originales; la estrella las fija.
Las apps que piden atención aparecen aunque no estén fijadas. Buds conserva en la barra los iconos y porcentajes de izquierdo y derecho, y el estuche cuando
haya lectura. La ayuda amplía el modo y los estados de carga; desconocido se representa con «—».
Clic cambia el modo, clic derecho alterna ANC/apagado y clic central abre Buds Manager.
