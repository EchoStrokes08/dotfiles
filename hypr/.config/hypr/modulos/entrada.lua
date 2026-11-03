-- Teclado, ratón y touchpad: https://wiki.hypr.land/configuring/core/config-options/#input
hl.config({
    input = {
        kb_layout  = "latam",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        numlock_by_default = true,  -- Bloq Num activo al iniciar (contraseña de hyprlock)
        follow_mouse       = 1,
        sensitivity        = 0,     -- -1.0 a 1.0; 0 = sin cambio

        touchpad = { natural_scroll = true },
    },
})

-- Gesto: deslizar 3 dedos en horizontal cambia de workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Config por dispositivo (ejemplo). Nombres: hyprctl devices
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
