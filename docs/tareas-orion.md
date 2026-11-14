# ORION · Lista de tareas

Plan de implementación derivado de la auditoría del 13 de noviembre de 2026.
Cinco fases: confianza, diseño, recorridos, consolidación y pulido. `[x]` significa implementado y verificado;
`[~]` implementado y con pruebas, pendiente del cierre (capturas y comprobación en el escritorio); `[-]` medido y descartado;
las limitaciones de comprobación se anotan en el cierre de cada fase. La configuración activa enlaza a este repositorio.

## Fase 1 · Estados fiables y recuperación

- [x] 1.1 Avisar de una recarga QML fallida, conservar la interfaz válida y ofrecer detalle y reintento. Documentar diagnóstico cuando Quickshell no arranca.
- [x] 1.2 Sustituir el éxito optimista de conmutadores por orden supervisada y lectura confirmada. Mostrar aplicando, disponible/apagado, activado, no disponible y error; permitir reintento sin bloquear todo el centro.
- [x] 1.3 Indicar los modos `redimensionar` y `lanzar`, sus teclas y cómo salir. Reconstruir el estado al iniciar o recuperar la conexión al compositor.
- [x] 1.4 Distinguir agenda actualizada, cargando, sin configurar, caché desactualizada y error. Conservar los últimos datos válidos, mostrar última sincronización y permitir reintento.
- [x] 1.5 Añadir regresiones de fallos y recuperación; comprobar carga QML, suite existente y capturas de los estados nuevos. Registrar límites de verificación en vivo.

Aceptación: una orden fallida no aparece como activada; una recarga fallida tiene recuperación visible;
el modo de teclado tiene salida explícita; datos antiguos no se presentan como recién sincronizados.

## Fase 2 · Diseño y espacio útil

- [x] 2.1 Superficies oscuras y claras casi neutras en shell y plantillas de aplicaciones; acento del wallpaper o Ayu y opción de fijarlo. Texto sobre acento con contraste adecuado.
- [x] 2.2 Seguimiento de la rotación con fundido de 500 ms y movimiento reducido. Generación ligera, caché por imagen/variante, exclusión mutua, publicación coherente y descarte de generaciones atrasadas. Conservar el tema válido al fallar matugen.
- [x] 2.3 Reducir gradientes, medallas y luces repetidos; mantener jerarquía mediante tonos sólidos en mínimo. Mantener letra legible y separar preferencia de movimiento de efectos y alimentación.
- [x] 2.4 Hoy a dos columnas cuando quepa: agenda/próximo/proyecto y calendario/clima/resumen de actividad. Quitar reloj grande y tiempo encendido; trasladar métricas a Salud, sin anillos (ajuste solicitado durante la fase 2); frase y sugerencias secundarias. Calendario completo a 1280×720 y un único desplazamiento en alturas menores.
- [x] 2.5 Seleccionar un día actualiza la agenda; regreso a Hoy y creación de evento/tarea claramente diferenciados.
- [x] 2.6 Compactar centro: cabecera corta, perfil visual en selector, volumen/brillo, mezclador desplegable, música compacta y área útil de avisos. Conexiones con flecha visible; bloqueo/apagado compactos; Más controles y favoritos.
- [x] 2.7 Diferenciar perfil visual de perfil energético; explicar políticas de batería, juego, privacidad y reunión. Replay con estados de política, grabación, pausa y error.
- [x] 2.8 Buds con iconos y porcentajes de I/D visibles en la barra y estuche cuando esté disponible (preferencia explícita solicitada durante la fase 2); desconocidos distintos de cero. Evitar duplicación con bandeja, mantener acceso al menú de Buds Manager.
- [x] 2.9 Bandeja contraíble con favoritos; conservar identidad y colores informativos. Priorizar grabación, micrófono, privacidad, batería crítica y teclado; limitar título/música y estabilizar alertas de recursos.
- [x] 2.10 Quitar `⌃1` de etiquetas permanentes, llevar atajos a ayudas y distinguir «Color actual» de «Cambiar colores».
- [x] 2.11 Comparar claro/oscuro, Ayu/wallpaper y cristal/mínimo; comprobar contraste de superficies reales y paletas generadas, escala fraccionaria y monitores cuando estén disponibles. Guardar capturas comparables.

