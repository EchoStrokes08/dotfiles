# Atajos y referencia rápida

Todos los atajos de teclado, ratón, gestos y prefijos del lanzador. Los marcados con ★ son los quince
esenciales. Esta página es la fuente de la chuleta (`SUPER+H`) y de la búsqueda de atajos del lanzador
(`a texto`): lo que documentes aquí aparece allí solo.

Para entender cada función, el [manual de usuario](manual.md).

<!-- atajos:inicio -->

### Atajos de teclado

#### Apps

| Atajo | Acción |
|---|---|
| ★ `SUPER+Q` | Terminal (kitty) |
| `SUPER+E` | Archivos (Thunar) |
| ★ `SUPER+R` | Lanzador: apps, acciones, calculadora, web, emojis, archivos, proyectos, plantillas y rutinas (sección 24) |
| `SUPER+H` | Chuleta: todos estos atajos, con buscador |
| `SUPER` (mantenida, sola) | Ayuda rápida: los esenciales y las teclas de la ventana o del modo; se va al soltar |
| ★ `SUPER+ESPACIO` | Vista general: todas las ventanas en miniatura (clic = ir · arrastrar = mover de workspace) |
| `SUPER+W` | WhatsApp (lo enfoca si ya está abierto) |
| `SUPER+G` | Roblox (Sober, con gamemode) |
| `SUPER+B` | Buds Manager (lo enfoca si ya está abierto) |
| ★ `SUPER+D` | Brújula: tu día (reloj, clima, agenda, sistema y tiempo de pantalla), línea de tiempo y salud |
| `SUPER+A`, luego una letra | Modo lanzar: `F` Firefox · `T` terminal · `E` archivos · `W` WhatsApp · `G` Roblox · `S` Spotify · `N` Nebula. Cualquier otra tecla cancela |

#### Ventanas

| Atajo | Acción |
|---|---|
| ★ `SUPER+C` | Cerrar la ventana |
| ★ `SUPER+V` | Flotante / en mosaico |
| ★ `SUPER+F` | Pantalla completa |
| `SUPER+P` | Pseudo-mosaico |
| `SUPER+J` | Cambiar la dirección de la división (dwindle) |
| `SUPER+U` | Mostrar la terminal que se «tragó» la app enfocada (swallow), o volver a ocultarla |
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
| ★ `SUPER+O` | Agente del escritorio: agenda, memoria, equipo y propuestas de acciones |
| `SUPER+ALT+A` | Asistente local (IA) sobre el texto seleccionado: resumir, corregir, redactar mejor, explicar, traducir o preguntar |
| `SUPER+SHIFT+O` | Nota rápida: una línea con fecha a `~/Documents/notas.md` |
| `SUPER+ALT+O` | Guardar en las notas el texto seleccionado |

#### Workspaces y monitores

| Atajo | Acción |
|---|---|
| ★ `SUPER+1` … `SUPER+0` | Ir al workspace 1-10 (el mismo otra vez = volver al anterior) |
| `SUPER+\|` (tecla a la izquierda del 1) | Saltar a la última ventana enfocada |
| `ALT+TAB` / `ALT+SHIFT+TAB` | Recorrer las ventanas del workspace (y traerla al frente) |
| ★ `SUPER+SHIFT+1` … `SUPER+SHIFT+0` | Mover la ventana al workspace 1-10 |
| `SUPER+rueda del ratón` | Workspace siguiente / anterior |
| ★ `SUPER+S` | Mostrar / ocultar el scratchpad (workspace especial «magic») |
| `SUPER+SHIFT+S` | Mandar la ventana al scratchpad |
| `SUPER+Return` | Terminal flotante (scratchpad; se abre sola la primera vez) |
| `SUPER+Y` | Música: Spotify en su scratchpad (si ya estaba abierto, lo trae) |
| `SUPER+CTRL+SHIFT+O` | Notas: nvim con `~/Documents/notas.md` en un scratchpad flotante |
| `SUPER+SHIFT+E` | Archivos: yazi en un scratchpad flotante (`SUPER+E` sigue siendo Thunar) |
| `SUPER+CTRL+←/→` | Foco al otro monitor |
| `SUPER+CTRL+SHIFT+←/→` | Mandar la ventana al otro monitor |
| `SUPER+CTRL+ALT+←/→` | Mandar el workspace entero al otro monitor |

#### Sistema

