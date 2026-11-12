# Brújula: el escritorio que se anticipa

`SUPER+CTRL+B` abre Brújula. Junta cinco funciones que trabajan solas en segundo plano. Todo es
local: nada sale del equipo.

| Pestaña / función | Qué hace |
|---|---|
| **Hoy** | Saludo, una frase del asistente local sobre tu día y sugerencias de un clic |
| **Línea de tiempo** | Qué app (y qué título) tenías delante y cuándo, día por día |
| **Contexto** | Reglas que cambian perfil, No molestar, energía y modo juego según lo que haces |
| **Sesión** | Al volver de un reinicio o un cuelgue, reabre tus apps en sus espacios |
| **Búsqueda universal** | En el lanzador (`SUPER+R`): dentro de documentos, historial, notas, línea… |
| **Salud** | Disco, batería, respaldo, snapshots, servicios, temperatura, USB… con semáforo |
| **Actualizar con seguridad** | Comprobaciones antes, snapshot, revisión después y deshacer |
| **Reabrir ventana** | `SUPER+SHIFT+Z`: la última que cerraste, en su sitio |
| **Fin de jornada** | A tu hora: guarda, silencia, luz cálida y brillo bajando; por la mañana vuelve |

Teclas del panel: `Ctrl+1…5` o `Ctrl+Tab` cambian de pestaña; en la línea, `←`/`→` cambian de día.

## Cómo funciona

El servicio `scripts/brujula.py vigilar` arranca con la sesión (`modulos/autostart.lua`) y escucha
los eventos de Hyprland. Guarda su estado en `~/.local/state/brujula/` (carpeta `0700`).
La configuración es un solo archivo, [`~/.config/hypr/brujula.json`](../hypr/.config/hypr/brujula.json):
los cambios valen en 2 segundos, sin reiniciar nada. Para abrirlo: botón «Editar reglas» de la
pestaña Contexto.

```bash
~/.config/hypr/scripts/brujula.py estado            # reglas y cuáles están activas
~/.config/hypr/scripts/brujula.py pausar            # nada cambia solo (reanudar para volver)
~/.config/hypr/scripts/brujula.py linea --dia 2026-11-10
~/.config/hypr/scripts/brujula.py sesion restaurar
~/.config/hypr/scripts/sugerencias.py               # las ideas del día, en JSON
~/.config/hypr/scripts/indice.py --buscar "método simplex"
```

## 1. Contexto automático

Cada regla tiene `si` (condiciones; tienen que cumplirse todas) y `entonces` (efectos):

```json
{ "id": "programar", "nombre": "Programar", "icono": "f0169",
  "si": { "apps": ["code-oss", "code"], "gracia": 4 },
  "entonces": { "perfil": "lectura", "no_molestar": true, "sesion": "programar" } }
```

- **Condiciones:** `apps` (class con comodines; `SUPER+I` la dice), `modo` (`foco` por defecto, o
  `abierta`), `gracia` (minutos que sigue activa después de cambiar de ventana: mirar la
  documentación no apaga «Programar»), `bateria_menor`, `cargando`, `pantalla_externa`, `hora` y `dias`.
- **Efectos:** `perfil`, `no_molestar`, `energia` (`power-saver`, `balanced`, `performance`) y `juego`.
  `sesion` no cambia nada: solo sirve para que «Hoy» proponga abrir esa sesión.
- Una regla se activa cuando sus condiciones llevan **4 s** cumpliéndose (así no parpadea con alt-tab).
- Si dos reglas activas quieren lo mismo, gana la de **más arriba** en el archivo.
- **Al terminar, todo vuelve a como estaba**, salvo lo que cambiaste a mano mientras tanto: si
  pusiste otro perfil durante «Programar», al cerrar VS Code se queda el tuyo.
- No molestar se pide como motivo `contexto`: convive con la concentración, las reuniones y el
  No molestar manual sin apagárselos.

Reglas de serie: Jugar, Programar, Estudiar, Pantalla externa y Ahorro de batería. Cada una se
activa o desactiva con su interruptor, y el interruptor de arriba pausa todo el contexto automático.

## 2. Línea de tiempo

Cada cambio de ventana que dura más de 4 s queda en `linea/AAAA-MM-DD.jsonl`: hora, class y título.
El panel lo convierte en una cinta de colores del día, un resumen por app y una lista de bloques
que se puede filtrar. La búsqueda universal también busca en ella («¿dónde vi lo de las VLAN?»).

Privacidad:
- Con la privacidad activa (`SUPER+CTRL+P` o una reunión) solo se guarda la app, **sin título**,
  y el panel oculta la línea.
- Las ventanas de navegación privada y las apps de `linea.sin_titulo` (gestores de contraseñas)
  nunca guardan título.
