# Ruta de Hyprland: de tu escritorio actual a desarrollo avanzado

Preparada el **11 de noviembre de 2026** para este repositorio y este equipo.
Base: [revisión del sistema](revision-sistema-2026-11-11.md).
Uso diario: [manual](manual.md). Referencia: [comandos](comandos.md) y [README](../README.md).

## Desde dónde partes

Ya tienes Arch, Hyprland 0.57.2 en Lua y Quickshell 0.3.2. Tu escritorio incluye layouts,
grupos, scratchpads, gestos, reglas, modos, temas dinámicos, portales, bloqueo propio, IA local,
integración del móvil y respaldos. Reinstalar otro conjunto de dotfiles no es un requisito.

**Punto de partida técnico: escritorio avanzado; dominio personal por comprobar.** Si puedes
explicar, modificar y recuperar esos componentes sin copiar una solución completa, comienza en
la etapa 2. Si solo los usas, recorre primero las etapas 0 y 1. Tener una función configurada no
equivale a comprenderla.

Meta: mantener un escritorio fiable, reconstruirlo en otra máquina, depurar fallos entre capas
y desarrollar una integración propia o una contribución upstream.

## Cómo seguir la ruta

Reserva 4–6 horas semanales: dos sesiones de estudio/práctica y una de revisión. La propuesta
completa ocupa **18–24 semanas**; el ritmo depende de los ejercicios, no del calendario.
Las etapas 0–5 tienen prioridad y dependencias sucesivas. Después de la 5 puedes alternar
rendimiento y recuperación; seguridad precede al proyecto de distribución o desarrollo.

Para cada práctica anota problema, hipótesis, cambio, resultado y reversión. Guarda datos crudos
fuera del repositorio: pueden contener ventanas, rutas personales o dispositivos de red.
Publica resultados resumidos, comandos y capturas recortadas de contenido personal.

Un bloque se supera cuando puedes repetir su entrega y explicar el motivo de cada decisión.
Si no lo consigues, repite con un ejemplo pequeño antes de añadir funciones nuevas.