Aceptación: agenda y calendario legibles sin recorte en 1280×720; ningún control apagado parece inutilizable;
la barra cede espacio a estados importantes; mínimo conserva profundidad; texto legible sobre cada selección.

## Fase 3 · Recorridos completos y funciones útiles

- [~] 3.1 Resultados tipados y acciones compartidas en lanzador; menú secundario visible con teclado/ratón, Enter para principal y Esc con devolución de foco.
- [~] 3.2 Ventanas: enfocar, mover a un espacio reconocible, aparcar/recuperar y cerrar. Plantillas: copiar, editar, duplicar y borrar con recuperación.
- [~] 3.3 Proyectos: guardar, retomar, cambiar siguiente paso, actualizar ventanas y archivar. Archivos: abrir, carpeta, copiar ruta y elegir aplicación. Vista previa cuando aporte información.
- [~] 3.4 Historial con títulos humanos y dominio, URL íntegra para abrir/copiar; ventana privada y ocultar en ORION sin confundirlo con borrar en Firefox. Eventos/tareas con acciones según capacidades reales.
- [~] 3.5 Reforzar búsqueda asíncrona: consultas vigentes, resultados anteriores identificados mientras carga, errores por fuente y ausencia de coincidencias diferenciados.
- [~] 3.6 Conservar identidad de calendario, serie, ocurrencia y excepciones; resumir recurrencias en Próximo sin deducir periodicidad por títulos ni perder recordatorios.
- [~] 3.7 Agrupar notificaciones por app/conversación, preservando acciones, respuestas y urgencias. No molestar 30 min/1 h/hasta fin de actividad/indefinido, vencimiento absoluto y motivos automáticos independientes. Resumen al terminar sin ráfaga de emergentes.
- [~] 3.8 Sugerencias: confirmar resultado antes de anunciar éxito y distinguir «app abierta» de tarea completada. Recordatorios: detalle al pulsar título y completar/descartar explícitos. Deshacer coherente para acciones reversibles.
- [~] 3.9 Estados de carga/error/actualización para móvil, búsqueda y demás fuentes que aún oculten fallos; reintentos locales y diagnóstico breve.
- [~] 3.10 IA opcional y no bloqueante en Hoy; conservar caché diaria y expiración ya existentes. Actividades explicables reutilizando reunión/concentración/juego y salida manual visible.
- [~] 3.11 Reutilizar privacidad en sugerencias, títulos, avisos y previsualizaciones, incluidos reunión y captura. Agente sobre las mismas acciones y estados verificables.

Aceptación: mover una ventana y editar una plantilla no exige Mesa; No molestar vence correctamente incluso tras
suspender o recargar; una serie se resume sin fusionar eventos distintos; acciones fallidas no dicen «Hecho».

## Fase 4 · Consolidación, accesibilidad y coste

- [ ] 4.1 Matriz de equivalencia de Mesa/Flujo/Móvil/Resumen/IA: ventanas, plantillas, proyectos, rutinas, reunión y conversación. Retirar superficies duplicadas solo con equivalencia completa; conservar servicios y compatibilidad IPC temporal.
- [ ] 4.2 Controles y pestañas con foco, rol y estado accesible; Tab recorre controles y Ctrl+Tab cambia pestaña. Probar abrir, actuar, cancelar y volver a la aplicación sin ratón.
- [ ] 4.3 Perfilar los servicios de la barra (≈ 126 MB sobre el motor, ver 5.12). Medir shell y auxiliares en reposo, música, panel y agente, con alimentación/carga registradas. Revisar sondeos, eventos y visualizador; conservar reconciliación útil de replay automático solo en juego.
- [ ] 4.4 Revisar instalación/respaldos de archivos generados, diagnóstico y recuperación desde terminal; corregir advertencias de recursos HTTP en pruebas.
- [ ] 4.5 Actualizar manuales, diseño, atajos, capturas y script de capturas a recorridos finales; verificar coherencia de apps, bloqueo y arranque sin imponer cambios privilegiados durante la edición del shell.
- [ ] 4.6 Suite y simulación de instalación, matriz visual, fallos inducidos, recurrencias/zonas horarias, búsqueda fuera de orden, suspensión y segundo monitor. Registrar rendimiento comparable y pendientes reales antes de cerrar.