- Con la pantalla bloqueada no se registra nada.
- Se borra sola a los `linea.dias` días (30). Con `"titulos": false` se guardan solo las apps.
- **Capturas** (`"capturas": true`, apagadas de serie): una imagen pequeña cada
  `capturas_cada_min` minutos, salvo con la privacidad activa o la pantalla bloqueada. Se borran a
  los `capturas_dias` días.
  - **Van cifradas** (AES-256 con `openssl`), sin pasar nunca por el disco en claro: `grim` escribe
    a una tubería y se guarda solo el `.jpg.enc`, con permisos `600`.
  - La clave se crea sola y vive en tu **anillo de claves** («Brújula: clave de las capturas»), que se
    abre con tu contraseña al iniciar sesión. Si no hay anillo disponible, no se hace ninguna captura.
  - Para mirarlas, el panel las descifra en `$XDG_RUNTIME_DIR` (memoria) y las borra al cerrarse.
- **Archivos del día:** los que abriste con las apps que lo apuntan en `recently-used.xbel` (visores
  de PDF, editores, el navegador al descargar…). Aparecen como rombos sobre la cinta y como fichas
  debajo; un clic los abre.

## 3. Sesión que vuelve

Cada minuto (y 5 s después de abrir, cerrar o mover una ventana) se guarda una foto de las apps
abiertas en los espacios 1-10. Para cada una se recuerda cómo volver a abrirla:
- las Flatpak, con `flatpak run`;
- las terminales, en la carpeta donde estabas;
- las demás, por su `.desktop`.

Las ventanas **flotantes** recuerdan también su **tamaño y posición** (relativos a su pantalla), y las
de pantalla completa vuelven a pantalla completa. Esos datos se pasan a Hyprland como reglas de la
ventana al lanzarla, y solo con números validados.

Al iniciar sesión, si la foto es de otro arranque, aparece una notificación: **«Restaurar todo»**
o **«Elegir…»**. La pestaña Sesión muestra la lista con casillas. Lo que ya está abierto (por
ejemplo la terminal y Firefox que abre el inicio) no se duplica. Firefox recupera sus pestañas él
mismo; los documentos sin guardar no se recuperan.

## 4. Sugerencias del día

La primera vez que usas el equipo cada día (desde las 6:00, sin modo juego) llega un aviso:
«Tengo N ideas para hoy». Las ideas salen de tus datos, con reglas fijas:

- **Distracciones:** si ayer pasaste más de 1 h 30 min en las apps de `sugerencias.distracciones`,
  propone **reservar** un bloque de concentración de `bloque_min` minutos (90) en el primer hueco
  libre: en punto o y media, sin pisar los eventos de tu calendario ni otros bloques, entre las 7:00
  y las 22:30; si hoy ya no cabe, mañana a las 9:00. Botones: *Programar HH:MM* o *Ahora 50 min*.
  - Avisa 5 min antes y empieza solo a su hora. Si el equipo estaba apagado, no empieza tarde.
  - Los bloques reservados salen en «Hoy» con una ✕ para cancelarlos.
  - También desde la terminal: `brujula.py programar --inicio 09:00 --minutos 90`, `programados` y
    `cancelar <id>`.
- **Proyecto:** retomar tu último proyecto de la mesa de trabajo, con su próximo paso.
- **Hábito:** si sueles tener un contexto a esta hora (3 de los últimos 7 días), propone abrir su sesión.
- **Eventos:** los de hoy que aún no han pasado.
- **Respaldo:** si la última copia tiene más de 5 días.
- **Pantalla:** si ayer pasaste más de 9 h delante.

El asistente local (ollama) solo redacta la frase de bienvenida, con esos mismos datos. Tarda
unos 30 s la primera vez y luego queda guardada todo el día. Sin ollama aparece una frase fija;
con `"ia": false`, nunca se usa.

## 5. Búsqueda universal

En el lanzador, a partir de 3 letras y sin prefijo, debajo de las apps aparecen los resultados por
grupos: **ajustes**, ventanas, **dentro de tus documentos**, notas, historial de Firefox, línea de
tiempo, atajos y portapapeles. Las fuentes se consultan en paralelo y la que tarda más de 1,5 s se queda
fuera. También hay prefijos para buscar en una sola fuente: `d` documentos, `h` historial,
`a` atajos, `l` línea de tiempo, `s` ajustes y `b` todo.

**Ajustes:** cada opción concreta, lista para aplicarse con Enter. Escribiendo «claro», «lectura»,
«regla programar», «bluetooth» o «portapapeles móvil» aparecen, por ejemplo:
- perfiles, privacidad, No molestar y modo juego;
- tema (claro u oscuro, Ayu o wallpaper, horario automático) y luz nocturna;
- energía, replay, sonido de las bocinas y filtros de pantalla;
- Wi-Fi, Bluetooth y widgets de escritorio;
- cada regla de contexto (activar o desactivar) y las funciones del móvil.

`indice.py` lee PDF, docx, odt, pptx, odp, ods y texto (md, txt, tex…) de Documents, Desktop y
Downloads (y sus equivalentes en español). Guarda el contenido en una base SQLite FTS5 en
`~/.cache/brujula/documentos.db`. Es incremental y el servicio lo relanza cada 30 min con la
prioridad más baja de CPU y disco.