| Atajo | Acción |
|---|---|
| ★ `SUPER+L` | Bloquear la pantalla |
| `SUPER+M` | Menú de apagado: bloquear, cerrar sesión, reiniciar, apagar |
| `ALT+F4` | Menú de apagado (wlogout) |
| ★ `SUPER+N` | Centro de control: botones, perfiles, sonido, música, avisos, Wi-Fi y Bluetooth, móvil y más |
| `SUPER+SHIFT+N` | Alternar No molestar manual (respeta los motivos automáticos) |
| `SUPER+CTRL+V` | Plantillas de texto en el lanzador (`pl`): copiar con fecha y hora; Alt+Enter para editar |
| `SUPER+CTRL+Enter` | Proyectos en el lanzador: guardar, retomar y cambiar su próxima tarea |
| `SUPER+CTRL+O` | Organizar el espacio por tarea, con previsualización y vuelta al layout anterior |
| `SUPER+ALT+C` | Capturar una selección y elegir acciones sobre ese texto |
| `SUPER+SHIFT+Z` | Reabrir la última ventana cerrada (en su espacio y, si flotaba, con su tamaño) |
| `SUPER+CTRL+P` | Privacidad: oculta títulos de la barra, activa No molestar y pausa el replay |
| `SUPER+SHIFT+F` | Modo concentración: 25 / 50 / 90 min (con sesión: +10 min o terminar) |
| `SUPER+ALT+N` | Luz nocturna sí/no (automática 20:30–7:00, `hyprsunset.conf`) |
| `SUPER+SHIFT+C` | Selector de color: clic en un píxel → hex copiado |
| `SUPER+SHIFT+G` | Modo juego: oculta la barra en el espacio del juego (también automático con Roblox, Steam y Gamescope) |
| `SUPER+SHIFT+P` | Modo de energía: ahorro → equilibrado → rendimiento |
| `SUPER+SHIFT+T` | Colores: Ayu ↔ sacados del wallpaper |
| `SUPER+CTRL+T` | Tema claro ↔ oscuro |
| `SUPER+ALT+S` | Filtro de pantalla: ninguno / grises / papel / colores vivos / invertido |
| `SUPER+ALT+E` | Sonido de las bocinas: perfil música / voz / sin efectos (EasyEffects) |
| `SUPER+SHIFT+W` | Selector de wallpapers |
| `SUPER+CTRL+W` | Wallpaper al azar |
| ★ `SUPER+SHIFT+V` | Historial del portapapeles |
| `SUPER+SHIFT+B` | Buds: cambiar de modo (ANC → transparencia → apagado) |
| `SUPER+ALT+P` | Pantalla externa: duplicar / extender / solo la externa / solo el portátil |

#### Capturas y grabación

| Atajo | Acción |
|---|---|
| ★ `PRINT` | Captura de una región → `~/Imágenes/screenshots` + portapapeles |
| `SUPER+PRINT` | Captura de toda la pantalla |
| `SHIFT+PRINT` | Menú: región, pantalla, ventana activa, pantalla en 5 s o región y anotar |
| `SUPER+SHIFT+A` | Capturar una región y anotarla (satty): flechas, texto, números, resaltar, difuminar. `Enter` copia, guarda y sale |
| `SUPER+SHIFT+PRINT` | Guardar los últimos 30 s de pantalla y audio en `~/Videos/Replays` |
| `SUPER+ALT+PRINT` | Encender / apagar el replay |
| `SUPER+ALT+R` | Grabar pantalla: menú región / pantalla / con audio / GIF; otra vez = parar → `~/Videos/Grabaciones` |
| `SUPER+SHIFT+X` | Copiar texto de la pantalla (OCR): seleccionas una zona y su texto queda copiado |

#### Teclado con capas (keyd: funciona en todas las apps, la TTY y el login)

> **Desactivado** desde el 10-11-2026 (no se instala). Para volver a usarlo, descomenta el paso 15 de `instalar/sistema-base.sh`.

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
| Barra: barras de colores (solo con música) | Visualizador de audio · clic = centro de control |
| Barra: punto rojo con tiempo / micrófono rojo | Grabando la pantalla / dictando · clic = parar |
| Barra: móvil (solo si está conectado) | Batería del móvil · clic = panel PC + móvil · derecho = hacerlo sonar |
| Barra: reloj | Al pasar el ratón muestra la fecha · clic = Brújula › Hoy |
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
| Brújula › Hoy: calendario | Flechas o rueda = mes · clic en el título = volver a hoy · clic en un día = elegirlo · puntito = hay eventos o tareas ese día |
| Brújula › Hoy: «＋ Nuevo evento o tarea» | Crea en Google el evento/tarea del día elegido · Enter guarda · duración: clic = más, derecho = menos |
| Brújula › Hoy: «Próximo» | Eventos de Google Calendar, tareas y recordatorios · clic en un recordatorio = borrarlo · en una tarea = hecha |
| Brújula › Hoy: últimos 7 días | Pasa el ratón por una barra: total y app principal de ese día |
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
| `dolar hoy` · `dólar` · `trm` | TRM oficial de hoy + dólar y euro de mercado (tasas al día por `tasas-cambio.timer`); `Enter` copia |
| `g …` · `yt …` · `w …` · `gh …` | Buscar en Google / YouTube / Wikipedia / GitHub |
| `:fuego` · `:corazon` · `:sigma` · `:≤` | Emojis y símbolos: los escribe y quedan copiados |
| `/apuntes` (solo `/` = recientes) | Archivos de tu carpeta personal: los abre |
| `recordar 20m beber agua` · `recordar 18:30 llamar` · `recordar mañana 7:00 examen` | Recordatorio (aviso con sonido; sobrevive a reinicios). Abreviado: `rec` |
| Cualquier cosa sin resultados | Buscarla en Google |