Aceptación: sin funciones huérfanas, documentación del comportamiento final, controles operables con teclado y
mediciones reproducibles. No usar RAM total o longitud del manual como sustitutos de experiencia comprobada.

## Fase 5 · Pulido visible y funciones nuevas

Añadida tras la revisión en vivo del 13 de noviembre de 2026 (21:45, sesión real a 1280×720 lógicos,
modo wallpaper oscuro, juego abierto). Ataca lo que todavía se nota cada día.

- [x] 5.1 Agenda que explica sus fallos: `gcal.py` devuelve un código (`api_desactivada`, `sin_permiso`, `sin_red`) y `EstadoAgenda` muestra la causa y la salida («Activa Google Tasks API en tu proyecto»), sin exponer URL ni claves. Un evento en curso dice «Ahora · termina 21:45», no «Próximo».
- [x] 5.2 Hoy sin huecos: si la agenda del día tiene menos de tres elementos, la columna izquierda muestra «Próximos días» (3 días) y tareas pendientes. El botón «Hoy» solo aparece con otro día elegido. Fuera «Tu día, a tu ritmo» y el subtítulo «Tu día». Una serie diaria no pone punto en todos los días del calendario: puntos solo para eventos no diarios, o intensidad por número de eventos.
- [x] 5.3 Selección sin tinte turbio: con fondos cálidos u oscuros el acento tintado se vuelve marrón (pestaña activa, fila del lanzador, burbuja del agente, tarjetas activas). Selección = superficie `elevada` neutra + indicador o borde de 2 px de `acento`; sin el brillo central en degradado de `FondoBoton.qml` ni en pestañas. `tema.py` garantiza croma mínima del acento y `test_tema_orion.py` lo comprueba con una paleta de atardecer.
- [x] 5.4 Centro · Inicio con avisos visibles: hoy la lista queda reducida a «Avisos · 5» al fondo. Reservar al menos tres grupos visibles; Wi-Fi y Bluetooth como botón dividido (flecha dentro de la misma tarjeta) que muestre red o dispositivo en lugar de «Activado»; «Más controles» en filas de 48 px con la estrella integrada; la ayuda emergente de la barra no tapa un panel abierto.
- [x] 5.5 Lanzador en reposo útil: secciones «Recientes» y «Sugerido ahora» (según hora y actividad), con encabezado; pie con «Enter abrir · Alt+Enter acciones · Tab prefijos»; icono de respaldo para entradas sin icono (p. ej. Buds Manager).
- [x] 5.6 Agente más limpio: «Copiar texto» y «Ver original» solo al pasar el ratón, con foco o con atajo; fuentes como chips con dominio que se abren; burbuja del usuario en superficie neutra.
- [x] 5.7 Barra: Buds en una sola cápsula (I/D/estuche dentro, mismos datos y la misma preferencia); chip de próxima cita junto a la hora cuando falten 30 min o menos.
- [x] 5.8 Ajustes desde el lanzador: «oscuro», «brillo 40», «wifi», «no molestar 1 h», «reunión» como resultados tipados que reutilizan `conmutadores.py`, el control confirmado y sus estados de error.
- [x] 5.9 Ayuda al mantener SUPER: tras 0,6 s, una capa con los atajos esenciales y los del modo o ventana activa; desaparece al soltar. Sustituye la necesidad de abrir la chuleta para lo común.
- [x] 5.10 Historial de avisos buscable desde el lanzador (prefijo `!`) y escala de interfaz 100/110/125 % en preferencias, aplicada por `EstiloPanel`.
- [x] 5.11 IPC con nombres ciertos: `dashboard irA` cambia de **espacio**, no de pestaña de Brújula. Crear `espacios ir` y `brujula pagina`, mantener el alias antiguo un tiempo y documentarlo.
- [-] 5.12 Carga perezosa de paneles: `shell.qml` instancia 18 superficies al arrancar; `qs` ocupaba 425 MB RSS durante la revisión. Cargar con `Loader` los paneles grandes al abrirlos (Agente, Mesa, Flujo, Brújula, Vista) y medir antes/después con el método de 4.3.

