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

-- Juegos de Steam con Proton (Overcooked, Geometry Dash…) y gamescope: igual, tearing permitido
hl.window_rule({
    name  = "steam-juegos-immediate",
    match = { class = "^(steam_app_[0-9]+|gamescope)$" },
    immediate = true,
})

-- Blur detrás de la barra, avisos y el centro de control: solo bajo las islas y tarjetas (≥ 0.92 de opacidad).
-- Su sombra (hasta ~0.58 sumada a otra capa) queda por debajo de ignore_alpha: sin «marco fantasma».
hl.layer_rule({
    name         = "quickshell-blur",
    match        = { namespace = "^quickshell-(barra|osd|notificaciones|centro)$" },
    blur         = true,
    ignore_alpha = 0.6,
})
-- Paneles con velo (lanzador y todos los de Superpuesta.qml): el velo cubre la pantalla entera (0.25–0.28),
-- así que con un umbral bajo se desenfoca TODO el fondo de forma uniforme al abrirlos («escritorio que respira»).
-- Entra y sale con el fundido de la capa. Con batería, en Mínimo o jugando, politicas.lua apaga el blur global.
hl.layer_rule({
    name         = "quickshell-blur-velo",
    match        = { namespace = "^quickshell-(lanzador|wallpapers|portapapeles|menu|chuleta|vista|ia|nota|brujula|agente|movil|mesa|flujo|apagado|impresora|autorizacion)$" },
    blur         = true,
    ignore_alpha = 0.05,
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

-- Picture-in-Picture de Opera GX: igual que el de Firefox
hl.window_rule({
    name  = "pip-opera",
    match = { class = "^Opera GX$", title = "^(Picture in picture|Picture-in-Picture|Imagen en imagen)$" },
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
    size   = "(monitor_w*0.75) (monitor_h*0.8)",   -- que nunca se salga de la pantalla
    center = true,
})

-- Ventana de contraseña de polkit y selector de archivos del portal: flotantes y centradas
hl.window_rule({
    name   = "polkit-portal-flotante",
    match  = { class = "^(hyprpolkitagent|xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde)$" },
    float  = true,
    max_size = "(monitor_w*0.9) (monitor_h*0.9)",
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

-- ---------- Nivel 6: workspaces con propósito ----------
-- Cada app abre siempre en "su" workspace (y te lleva ahí). Con " silent" detrás abriría sin llevarte.
--   1 terminal · 2 navegador · 9 chats   (Spotify vive en su scratchpad: SUPER+Y)
hl.window_rule({ name = "ws-navegador", match = { initial_class = "^(firefox|Opera GX)$" },                   workspace = "2" })
hl.window_rule({ name = "ws-chats",     match = { initial_class = "^(com.rtosta.zapzap|discord|vesktop)$" }, workspace = "9" })

-- ---------- Animaciones por tipo (explicado al final de animaciones.lua) ----------
-- Estilos de ventana: "popin N%", "slide [left|right|top|bottom]", "gnomed"
hl.window_rule({
    name  = "anim-dialogos",
    match = { class = "^(hyprpolkitagent|xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde|zenity|org.pulseaudio.pavucontrol)$" },
    animation = "gnomed",
})
hl.window_rule({
    name  = "anim-dialogos-titulo",
    match = { title = "^(Open File|Save As|Save File|Abrir archivo|Guardar como|Guardar archivo|File Operation Progress|Progreso de la operación con archivos|Rename.*|Renombrar.*|Library|Biblioteca)$" },
    animation = "gnomed",
})
hl.window_rule({
    name  = "anim-pip",
    match = { class = "^(firefox|Opera GX)$", title = "^(Picture-in-Picture|Picture in picture|Imagen en imagen)$" },
    animation = "slide right",
})

-- Capas (layers). Estilos: "slide [lado]", "popin N%", "fade"
hl.layer_rule({ name = "anim-barra",          match = { namespace = "^quickshell-barra$" },          animation = "slide top" })
hl.layer_rule({ name = "anim-notificaciones", match = { namespace = "^quickshell-notificaciones$" }, animation = "slide right" })
hl.layer_rule({ name = "anim-escritorio",     match = { namespace = "^quickshell-escritorio$" },     animation = "fade" })
hl.layer_rule({
    name    = "anim-quickshell-propias",
    match   = { namespace = "^quickshell-(lanzador|centro|wallpapers|portapapeles|menu|chuleta|vista|osd|ia|nota|brujula|agente|movil|mesa|flujo)$" },
    no_anim = true,
})
hl.layer_rule({ name = "anim-lanzamiento", match = { namespace = "^quickshell-lanzamiento$" }, no_anim = true })   -- sale justo del icono
hl.layer_rule({ name = "anim-bienvenida", match = { namespace = "^quickshell-bienvenida$" }, no_anim = true })   -- negro desde el primer fotograma
hl.layer_rule({ name = "anim-fondo-vivo", match = { namespace = "^quickshell-fondo-vivo$" }, no_anim = true })   -- copia del wallpaper: aparece sin fundido
hl.layer_rule({ name = "anim-seleccion", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })

-- Editor de capturas (satty, SUPER+SHIFT+A): flotante y centrado, sin transparencia
hl.window_rule({
    name   = "satty-flotante",
    match  = { class = "^com.gabm.satty$" },
    float  = true,
    center = true,
    opaque = true,
    max_size = "(monitor_w*0.92) (monitor_h*0.9)",
    animation = "popin 92%",
})

-- Terminal de actualizar (clic en el módulo de actualizaciones de la barra): flotante y centrada
hl.window_rule({
    name   = "kitty-actualizar",
    match  = { class = "^kitty-actualizar$" },
    float  = true,
    size   = "900 520",
    center = true,
})
