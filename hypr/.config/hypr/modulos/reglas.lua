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