Aceptación: con la agenda vacía Hoy no deja la mitad del panel en blanco; un fallo de Google dice qué hacer;
ninguna selección se ve marrón con el wallpaper más cálido; el centro enseña avisos sin desplazarse;
un ajuste común se cambia desde el lanzador sin abrir el centro.

## Registro de la fase 1

**Completada el 13 de noviembre de 2026.** El avance posterior se registra más abajo.

Implementación:

- `EstadoRecarga`, `AvisoRecarga` y `TarjetaRecarga`: error persistente con detalle seleccionable y reintento; independiente de No molestar. Diagnóstico de arranque desde terminal documentado.
- `conmutadores.py` y `ControlRapido`: consulta de disponibilidad, órdenes idempotentes, comprobación del estado posterior, límites de tiempo, error recuperable y bloqueo individual. Las consultas atrasadas no pisan confirmaciones recientes.
- `ModoTeclado` e `IndicadorTeclado`: eventos compartidos entre barras, ayuda y salida, consulta inicial/reconexión con `hl.get_current_submap()` de Hyprland 0.57. El título de ventana cede espacio durante el modo.
- `eventos.py --estado`, `Eventos` y `EstadoAgenda`: datos con frescura y fecha de sincronización, caché válida conservada y reintento. Se mantiene el formato de lista anterior para los otros consumidores; los errores no exponen las URL iCal.
- Manual de usuario, diagnóstico técnico, pruebas y captura reproducible de componentes actualizados.

Verificación de cierre:

- **157 pruebas Python: OK**, incluidas **5 pruebas de interacción QML** ejecutadas con Quickshell real en configuraciones temporales. Cubren orden pendiente/fallida/confirmada, reconstrucción del modo, caché/JSON inválido/recuperación y recarga inválida seguida de corrección.
- Regresiones de backend: dispositivo ausente, servicio fallido, permisos, dependencia ausente, timeout, falta de confirmación, orden idempotente y protección de dirección privada del calendario.
- Sintaxis Python y Bash correcta; análisis QML de Qt 6 sin errores de sintaxis. El analizador estático emite advertencias de tipos dinámicos de Quickshell, por lo que no se presenta como un lint semántico sin advertencias.
- `git diff --check`: sin problemas. `./instalar.sh --simular`: salida 0, «Todo en orden».
- El registro de la instancia activa termina las recargas con **Configuration Loaded**; no fue necesario reiniciar Hyprland.
- [Captura de los componentes con datos simulados](screenshots/orion-fase1-estados.png), generada mediante `python3 tests/previsualizar_orion.py`. Usa componentes reales, con HOME/runtime temporales y sin información personal.

Límite de verificación: el entorno de ejecución impide conectar con los sockets de la sesión
(Wayland, Hyprland y D-Bus). Las pruebas inducidas y la captura se hicieron fuera de la sesión
personal. No se afirma haber conmutado radios físicos ni probado el ratón en el escritorio activo.
La comprobación visual completa a distintas resoluciones pertenece a la fase 2.

La auditoría original permanece en `~/Downloads/ORION - Auditoria UX y propuesta de evolucion.md`.
La copia de esta lista para consulta está en `~/Downloads/ORION - Lista de tareas.md`;
la versión mantenida junto al código es este archivo.


## Registro de la fase 2

**Completada el 13 de noviembre de 2026.** La fase 3 comienza a continuación por petición del usuario.