## 6. Salud del sistema (pestaña «Salud»)

`scripts/salud.py` comprueba en menos de un segundo, y sin contraseña de administrador:

| Comprobación | De dónde sale | Aviso / mal |
|---|---|---|
| Copia de seguridad | `/var/lib/respaldo/ultima` | más de 3 / 8 días |
| Disco (SMART) | UDisks: desgaste, reserva, errores, temperatura | avisos del disco o errores |
| Espacio libre | `df /` | 85 % / 95 % |
| Snapshots | `snapper list` | el último hace más de 3 h / 2 días |
| Actualizaciones | `checkupdates -n`, barra (AUR, noticias, vulnerables) | noticias, vulnerables, más de 60; **mal** si el kernel se actualizó y no has reiniciado |
| Servicios | `systemctl --failed` (sistema y usuario) | alguno fallido |
| Temperatura | `sensors -j` | 80 / 92 °C |
| Batería | capacidad actual frente a la original y ciclos | 80 % / 60 % |
| Memoria | `/proc/meminfo` | menos del 15 % / 5 % libre |
| Scrub de Btrfs | temporizador `btrfs-scrub@-` | más de 40 días o con errores |
| USB | errores `-71` del kernel en este arranque | alguno |
| `.pacnew` | `pacdiff -o` | alguno |
| Escritorio y arranque | `hyprctl configerrors`, `grub-btrfsd` | errores o servicio parado |

Cada tarjeta trae su acción: copiar ahora, actualizar, ver qué ocupa, abrir btop, ver por qué falló…
Si algo está **mal** (no basta con un aviso), «Hoy» lo propone el primero.

## 7. Actualizar con seguridad

«Actualizar con seguridad» (en Salud, el lanzador o la barra) abre `scripts/actualizar.py` en una terminal.

**Antes:**
- con batería por debajo del 40 % y sin cargador, para y pregunta;
- con menos de 5 GiB libres, no sigue;
- muestra las noticias de Arch sin leer (informant) y pide confirmación;
- avisa de los paquetes delicados (kernel, systemd, Mesa, Hyprland, Quickshell…);
- comprueba que snap-pac hará los snapshots.

**Durante:** `yay -Syu`. snap-pac hace un snapshot de `/` antes y otro después de cada paso de pacman,
y grub-btrfs los pone en el menú de GRUB.

**Después:**
- indica los snapshots creados, los `.pacnew` nuevos, los servicios fallidos y si hace falta reiniciar;
- lo apunta en `~/.local/state/brujula/actualizaciones.jsonl` y avisa con una notificación.

**Deshacer la última actualización** (Salud o lanzador): `snapper undochange <antes>..<después>`
devuelve los archivos de `/` a como estaban, sin tocar `/home`. Hay que escribir `DESHACER` para
confirmar y pide tu contraseña. Si el sistema ni siquiera arranca: GRUB → «Arch Linux snapshots».

## 8. Reabrir la última ventana cerrada (`SUPER+SHIFT+Z`)

El servicio calcula cómo reabrir cada ventana mientras su proceso vive (después ya no se puede). Al
cerrarla, la guarda en una pila de 15 (`cerradas.json`). `SUPER+SHIFT+Z` reabre la última:
- en su espacio;
- si flotaba, con su tamaño y posición;
- las terminales, en su carpeta.

Repetirlo reabre la anterior. Las que duran menos de 2 s (diálogos) no cuentan.

## 9. Fin de jornada

En `brujula.json → jornada` eliges la hora (23:00), los días (vacío = todos) y el brillo de noche (30 %).
A esa hora llega «Fin de jornada», con dos botones:
- **Cerrar el día:**
  - guarda la sesión, activa No molestar (motivo `jornada`) y enciende la luz nocturna;
  - baja el brillo poco a poco durante un minuto;
  - abre «Hoy» con el resumen: pantalla del día, apps principales y lo de mañana.
- **15 min más:** vuelve a avisar.

No avisa con un juego abierto ni con la pantalla bloqueada. Una hora antes, «Hoy» ya muestra la
tarjeta de cierre. Por la mañana (desde las 5:00, al desbloquear) vuelven el brillo y las
notificaciones. También a mano: `brujula.py jornada cerrar` / `reabrir`, o «Cerrar el día» en el lanzador.

## Pruebas

```bash
cd ~/dotfiles && python3 -m unittest tests.test_brujula tests.test_salud -v
```

Los tests cubren:
- la activación y el deshacer del contexto, sin pisar los cambios manuales;
- la prioridad entre reglas, la gracia y las condiciones;
- los bloques, la privacidad y la limpieza de la línea de tiempo;
- la foto y la restauración de la sesión;
- el índice de documentos (también el incremental) y la búsqueda en paralelo;
- las sugerencias;
- las reglas de ventana validadas (geometría);
- la concentración programada: solapes, aviso, inicio y equipo apagado;
- el hueco libre en la agenda;
- el cifrado de ida y vuelta, y que sin anillo de claves no hay capturas;
- los archivos del día y los ajustes.
