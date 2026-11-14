# ORION · Lista de tareas

Plan de implementación derivado de la auditoría del 13 de noviembre de 2026.
Cuatro fases: confianza, diseño, recorridos y consolidación. `[x]` significa implementado y verificado;
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

- [ ] 3.1 Resultados tipados y acciones compartidas en lanzador; menú secundario visible con teclado/ratón, Enter para principal y Esc con devolución de foco.
- [ ] 3.2 Ventanas: enfocar, mover a un espacio reconocible, aparcar/recuperar y cerrar. Plantillas: copiar, editar, duplicar y borrar con recuperación.
- [ ] 3.3 Proyectos: guardar, retomar, cambiar siguiente paso, actualizar ventanas y archivar. Archivos: abrir, carpeta, copiar ruta y elegir aplicación. Vista previa cuando aporte información.
- [ ] 3.4 Historial con títulos humanos y dominio, URL íntegra para abrir/copiar; ventana privada y ocultar en ORION sin confundirlo con borrar en Firefox. Eventos/tareas con acciones según capacidades reales.
- [ ] 3.5 Reforzar búsqueda asíncrona: consultas vigentes, resultados anteriores identificados mientras carga, errores por fuente y ausencia de coincidencias diferenciados.
- [ ] 3.6 Conservar identidad de calendario, serie, ocurrencia y excepciones; resumir recurrencias en Próximo sin deducir periodicidad por títulos ni perder recordatorios.
- [ ] 3.7 Agrupar notificaciones por app/conversación, preservando acciones, respuestas y urgencias. No molestar 30 min/1 h/hasta fin de actividad/indefinido, vencimiento absoluto y motivos automáticos independientes. Resumen al terminar sin ráfaga de emergentes.
- [ ] 3.8 Sugerencias: confirmar resultado antes de anunciar éxito y distinguir «app abierta» de tarea completada. Recordatorios: detalle al pulsar título y completar/descartar explícitos. Deshacer coherente para acciones reversibles.
- [ ] 3.9 Estados de carga/error/actualización para móvil, búsqueda y demás fuentes que aún oculten fallos; reintentos locales y diagnóstico breve.
- [ ] 3.10 IA opcional y no bloqueante en Hoy; conservar caché diaria y expiración ya existentes. Actividades explicables reutilizando reunión/concentración/juego y salida manual visible.
- [ ] 3.11 Reutilizar privacidad en sugerencias, títulos, avisos y previsualizaciones, incluidos reunión y captura. Agente sobre las mismas acciones y estados verificables.

Aceptación: mover una ventana y editar una plantilla no exige Mesa; No molestar vence correctamente incluso tras
suspender o recargar; una serie se resume sin fusionar eventos distintos; acciones fallidas no dicen «Hecho».

## Fase 4 · Consolidación, accesibilidad y coste

- [ ] 4.1 Matriz de equivalencia de Mesa/Flujo/Móvil/Resumen/IA: ventanas, plantillas, proyectos, rutinas, reunión y conversación. Retirar superficies duplicadas solo con equivalencia completa; conservar servicios y compatibilidad IPC temporal.
- [ ] 4.2 Controles y pestañas con foco, rol y estado accesible; Tab recorre controles y Ctrl+Tab cambia pestaña. Probar abrir, actuar, cancelar y volver a la aplicación sin ratón.
- [ ] 4.3 Medir shell y auxiliares en reposo, música, panel y agente, con alimentación/carga registradas. Revisar sondeos, eventos y visualizador; conservar reconciliación útil de replay automático solo en juego.
- [ ] 4.4 Revisar instalación/respaldos de archivos generados, diagnóstico y recuperación desde terminal; corregir advertencias de recursos HTTP en pruebas.
- [ ] 4.5 Actualizar manuales, diseño, atajos, capturas y script de capturas a recorridos finales; verificar coherencia de apps, bloqueo y arranque sin imponer cambios privilegiados durante la edición del shell.
- [ ] 4.6 Suite y simulación de instalación, matriz visual, fallos inducidos, recurrencias/zonas horarias, búsqueda fuera de orden, suspensión y segundo monitor. Registrar rendimiento comparable y pendientes reales antes de cerrar.

Aceptación: sin funciones huérfanas, documentación del comportamiento final, controles operables con teclado y
mediciones reproducibles. No usar RAM total o longitud del manual como sustitutos de experiencia comprobada.

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