- Tema con superficies neutras, contraste verificado, acento adaptable/fijable, fundido de 500 ms y preferencia de movimiento independiente de batería. Generación cacheada, publicación atómica y conservación de la paleta válida ante fallos.
- Hoy a dos columnas: calendario completo y agenda del día seleccionado, con regreso a Hoy y creación diferenciada de evento/tarea. Información secundaria desplegable.
- Salud rediseñada a petición del usuario: métricas compactas sin anillos, avisos prioritarios y revisiones sobrias desplegables; conserva diagnóstico, mantenimiento y acciones.
- Centro compacto, perfil visual claramente separado de energía, mezclador y música desplegables, flechas de dispositivos, favoritos y explicación del replay.
- Bandeja contraíble con favoritos y atención prioritaria. A petición del usuario se conservan **iconos y porcentajes individuales de Buds en la barra**, incluido estuche cuando hay lectura; se evita duplicar Buds Manager sin ocultar una petición de atención.
- 170 pruebas Python correctas, incluidas 8 de interacción QML; 768 combinaciones de política Lua y prueba de apariencia correctas. Sintaxis y `git diff --check` correctos; simulación de instalación finalizada en «Todo en orden».
- Matriz real de 8 combinaciones (Ayu/fondo × claro/oscuro × cristal/mínimo), capturada en `~/.cache/capturas-escritorio/orion-fase2/`. Pantalla física 1920×1080 a escala 1,5: 1280×720 lógicos. Pruebas QML adicionales de geometría y adaptación a una columna. No hay segundo monitor físico conectado.
- Contraste probado sobre fondo, selección, tarjeta, elevación y selección tintada, además de texto sobre acento sólido; colores extremos también se corrigen.
- [Captura final de Salud](screenshots/orion-fase2-salud.png). Las capturas con agenda/reproductor se mantienen fuera del repositorio.
- La configuración activa cargó correctamente. Fue necesario reiniciar Quickshell una vez durante el desarrollo; Hyprland no se reinició. Se restauraron el modo wallpaper oscuro y el perfil visual previo (rendimiento).


## Estado de la fase 3

**Implementada en código el 13 de noviembre de 2026; pendiente de cierre.** Se incorporó al repositorio
en los commits `b9d7d2a` y `b257a51`.

- `acciones.py` + `AccionesResultado`/`AccionesServicio`: resultados tipados, inspector con formularios,
  deshacer con token y revisión, rechazo de referencias inyectadas. Ventanas, plantillas, proyectos,
  archivos, historial web (ocultar en ORION sin tocar Firefox), eventos y tareas.
- `buscar.py`: resultados por fuente a medida que llegan, errores por fuente y cancelación del proceso hijo.
- `eventos.py`: calendario, serie, ocurrencia y excepción conservados; la regla se describe solo si existe.
- `NotificacionesLogica.js`: grupos por app y conversación; No molestar con vencimiento absoluto,
  «hasta terminar» actividad y motivos automáticos independientes.
- Sugerencias que dicen «Solicitud enviada» y no «Hecho»; recordatorios con descarte explícito y recuperable;
  frase de IA solo desde caché al abrir Hoy; captura privada con expiración y liberación por dueño.
- Agente con Markdown y fórmulas (MathJax local en `scripts/vendor/mathjax`).
- **205 pruebas Python: OK**, incluidas las de interacción QML.

Falta para marcar `[x]`: capturas de los recorridos, el resumen al salir de No molestar sin ráfaga (3.7)
comprobado en vivo y la prueba de suspensión con una pausa activa.

Revisión en vivo del mismo día (base de la fase 5): el aviso «Las tareas no se pudieron actualizar» salía
dos veces porque el botón repetía el error; corregido (el botón dice «Reintentar»). La causa real es un
403 de Google: la API de Google Tasks no está activada en el proyecto de Cloud del usuario.

## Registro de la fase 5

**Fase 5 cerrada el 13 de noviembre de 2026** (5.12 medida y descartada).

- 5.3: `FondoSeleccion.qml` y los tokens `seleccionado`, `seleccionadoEncima` y `bordeSeleccion` de `EstiloPanel`.
  La selección es una superficie neutra con un borde de acento; sin degradados ni resplandor de color en
  `FondoBoton`, pestañas (`NavegacionPanel`, Brújula), fila del lanzador, conversación actual y medallas.
  La burbuja del usuario del agente usa `elevada`. Comprobado en vista aislada con un acento cálido (`#f2a68c`).
