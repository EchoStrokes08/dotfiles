-- Reglas de ventanas y capas: https://wiki.hypr.land/configuring/core/rules/
-- Ver la class de una ventana: hyprctl clients  ·  namespace de una capa: hyprctl layers

-- Ignorar las peticiones de "maximizar" de todas las apps (en mosaico no tienen sentido)
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Arreglo para arrastrar cosas en apps XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = true, pin = false },
    no_focus = true,
})

-- Ventana de "ejecutar" de Hyprland: flotante, abajo a la izquierda
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Roblox (Sober): tearing permitido = menor latencia de entrada
hl.window_rule({
    name  = "roblox-sober-immediate",
    match = { class = "^(org.vinegarhq.Sober)$" },
    immediate = true,
})

-- Navegador, juegos y video siempre 100 % opacos (ignoran active/inactive_opacity)
hl.window_rule({
    name   = "opaco-navegador-juegos-video",
    match  = { class = "^(firefox|org.vinegarhq.Sober|mpv|vlc)$" },
    opaque = true,
})

-- Blur detrás del panel y las notificaciones de swaync.
-- Ojo: las layer rules se aplican cuando la capa se CREA → tras cambiarlas, reiniciar swaync.
hl.layer_rule({
    name         = "swaync-blur",
    match        = { namespace = "swaync-control-center|swaync-notification-window" },
    blur         = true,
    ignore_alpha = 0.3,
})

-- Blur detrás de la tarjeta del dashboard de Quickshell (el resto de la capa es transparente → ignore_alpha)
hl.layer_rule({
    name         = "quickshell-blur",
    match        = { namespace = "quickshell-(dashboard|lanzador|osd)" },
    blur         = true,
    ignore_alpha = 0.3,
})

-- ---------- Nivel 3: reglas para el día a día ----------

-- Picture-in-Picture de Firefox: flotante, fijo en todos los workspaces, esquina inferior derecha
hl.window_rule({
    name  = "pip-firefox",
    match = { class = "^firefox$", title = "^(Picture-in-Picture|Imagen en imagen)$" },
    float = true,
    pin   = true,
    size  = "480 270",
    move  = "monitor_w-490 monitor_h-280",
    keep_aspect_ratio = true,
    opaque = true,
})

-- Diálogos que no deberían ocupar medio mosaico: flotantes y centrados
hl.window_rule({
    name   = "dialogos-flotantes",
    match  = { title = "^(Open File|Save As|Save File|Abrir archivo|Guardar como|Guardar archivo|File Operation Progress|Progreso de la operación con archivos|Rename.*|Renombrar.*)$" },
    float  = true,
    center = true,
})

-- Ventana de contraseña de polkit y selector de archivos del portal: flotantes y centradas
hl.window_rule({
    name   = "polkit-portal-flotante",
    match  = { class = "^(hyprpolkitagent|xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde)$" },
    float  = true,
    center = true,
})

-- Descargas / biblioteca de Firefox: flotante, tamaño cómodo
hl.window_rule({
    name   = "firefox-biblioteca",
    match  = { class = "^firefox$", title = "^(Library|Biblioteca)$" },
    float  = true,
    size   = "900 600",
    center = true,
})

-- Ventana de instalación (la kitty "Instalando-temas" que abre Claude): flotante y centrada
hl.window_rule({
    name   = "kitty-instalador",
    match  = { class = "^kitty$", title = "^Instalando.*" },
    float  = true,
    size   = "900 500",
    center = true,
})

-- Calendario al hacer clic en la hora de waybar (~/.config/hypr/scripts/calendario.sh):
-- flotante, en todos los workspaces, centrado arriba justo debajo de la barra
hl.window_rule({
    name  = "calendario-waybar",
    match = { class = "^zenity$", title = "^Calendario$" },
    float = true,
    pin   = true,
    move  = "(monitor_w*0.5)-(window_w*0.5) 44",
})
