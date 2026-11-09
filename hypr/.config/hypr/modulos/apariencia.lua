-- Look and feel: https://wiki.hypr.land/configuring/core/config-options/
local c = require("modulos.colores")

hl.config({
    general = {
        gaps_in     = 3.5,  -- espacio entre ventanas
        gaps_out    = 7.5,  -- espacio entre las ventanas y el borde de la pantalla
        border_size = 4,

        col = {
            -- borde activo: degradado naranja → azul a 135°
            active_border   = { colors = { c.rgba("naranja", "ee"), c.rgba("azul", "ff") }, angle = 135 },
            inactive_border = c.rgba("seleccion", "aa"),
        },

        resize_on_border = false,  -- true = redimensionar arrastrando bordes y huecos
        allow_tearing    = true,   -- solo afecta a ventanas con la regla "immediate" (Roblox)
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 3,  -- radio de las esquinas
        rounding_power = 3,

        active_opacity     = 0.80,
        inactive_opacity   = 0.70,
        fullscreen_opacity = 1.0,  -- en pantalla completa nada es transparente

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "0xee" .. c.fondo,
        },

        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = { enabled = true },

    -- Layouts: dwindle (el actual), master y scrolling. Se cambia con general.layout
    dwindle   = { preserve_split = true },
    master    = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },
})

-- "Smart gaps" (Nivel 6, paso 6): una sola ventana en mosaico ocupa toda la pantalla, sin huecos, borde ni esquinas.
--   w[tv1] = workspace con exactamente 1 ventana en mosaico visible · f[1] = workspace con una ventana maximizada
-- Para volver a los huecos siempre: comentar estas 4 líneas.
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })

-- Grupos = ventanas apiladas en pestañas (Nivel 6, paso 4). Atajos en atajos.lua (SUPER+T, SUPER+, y SUPER+.)
-- Los colores salen de colores.lua, así que siguen al tema (Ayu o wallpaper) igual que el resto.
hl.config({
    group = {
        col = {
            -- borde de una ventana agrupada: amarillo → naranja, para distinguirla de una normal (naranja → azul)
            border_active   = { colors = { c.rgba("amarillo", "ee"), c.rgba("naranja", "ff") }, angle = 135 },
            border_inactive = c.rgba("seleccion", "aa"),
        },
        groupbar = {
            enabled             = true,
            font_family         = "JetBrainsMono Nerd Font",
            font_size           = 11,
            height              = 18,
            gradients           = true,   -- pestañas rellenas de color (no solo una línea)
            rounding            = 4,
            gradient_rounding   = 4,
            indicator_height    = 0,      -- sin rayita extra: ya se ve por el relleno
            gaps_in             = 3,
            keep_upper_gap      = false,
            middle_click_close  = true,   -- clic central en una pestaña = cerrarla
            text_color          = c.rgba("fondo"),         -- texto de la pestaña activa (sobre naranja)
            text_color_inactive = c.rgba("texto", "cc"),
            col = {
                active   = c.rgba("naranja", "ee"),
                inactive = c.rgba("seleccion", "dd"),
            },
        },
    },
})