En el lanzador, el portapapeles y el selector de wallpapers: `↑↓` (o flechas) para moverse, `Enter` para elegir,
`Esc` o clic fuera para cerrar. En el portapapeles, `Supr` borra la entrada. En los menús, `1`-`9` eligen directo.

### Búsquedas directas del lanzador

| Escribe | Resultado |
|---|---|
| `v texto` | Ventanas abiertas en cualquier workspace → ir a ella |
| `n texto` | Buscar dentro de tus notas (`~/Documents/*.md`) → abrir nvim en esa línea |
| `c texto` | Historial del portapapeles → copiarlo otra vez |
| `t texto` | Pestañas abiertas de Firefox → abrir esa dirección (para saltar a la pestaña ya abierta, en Firefox escribe `%` en la barra) |
| `p nombre` | Contraseñas (Bitwarden o pass) → la escribe donde esté el cursor. Primera vez: `claves.sh configurar` |
| `ia pregunta` | Preguntar al asistente local |
| `nota texto` | Apuntar una línea en `notas.md` |
| `!texto` | Avisos pasados (historial local de los últimos 500) → copiar su texto |
| `brillo 40` · `volumen 30` · `wifi` · `bluetooth off` · `no molestar 1 h` · `oscuro` · `reunión` | Ajustes directos, sin prefijo. Los interruptores solo dicen «activado» si el servicio lo confirma |

### Atajos que se adaptan al layout (`modulos/layouts.lua`)

| Tecla | dwindle | master | scrolling |
|---|---|---|---|
| `SUPER++` / `SUPER+-` | División más grande / pequeña | Área principal más ancha / fina | Columna más ancha / estrecha |
| `SUPER+Z` | Llevar la ventana a la raíz | Cambiarla con la principal | Centrar la columna |
| `SUPER+X` | Invertir la división | Girar la orientación | Meter / sacar de la columna anterior |
| `SUPER+SHIFT++` / `SUPER+SHIFT+-` | — | Una ventana principal más / menos | — |


### Búsqueda universal

| Prefijo de búsqueda | Fuente |
|---|---|
| `d texto` | Dentro de documentos indexados |
| `h texto` | Historial de Firefox |
| `a texto` | Atajos |
| `l texto` | Línea de tiempo |
| `s texto` | Ajustes y acciones del sistema |
| `b texto` | Todas las fuentes universales |

Con tres letras sin prefijo, el lanzador añade resultados de varias fuentes a las apps.
En cualquier resultado, **Alt+Enter** abre sus acciones (ventana: ir, mover, aparcar, cerrar; plantilla:
editar, duplicar, borrar; proyecto: retomar, editar, actualizar, archivar) y Esc vuelve a la lista.

### Gestos del touchpad

| Gesto | Acción |
|---|---|
| 3 dedos ← → | Cambiar de workspace |
| 3 dedos ↑ | Mostrar / ocultar el scratchpad |
| 3 dedos ↓ | Brújula › Hoy |
| Abrir 3 dedos | Pantalla completa (otra vez = salir) |
| Juntar 3 dedos | Flotante ↔ mosaico |
| 4 dedos (cualquier dirección) | Mover la ventana |
| `SUPER` + 4 dedos | Redimensionar la ventana |
| `SUPER` + 3 dedos ↓ | Cerrar la ventana |
| `SUPER` + 3 dedos ↑ | Vista general |
| `SUPER` + pellizco (2 dedos) | Lupa alrededor del cursor |

### Comportamiento automático

<!-- atajos:fin -->

Los automatismos se explican en los capítulos anteriores y su arquitectura en el manual técnico.
