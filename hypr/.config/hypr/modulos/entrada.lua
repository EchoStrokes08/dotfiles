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

        -- Repetición de teclas (Nivel 6, paso 7): al mantener una tecla, empieza antes y repite más rápido
        repeat_delay = 300,   -- ms hasta que empieza a repetir (antes 600)
        repeat_rate  = 40,    -- repeticiones por segundo (antes 25)

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,   -- tocar = clic (ya venía activo; aquí para que se vea)
            disable_while_typing = true,   -- ignorar el touchpad mientras escribes (también por defecto)
            clickfinger_behavior = true,   -- al HUNDIR el touchpad: 1 dedo = clic, 2 = derecho, 3 = central (en cualquier zona)
        },
    },

    -- Cursor: que no estorbe al escribir ni al leer
    cursor = {
        hide_on_key_press = true,  -- se esconde al teclear y vuelve al mover el ratón
        inactive_timeout  = 5,     -- y se esconde tras 5 s quieto
    },
})

-- Gestos del touchpad (Nivel 6, paso 3): https://wiki.hypr.land/configuring/core/binds/gestures/
-- Son 1:1: la animación sigue a los dedos y, si sueltas a medias, se cancela.
-- 3 dedos = navegar · 4 dedos = manipular la ventana · con SUPER = acciones "peligrosas" o raras
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })                 -- cambiar de workspace
hl.gesture({ fingers = 3, direction = "up",   action = "special", workspace_name = "magic" }) -- mostrar/ocultar el scratchpad
hl.gesture({ fingers = 3, direction = "down", action = function()                           -- dashboard de Quickshell
    hl.exec_cmd("qs ipc call dashboard toggle")
end })
hl.gesture({ fingers = 3, direction = "pinchout", action = "fullscreen" })                  -- abrir 3 dedos: pantalla completa (otra vez: salir)
hl.gesture({ fingers = 3, direction = "pinchin",  action = "float" })                       -- juntar 3 dedos: flotante ↔ mosaico

hl.gesture({ fingers = 4, direction = "swipe", action = "move" })                           -- arrastrar la ventana con 4 dedos
hl.gesture({ fingers = 4, direction = "swipe", mods = "SUPER", action = "resize" })         -- SUPER + 4 dedos: redimensionarla

hl.gesture({ fingers = 3, direction = "up", mods = "SUPER", action = function()                -- SUPER + 3 dedos arriba: vista general
    hl.exec_cmd("qs ipc call vista toggle")
end })
hl.gesture({ fingers = 3, direction = "down", mods = "SUPER", action = "close" })           -- SUPER + 3 dedos abajo: cerrar (con SUPER para no cerrar sin querer)
hl.gesture({ fingers = 2, direction = "pinch", mods = "SUPER", action = "cursor_zoom",      -- SUPER + pellizco: lupa alrededor del cursor
             zoom_level = 1, mode = "live" })

-- Config por dispositivo (ejemplo). Nombres: hyprctl devices
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
