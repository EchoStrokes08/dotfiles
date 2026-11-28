-- Look and feel: https://wiki.hypr.land/configuring/core/config-options/
local c = require("modulos.colores")
local base = require("modulos.politicas").base

hl.config({
    general = {
        gaps_in     = base.general.gaps_in,  -- espacio entre ventanas
        gaps_out    = base.general.gaps_out,  -- espacio entre las ventanas y el borde de la pantalla
        border_size = base.general.border_size,

        resize_on_border = false,  -- true = redimensionar arrastrando bordes y huecos
        allow_tearing    = true,   -- solo afecta a ventanas con la regla "immediate" (Roblox)
        layout           = "dwindle",
    },

    decoration = {
        rounding       = base.decoration.rounding,  -- radio de las esquinas
        rounding_power = 3,

        active_opacity     = base.decoration.active_opacity,
        inactive_opacity   = base.decoration.inactive_opacity,
        fullscreen_opacity = 1.0,  -- en pantalla completa nada es transparente

        -- Sombra amplia y suave, como la de los paneles de Quickshell
        shadow = {
            enabled      = true,
            range        = 26,
            render_power = 3,
        },

        -- Blur fuerte: detrás de un panel no se debe poder leer nada. Con batería se apaga solo (politicas.lua).
        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            noise    = 0.02,     -- grano fino: evita bandas en los degradados
            vibrancy = 0.1696,
        },
    },

    animations = { enabled = base.animations.enabled },

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
        groupbar = {
            enabled             = true,
            font_family         = "Adwaita Sans",
            font_size           = 12,
            height              = 20,
            gradients           = true,   -- pestañas rellenas de color (no solo una línea)
            rounding            = 8,
            gradient_rounding   = 8,
            indicator_height    = 0,      -- sin rayita extra: ya se ve por el relleno
            gaps_in             = 3,
            keep_upper_gap      = false,
            middle_click_close  = true,   -- clic central en una pestaña = cerrarla
        },
    },
})

-- ---------- Colores ----------
-- Todo lo que depende de la paleta va aquí, en una función: al cambiar de tema o de wallpaper, tema.sh la
-- llama en caliente (hyprctl dispatch 'colores_tema() or hl.dsp.no_op()') en vez de hacer «hyprctl reload».
-- Una recarga completa reinicia temporizadores y reglas de espacio, y el 13-11-2026 dejó Hyprland colgado.
-- borde_musica(a, b, sombra): mientras suena algo con carátula, Quickshell (BordeMusica.qml) pone en el
-- borde activo y su resplandor los colores de la portada; borde_musica() vuelve a los del tema.
local musica = nil
local function colores()
    local acento, acento2 = c.rgba("acento", "ff"), c.rgba("acento2", "ff")
    local brillo = c.rgba("acento", "3d")
    if musica then acento, acento2, brillo = musica[1], musica[2], musica[3] end
    hl.config({
        general = { col = {
            -- borde activo: degradado acento → acento2 en diagonal (gira una vez al enfocar: borderangle en
            -- animaciones.lua). El inactivo, casi invisible: la ventana activa se reconoce por su luz
            active_border   = { colors = { acento, acento2 }, angle = 45 },
            inactive_border = c.rgba("texto", "14"),
        } },
        -- La ventana activa proyecta un resplandor del acento; las demás, una sombra neutra
        decoration = { shadow = { color = brillo, color_inactive = c.rgba("fondo", "66") } },
        group = {
            col = {
                -- borde de una ventana agrupada: acento2, para distinguirla de una normal (acento)
                border_active   = c.rgba("acento2", "ee"),
                border_inactive = c.rgba("seleccion", "aa"),
            },
            groupbar = {
                text_color          = c.rgba("fondo"),         -- texto de la pestaña activa (sobre el acento)
                text_color_inactive = c.rgba("texto", "cc"),
                col = {
                    active   = c.rgba("acento", "ee"),
                    inactive = c.rgba("seleccion", "dd"),
                },
            },
        },
    })
end
colores()

_G.borde_musica = function(a, b, sombra)
    musica = a and { a, b or a, sombra or a } or nil
    colores()
end

_G.colores_tema = function()
    c.recargar()
    colores()
end