La wiki de Hyprland usa por defecto la versión de desarrollo: selecciona la versión indicada
por `hyprctl version` antes de copiar APIs. Véase el aviso de la
[documentación oficial](https://wiki.hypr.land/configuring/).
La configuración Lua actual se explica en [Core](https://wiki.hypr.land/configuring/core/), y
los tipos de tu shell en [Quickshell 0.3.2](https://quickshell.org/docs/v0.3.2/types/).

## Etapa 0 · Establecer una base recuperable — 1 semana

**Objetivo:** saber qué está funcionando y cómo volver a ello.

1. Lee la revisión y clasifica H1–H9: corregir, investigar o aceptar con un motivo.
2. Distingue cambios pendientes tuyos y cambios del ejercicio con `git status` y `git diff`.
   No uses `git reset --hard` ni publiques un `git add .` sin revisar.
3. Guarda el trabajo y planifica una sesión para comprobar acceso TTY, kernel LTS y respaldo.
4. Atiende primero H1: eliminar del bloqueo de producción la liberación temporizada de prueba.
   Hasta corregirla, no uses el modo `probar` como protección de una sesión.
5. Investiga el hub USB con conexión directa y después restaura un archivo desde restic.

Comprobaciones iniciales de solo lectura:

```bash
cd ~/dotfiles
git status --short
hyprctl version
hyprctl configerrors
systemctl --failed
systemctl --user --failed
systemctl list-timers --all
swapon --show
```

**Entrega:** lista de incidencias priorizada, un archivo recuperado y procedimiento TTY anotado.
**Pasas si:** puedes diferenciar «hay timer», «hubo copia» y «puedo restaurarla», y puedes recuperar
la sesión sin depender de que funcione el panel gráfico. Las pruebas que interrumpen la sesión
se hacen con trabajo guardado, no durante una actividad importante.

## Etapa 1 · Dominar lo que ya usas — 1–2 semanas

**Objetivo:** elegir herramientas del escritorio según la tarea.

Lee las secciones 4–9, 13 y 15–17 del [manual](manual.md). Practica con ventanas desechables:

- Haz una sesión de 30 minutos con foco, movimiento, intercambio y workspaces usando teclado.
- Resuelve la misma tarea con dwindle, master y scrolling; explica cuál te conviene y por qué.
- Crea un grupo, cambia pestañas y separa una ventana. Distingue grupo y workspace especial.
- Usa los tres scratchpads y los submaps de lanzar/redimensionar; practica salir con Escape.
- Identifica qué hace la capa de teclado del sistema y qué hace Hyprland. En esta revisión
  keyd estaba inactivo: no supongas que las capas del README están aplicadas.
- Revisa los gestos que cierran ventanas y el uso de `SUPER` para evitar acciones accidentales.

Archivos: `modulos/atajos.lua`, `layouts.lua`, `scratchpads.lua`, `submaps.lua`, `entrada.lua`
dentro de [`hypr/.config/hypr`](../hypr/.config/hypr/).

**Entrega:** una chuleta personal de diez acciones y un flujo de trabajo universidad/programación.
**Pasas si:** puedes organizar y recuperar el foco de seis ventanas sin recurrir al ratón y
explicas la diferencia entre mover foco, mover ventana, intercambiar y mover workspace.

## Etapa 2 · Entender Linux, Wayland y el inicio de sesión — 2 semanas

**Objetivo:** localizar la capa responsable de un fallo.

Estudia procesos, señales, descriptores, permisos Unix, variables de entorno, sockets, unidades
y D-Bus. Dibuja esta cadena con tus componentes: firmware → cargador → kernel → systemd → SDDM
→ `start-hyprland` → compositor → shell → aplicaciones.

Prácticas:

1. Explica por qué Hyprland es el compositor y Quickshell construye la interfaz del escritorio.
2. Identifica tres clientes Wayland y alguno XWayland si lo hay, sin publicar sus títulos.
3. Sigue un atajo desde `hl.bind` hasta el script o `IpcHandler` que termina ejecutándolo.
4. Compara servicios de usuario, servicios del sistema y programas lanzados por autostart.
5. Lee la entrada de sesión en `/usr/share/wayland-sessions/` y comprueba el proceso real.
   No migres a UWSM por una receta genérica: primero entiende tu arranque actual y su ciclo de vida.

```bash
systemctl --user status pipewire wireplumber
systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland
systemctl status sddm
hyprctl monitors
hyprctl devices
```

**Entrega:** diagrama de arquitectura con responsable, entrada, salida y log para cada componente.
**Pasas si:** ante «no hay audio», «no aparece la barra» y «no comparte pantalla» propones
comprobaciones distintas y justificas cuál harías primero.

## Etapa 3 · Lua y configuración mantenible — 2 semanas

**Objetivo:** modificar la configuración entendiendo su ciclo de vida.

Aprende tablas, funciones, cierres, módulos, `require`, alcance local/global, manejo de errores
y separación entre datos y acciones. Sigue las dependencias de `hyprland.lua`, `programas.lua`,
`utilidades.lua`, `colores.lua`, `autostart.lua` y `sesiones.lua`.

1. Dibuja qué módulos definen `_G` para llamadas externas y cuáles retornan una tabla.
2. Explica por qué `hyprland.start` evita duplicados al recargar y qué pasa con los timers.
3. Añade en una rama una sesión mínima para una aplicación inocua ya instalada; verifica que
   repetirla cuando la app está abierta no duplica ventanas.
4. Detecta los valores dependientes de máquina: monitor interno, rutas absolutas y apps opcionales.
5. Propón un módulo de datos de máquina; implementa solo un caso y verifica un valor de respaldo.

```bash
# Desde la raíz del repositorio; comprobar sintaxis no ejecuta el módulo.
luac -p hypr/.config/hypr/modulos/sesiones.lua
```

Los enlaces de stow apuntan al árbol de trabajo: **cambiar de rama o guardar Lua puede modificar
la sesión activa inmediatamente**. Para experimentar con APIs desconocidas usa un usuario de
pruebas o una VM. Una rama por sí sola no aísla el escritorio.

**Entrega:** módulo pequeño con propósito documentado y un commit que puedas revertir.
**Pasas si:** explicas cuándo se ejecuta el código y validas sintaxis, errores del compositor y
comportamiento. `luac -p` no conoce los objetos `hl` ni valida las APIs de Hyprland.

## Etapa 4 · Ventanas, reglas, monitores y portales — 2 semanas

**Objetivo:** automatizar ventanas sin reglas frágiles.

1. Usa `hyprctl -j clients` localmente para distinguir clase, título, workspace y XWayland.
2. Crea una regla estrecha para una app de prueba; comprueba ventanas normales, diálogos y segunda
   instancia. Evita depender de un título que cambia con el documento.
3. Revisa `reglas.lua`, `monitores.lua` y `presentacion.lua`; explica escala física/lógica,
   posiciones, espejo y extensión. En tu pantalla 1920×1080 con escala 1.5 el área lógica es menor.
4. Con un monitor disponible, ensaya conectar, duplicar, extender y desconectar. Comprueba foco,
   workspaces, bloqueo y presentación. Sin hardware, deja la prueba física como pendiente.
5. Comparte una ventana y una pantalla desde una aplicación de uso habitual; comprueba selección,
   audio cuando corresponda y finalización de captura. Un portal activo no garantiza todo eso.

**Entrega:** matriz de al menos seis casos con resultado y reversión de cada regla nueva.
**Pasas si:** puedes explicar qué parte resuelve el compositor, cuál el portal y cuál la app;
al desconectar un monitor conservas un escritorio utilizable.

## Etapa 5 · Shell, Python e IPC fiables — 2–3 semanas

**Objetivo:** que una automatización falle de forma comprensible.

Estudia códigos de salida, comillas, argumentos como listas, plazos, señales, archivos temporales,
escritura atómica, exclusión mutua e idempotencia. Usa como casos `replay.sh`, `bloquear.sh`,
`desbloqueo-emergencia.sh`, `tema.sh` y `tiempo-pantalla.py`.

1. Corrige H4 en un entorno de pruebas: salida 0 al simular sin incidencias, salida no cero al
   fallar una etapa. Comprueba que no se instale ni se reconfigure nada en simulación.
2. Define cómo detectar **tu** proceso de replay y no cualquier grabador del mismo nombre.
3. Añade un plazo a una consulta externa que pueda colgarse y una respuesta útil ante fallo.
4. Construye un pequeño consumidor del socket de eventos de Hyprland que cuente cambios de
   workspace sin guardar títulos. Incluye desconexión y reconexión de la instancia.
5. Define un contrato IPC: argumentos admitidos, estados, errores y quién puede invocarlo.
6. Prueba nombres de archivo con espacios y comillas, ausencia de una dependencia y llamadas
   repetidas. No construyas comandos de shell concatenando texto no validado.

**Entrega:** una automatización mejorada y una prueba de fallo real en aislamiento.
**Pasas si:** funciona dos veces sin duplicar procesos, no bloquea la interfaz y no informa
«éxito» cuando la operación no ocurrió. Introduce ShellCheck cuando trabajes en scripts;
no estaba instalado en la revisión. Consulta `man bash` y `man systemd.service` locales.

## Etapa 6 · Quickshell y QML reactivo — 2–3 semanas

**Objetivo:** crear un componente entendiendo estado y actualizaciones.

Lee [`shell.qml`](../quickshell/.config/quickshell/shell.qml), `Sistema.qml`, `Cargador.qml`,
`Notificaciones.qml` y `Bloqueo.qml`. Estudia propiedades, bindings, señales, modelos, singleton,
`Process`, `FileView`, `IpcHandler` y ciclo de vida en la
[API oficial de tu versión](https://quickshell.org/docs/v0.3.2/types/).

1. Dibuja qué estado pertenece al componente, a un singleton o al sistema externo.
2. Construye un indicador pequeño de salud de sesión que no muestre información privada.
3. Haz que sus procesos tengan plazo, indiquen fallo y no se solapen entre actualizaciones.
4. Actualiza por eventos cuando exista una señal adecuada; justifica los sondeos restantes.
5. Pausa trabajo innecesario de paneles ocultos. Prueba abrir/cerrar y recargar varias veces.
6. Separa el diseño de previsualización del bloqueo real; prueba cada uno sin compartir una
   ruta de liberación automática en producción.

**Entrega:** componente nuevo, captura de la interfaz y medición de actualizaciones/procesos.
**Pasas si:** explicas por qué se recalcula cada binding, qué ocurre al recargar y cómo se
representa un servicio ausente. Usa `qmllint` con imports adecuados; errores de imports ausentes
no equivalen por sí mismos a errores funcionales del QML.

## Etapa 7 · Rendimiento y batería con evidencia — 2 semanas

**Objetivo:** decidir cambios usando mediciones comparables.

Tu Ryzen 7520U/Radeon 610M comparte memoria con la GPU. Ya hay ahorro por batería, efectos y
replay continuo. No necesitas más ajustes hasta medir los existentes.

Diseña cuatro escenarios: reposo normal, reposo sin replay, reposo sin efectos y tu carga real.
Mantén brillo, apps, red y perfil de energía; espera estabilización y mide al menos tres veces
cada escenario durante cinco minutos. Cambia una variable por comparación.

| Medida | Herramienta o fuente | Qué registrar |
|---|---|---|
| CPU / RAM | btop, `ps`, `free -h` | Intervalo y procesos; separar caché y memoria disponible |
| GPU | radeontop, si ya está instalado | Carga en reposo y con replay |
| Perfil | `powerprofilesctl get` | Perfil y cargador conectado/desconectado |
| Energía | UPower o sysfs de la batería | Tasa de descarga si está disponible; condiciones |
| Interacción | Tarea repetible de ventanas/vídeo | Tirones observados y forma de reproducirlos |

No prometas una autonomía exacta con cinco minutos ni uses porcentajes acumulados de `ps` como
medida instantánea. Conserva la configuración anterior para comparar.

**Entrega:** tabla de muestras, mediana y decisión justificada sobre replay/efectos/sondeo.
**Pasas si:** puedes demostrar una mejora reproducible o concluir que el cambio no aporta.

## Etapa 8 · Recuperación, Btrfs y administración de Arch — 2 semanas

**Objetivo:** sobrevivir una actualización o un error humano.

1. Explica subvolúmenes, snapshots, exclusión del swapfile y retención. Distingue raíz y home.
2. Recupera un archivo de prueba desde un snapshot y otro desde restic a destinos nuevos.
   Comprueba contenido; nunca ensayes restaurar toda la raíz sobre la sesión activa.
3. Verifica arranque de LTS y retorno al kernel habitual. Anota cómo acceder al menú oculto.
4. Con trabajo guardado, prueba suspensión y después hibernación; comprueba recuperación de apps,
   bloqueo, red y audio. No concluyas que hibernación funciona solo por tener swap.
5. Revisa mantenimiento de paquetes y AUR: lee cambios y PKGBUILD antes de actualizar. Evita
   actualizaciones parciales y comprende qué paquetes puedes recuperar de caché o snapshots.
6. Registra el plan si falla SSD: copia externa, clave recuperable y medio de instalación.

Para restic, usa la [guía oficial de restauración](https://restic.readthedocs.io/en/stable/050_restore.html)
y el wrapper del proyecto: `respaldo estado`, `respaldo lista`, `respaldo comprobar`.
Estas operaciones requieren acceso al disco y, en el wrapper actual, privilegios.

**Entrega:** procedimiento de recuperación con tiempos medidos y pruebas marcadas pendientes.
**Pasas si:** recuperas un archivo sin sobrescribir el original y explicas qué perderías si
desaparece el SSD. Consulta también `man snapper`, `man btrfs` y `man systemd-sleep` instalados.

## Etapa 9 · Seguridad práctica de la sesión — 1–2 semanas

**Objetivo:** conocer los límites de confianza del escritorio.

1. Define amenazas concretas: acceso físico al portátil, app del mismo usuario, red no confiable
   y publicación accidental. No atribuyas al bloqueo protección frente a un disco sin cifrar.
2. Revisa PAM y prueba bloqueo normal, antes de suspensión, fallo de shell y recuperación por TTY.
   Prueba ambos monitores cuando estén disponibles; éxito requiere bloqueo confirmado.
3. Inventaría IPC del compositor y de Quickshell, capturadores y herramientas que escriben texto.
4. Revisa UFW con privilegios y contrasta reglas con sockets escuchando. Comprueba las excepciones
   de KDE Connect, Syncthing y Tailscale según las redes donde realmente los necesitas.
5. Revisa retención del portapapeles, capturas y replay. Usa datos sintéticos al probar secretos.
6. Estudia permisos de Hyprland antes de activarlos; comprueba que capturas y portales siguen
   funcionando. Los permisos no aíslan sus sockets IPC por sí solos, según la
   [documentación oficial](https://wiki.hypr.land/configuring/core/advanced-configuration/permissions/).

**Entrega:** mapa de permisos y pruebas con resultados, sin publicar reglas que revelen tu red.
**Pasas si:** explicas qué protege cada capa y has eliminado la liberación temporizada del bloqueo
de producción. No subas credenciales, claves restic, historiales ni configuración privada.

## Etapa 10 · Mantener y distribuir tu escritorio — 2 semanas

**Objetivo:** convertir los dotfiles en un proyecto reproducible.

1. Separa datos por máquina de configuración compartida: usuario, monitor, rutas y apps opcionales.
2. Haz que los modos juego/batería/presentación/concentración tengan estado explícito y un único
   cálculo de efectos y «No molestar». Prueba entrar/salir en distintos órdenes y recargar.
3. Alinea README y manual con keyd, rotación de fondos y funciones opcionales realmente activas.
4. Define checks de sintaxis y enlaces documentales en CI. Añade regresiones para fallos reales:
   salida de simulación, procesos duplicados y composición de modos.
5. Instala en VM con usuario diferente. Primero simula; luego verifica instalación y segunda
   ejecución. Una VM no certifica batería, USB, GPU ni suspensión de tu portátil.
6. Publica una versión con dependencias, limitaciones, capturas y procedimiento de desinstalación
   o reversión. Revisa el diff y añade únicamente archivos previstos en cada commit.

**Entrega:** instalación repetible en entorno limpio y una versión etiquetada con pruebas.
**Pasas si:** otra persona puede reproducir el entorno sin usar tus rutas ni copiar secretos.

## Etapa 11 · Desarrollo avanzado y contribución — itinerario abierto

**Objetivo:** pasar de configurar Hyprland a extenderlo con una contribución mantenible.

Prerrequisitos: etapas anteriores, Git cómodo, lectura de documentación técnica y fundamentos
de C++ antes de modificar el compositor. Empieza por un cambio pequeño y verificable.

Elige un proyecto:

| Proyecto | Qué aprendes | Criterio de cierre |
|---|---|---|
| Coordinador de modos | Máquinas de estados, precedencias, IPC | Combinaciones y recargas mantienen estado correcto |
| Monitor de salud de sesión | IPC, D-Bus, procesos y observabilidad | Detecta un fallo inducido sin sondeo excesivo |
| Layout propio en Lua | Geometría y ciclo de ventanas | Abrir, cerrar, mover, fullscreen y multimonitor comprobados |
| Corrección upstream | Código del compositor, compilación y revisión | Reproductor mínimo, parche y validación según el proyecto |

Para el último: usa el código y las instrucciones de contribución de
[hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) correspondientes a tu versión.
Compila en aislamiento; no sustituyas el compositor de la sesión de trabajo para experimentar.
Aprende a preparar un reproductor mínimo, leer backtraces y diferenciar fallo de app, shell,
compositor y controlador. Si desarrollas un plugin, estudia ABI y recompilación por versión.
Un plugin o un layout no es requisito para tener un buen escritorio: elige un problema real.

**Entrega:** proyecto con explicación de arquitectura, validación reproducible y limitaciones;
si corresponde, issue o PR upstream revisado según las normas del proyecto.
**Pasas si:** otra persona puede reproducir el problema y verificar tu solución sin tus dotfiles
completos. No necesitas que un mantenedor acepte el PR para demostrar ese aprendizaje.

## Primeros siete días

| Día | Trabajo | Resultado esperado |
|---|---|---|
| 1 | Leer revisión y recorrer arquitectura | Prioridades y dudas concretas |
| 2 | Trabajar H1 en entorno de pruebas | Bloqueo sin liberación temporizada de producción |
| 3 | Investigar USB directo/cable/hub | Comparación con horas y errores observados |
| 4 | Conectar respaldo y recuperar un archivo | Evidencia de restauración |
| 5 | Practicar teclado, layouts y grupos | Flujo diario elegido conscientemente |
| 6 | Seguir un atajo de Lua a IPC/QML | Explicación de extremo a extremo |
| 7 | Revisar entregas y planificar | Etapa de inicio y siguiente cambio pequeño |

No marques una tarea como terminada solo porque está documentada en esta ruta.

## Seguimiento de dominio

- [ ] Puedo recuperar la sesión desde TTY.
- [ ] Eliminé y validé la liberación temporizada del bloqueo de producción.
- [ ] Investigué los errores USB con una comparación controlada.
- [ ] Restauré un archivo desde una copia externa.
- [ ] Manejo ventanas y layouts con intención.
- [ ] Puedo explicar inicio de sesión, servicios y portales.
- [ ] Puedo escribir y depurar un módulo Lua pequeño.
- [ ] Puedo diseñar una regla sin depender de títulos frágiles.
- [ ] Mi automatización maneja fallos, plazos y llamadas repetidas.
- [ ] Mi componente QML maneja estado, recarga y servicio ausente.
- [ ] Medí rendimiento y energía con condiciones comparables.
- [ ] Probé recuperación con LTS y documenté suspensión/hibernación.
- [ ] Revisé permisos, sockets y privacidad de los datos generados.
- [ ] Instalé el escritorio en un entorno limpio con otro usuario.
- [ ] Puedo entregar una integración o corrección reproducible a otra persona.

Para cada casilla guarda fecha y evidencia. Esta lista describe habilidades por demostrar,
no certifica que las correcciones ya estén aplicadas.