- 5.4: Wi-Fi y Bluetooth en tarjetas compactas de 52 px con la flecha dentro y la red o el dispositivo
  conectado como estado; favoritos en la misma rejilla; perfil visual movido a «Más · Apariencia»; mezclador
  como botón junto al volumen; No molestar en una fila; la lista de avisos tiene un mínimo de 180 px.
  «Más controles» en filas compactas con estrella de 40 px.
- 5.2: sin eslogan ni subtítulo en Hoy; «Volver a hoy» solo con otro día elegido; «Ahora · termina HH:mm»
  para el evento en curso; tareas vencidas visibles con su fecha; tarjeta «Próximos días» cuando el día tiene
  menos de tres elementos; los puntos del calendario ignoran las series diarias (`Eventos.marcaEn`).
- Pruebas: 204 correctas. La configuración activa recargó sin errores; Hoy y la pestaña «Más» se revisaron
  en la sesión real. La comprobación de 5.3 sin efectos (perfil mínimo) y en modo claro queda para 4.6.
- 5.1: `gcal.py` clasifica los errores (`api_desactivada`, `sin_permiso`, `sin_conectar`, `sin_red`, `servicio`)
  con ayuda y enlace a Google Cloud cuando existe; Hoy muestra la causa y «Abrir Google Cloud». Pruebas en
  `test_calendario.py` (clase `ErroresDeGoogle`).
- 5.5: lanzador en reposo con «Sugerido ahora» (compromiso en ≤ 60 min o en curso, proyecto en curso, tareas),
  «Recientes» por uso y «Todas las apps»; pie con las teclas; inicial como respaldo de iconos ausentes.
- 5.6: en los mensajes del agente, «Copiar» y «Ver original» solo con el ratón encima o con foco; los enlaces
  citados aparecen como chips con el dominio.
- 5.7: Buds en una cápsula (mismos datos e iconos); chip «Título · 12 min» junto a la hora con una cita en
  ≤ 30 min o en curso, oculto con privacidad.
- 5.8: ajustes sin prefijo: «brillo 40», «volumen 30», «wifi», «bluetooth off», «luz nocturna», «no molestar 1 h»,
  «oscuro», «reunión». Los interruptores pasan por `conmutadores.sh` y solo anuncian el cambio confirmado.
  Nuevo IPC `notificaciones pausar <modo>`.
- 5.9: `AyudaSuper.qml`. Pulsación larga de SUPER sola (`long_press` de Hyprland, 300 ms, + 300 ms): esenciales
  de `docs/atajos.md` y teclas de la ventana o del modo; se oculta al soltar y no aparece si entre medias hay otro
  atajo, un panel nuevo o movimiento del ratón. `wtype` no activa atajos de Hyprland, así que la tecla física la
  comprueba la persona; la ruta IPC (`qs ipc call ayudaSuper mantener|soltar|estado`) se comprobó en vivo.
- 5.10: historial local de avisos (`~/.local/state/quickshell/avisos.jsonl`, máx. 500; sin avisos con privacidad
  ni códigos de verificación) buscable con `!` en el lanzador. «Tamaño de la interfaz» 100/110/125 % en
  «Más › Apariencia»: `scripts/shell.sh` arranca Quickshell con `QT_SCALE_FACTOR` y `autostart.lua` lo usa.
  El cambio reinicia la barra; no se probó el reinicio en la sesión activa.
- 5.11: IPC `espacios ir|actual`; `dashboard irA` queda como alias documentado.
- 5.12 (descartada tras medir): RSS de instancias aisladas en la sesión real, 8 s tras arrancar:
  motor vacío 161 MB · solo barra 287 MB · todo 385 MB · sin Agente, Mesa, Flujo y Vista 374 MB · sin un panel
  cualquiera 375–386 MB. La carga perezosa ahorraría ≈ 3 % a cambio de reestructurar más de 2.000 líneas.
  El coste está en el motor y en los servicios que carga la barra: pasa a 4.3.
- Pruebas: 207 correctas, incluidas las de interacción QML; pruebas Lua correctas; recarga sin errores.
