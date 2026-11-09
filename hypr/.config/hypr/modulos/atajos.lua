-- Atajos de teclado: https://wiki.hypr.land/configuring/core/binds/
local p   = require("modulos.programas")
local u   = require("modulos.utilidades")
local mod = p.mainMod
local exec = hl.dsp.exec_cmd

-- Opciones reutilizables
local fijo      = { locked = true }                    -- funciona también con la pantalla bloqueada
local repetible = { locked = true, repeating = true }  -- y además se repite al mantener

u.atajos({
    -- Apps
    { mod .. " + Q", exec(p.terminal) },
    { mod .. " + E", exec(p.fileManager) },
    { mod .. " + R", exec(p.menu) },
    { mod .. " + W", u.enfocar_o_abrir("com.rtosta.zapzap", p.whatsapp) },
    { mod .. " + G", exec(p.roblox) },
    { mod .. " + D", exec("qs ipc call dashboard toggle") },   -- dashboard de Quickshell

    -- Ventanas
    { mod .. " + C", hl.dsp.window.close() },
    { mod .. " + V", hl.dsp.window.float({ action = "toggle" }) },
    { mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }) },
    { mod .. " + P", hl.dsp.window.pseudo() },
    { mod .. " + J", hl.dsp.layout("togglesplit") },  -- solo dwindle
    { mod .. " + I", exec("~/.config/hypr/scripts/inspector.sh") },  -- info de la ventana (para window rules)

    -- Mover el foco con las flechas
    { mod .. " + left",  hl.dsp.focus({ direction = "left" }) },
    { mod .. " + right", hl.dsp.focus({ direction = "right" }) },
    { mod .. " + up",    hl.dsp.focus({ direction = "up" }) },
    { mod .. " + down",  hl.dsp.focus({ direction = "down" }) },

    -- Mover la ventana con el teclado (Nivel 6)
    -- SHIFT = moverla en esa dirección: en dwindle cambia su sitio en el árbol (puede partir otro hueco).
    -- group_aware: si al lado hay un grupo, entra en él; si está en un grupo, sale por ese lado.
    { mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left", group_aware = true }) },
    { mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right", group_aware = true }) },
    { mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up", group_aware = true }) },
    { mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down", group_aware = true }) },
    -- ALT = intercambiarla con la vecina: las dos se cambian de sitio y el resto no se mueve
    { mod .. " + ALT + left",  hl.dsp.window.swap({ direction = "left" }) },
    { mod .. " + ALT + right", hl.dsp.window.swap({ direction = "right" }) },
    { mod .. " + ALT + up",    hl.dsp.window.swap({ direction = "up" }) },
    { mod .. " + ALT + down",  hl.dsp.window.swap({ direction = "down" }) },

    -- Ratón: SUPER + clic izquierdo mueve, SUPER + clic derecho redimensiona
    { mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true } },
    { mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true } },

    -- Workspaces: rueda del ratón y scratchpad "magic"
    { mod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }) },
    { mod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }) },
    { mod .. " + S",           hl.dsp.workspace.toggle_special("magic") },
    { mod .. " + SHIFT + S",   hl.dsp.window.move({ workspace = "special:magic" }) },

    -- Sesión
    { mod .. " + L", exec("loginctl lock-session") },  -- bloquear (hypridle → scripts/bloquear.sh → Quickshell; hyprlock de respaldo)
    { mod .. " + M", hl.dsp.exit() },
    { "ALT + F4",    exec("wlogout") },

    -- Notificaciones (Quickshell: Notificaciones.qml / CentroControl.qml)
    { mod .. " + N",         exec("qs ipc call notificaciones toggle") },      -- abrir/cerrar el centro de control
    { mod .. " + SHIFT + N", exec("qs ipc call notificaciones noMolestar") },  -- No molestar

    -- Portapapeles
    { mod .. " + SHIFT + V", exec("qs ipc call portapapeles toggle") },

    -- Wi-Fi y Bluetooth (Quickshell: Conexiones.qml). Tab cambia de pestaña dentro del panel
    { mod .. " + K", exec("qs ipc call conexiones toggle") },

    -- Capturas (archivo en ~/Imágenes/screenshots + portapapeles)
    { "PRINT",            exec([[mkdir -p ~/Imágenes/screenshots && grim -g "$(slurp)" - | tee ~/Imágenes/screenshots/$(date +'%Y%m%d_%H%M%S_grim.png') | wl-copy]]) },
    { mod .. " + PRINT",  exec([[mkdir -p ~/Imágenes/screenshots && grim - - | tee ~/Imágenes/screenshots/$(date +'%Y%m%d_%H%M%S_grim.png') | wl-copy]]) },

    { "SHIFT + PRINT",    exec("~/.config/hypr/scripts/capturas.sh") },  -- menú: región, pantalla, ventana, 5 s

    -- Wallpapers: menú con miniaturas / uno al azar
    { mod .. " + SHIFT + W",  exec("~/.config/hypr/scripts/wallpaper.sh") },
    { mod .. " + CTRL + W",   exec("~/.config/hypr/scripts/wallpaper.sh aleatorio") },

    -- Replay: guardar los últimos 30 s / encender-apagar
    { mod .. " + SHIFT + PRINT", exec("~/.config/hypr/scripts/replay.sh save") },
    { mod .. " + ALT + PRINT",   exec("~/.config/hypr/scripts/replay.sh toggle") },

    -- Redmi Buds: abrir (o ir a) Buds Manager / cambiar de modo (ANC → transparencia → apagado)
    { mod .. " + B",         u.enfocar_o_abrir("io.github.echostrokes08.BudsManager", "~/.local/bin/buds-manager") },
    { mod .. " + SHIFT + B", exec("~/.local/bin/buds mode next --notify") },

    -- Modo de energía: ahorro → equilibrado → rendimiento (con notificación)
    { mod .. " + SHIFT + P", exec("~/.config/hypr/scripts/modo-energia.sh") },

    -- Luz nocturna (hyprsunset; horario automático en hyprsunset.conf) y selector de color (hyprpicker)
    { mod .. " + ALT + N",   exec("~/.config/hypr/scripts/luz-nocturna.sh") },
    { mod .. " + SHIFT + C", exec("~/.config/hypr/scripts/selector-color.sh") },
    -- Modo concentración: temporizador, No molestar y apps que distraen escondidas
    { mod .. " + SHIFT + F", exec("qs ipc call menu concentracion") },

    -- Teclas multimedia. Volumen y micro: el OSD de Quickshell reacciona solo al cambio (escucha PipeWire).
    -- Brillo y música: se hace el cambio y luego se avisa al OSD (si qs no corre, las teclas siguen funcionando).
    { "XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), repetible },
    { "XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      repetible },
    { "XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     fijo },
    { "XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   fijo },
    { "XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+ && qs ipc call osd brillo"), repetible },
    { "XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%- && qs ipc call osd brillo"), repetible },
    { "XF86AudioNext",  exec("playerctl next; qs ipc call osd media"),       fijo },
    { "XF86AudioPause", exec("playerctl play-pause; qs ipc call osd media"), fijo },
    { "XF86AudioPlay",  exec("playerctl play-pause; qs ipc call osd media"), fijo },
    { "XF86AudioPrev",  exec("playerctl previous; qs ipc call osd media"),   fijo },

    -- Bloq Mayús: al SOLTAR la tecla se avisa al OSD; non_consuming = la tecla sigue funcionando
    { "Caps_Lock", exec("qs ipc call osd bloqMayus"), { release = true, non_consuming = true, ignore_mods = true, locked = true } },
})

-- Workspaces 1-10: SUPER+número va, SUPER+SHIFT+número mueve la ventana (el 0 es el 10)
for i = 1, 10 do
    local tecla = i % 10
    hl.bind(mod .. " + " .. tecla,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. tecla, hl.dsp.window.move({ workspace = i }))
end

-- SUPER+TAB: cambiar el layout del workspace actual (dwindle → master → scrolling → monocle → …)
-- Lo guarda como workspace rule, así cada workspace recuerda el suyo hasta recargar la config.
hl.bind(mod .. " + TAB", function()
    local layouts = { "dwindle", "master", "scrolling", "monocle" }
    local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not ws then return end
    local siguiente = layouts[1]
    for i, nombre in ipairs(layouts) do
        if nombre == ws.tiled_layout then siguiente = layouts[(i % #layouts) + 1] break end
    end
    -- ojo: el ejemplo de la wiki usa "name:N", pero para workspaces numerados hay que usar el id ("1")
    local selector = ws.special and tostring(ws.name) or tostring(ws.id)
    hl.workspace_rule({ workspace = selector, layout = siguiente })
    hl.exec_cmd("notify-send -a Layout -t 1500 'Layout' '" .. siguiente .. "'")
end)

-- Navegación rápida (Nivel 6, paso 2)
-- SUPER+número sobre el workspace en el que ya estás → vuelve al anterior (ir y volver con la misma tecla)
hl.config({ binds = { workspace_back_and_forth = true } })

-- SUPER + tecla a la izquierda del 1 (en latam: | ° ¬): saltar a la última ventana enfocada, aunque esté en otro workspace.
-- Se usa el código físico de la tecla (code:49) para que no dependa de la distribución del teclado.
hl.bind(mod .. " + code:49", hl.dsp.focus({ last = true }))

-- ALT+TAB / ALT+SHIFT+TAB: recorrer las ventanas del workspace y traer la elegida al frente (útil con flotantes)
hl.bind("ALT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind("ALT + SHIFT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

-- Grupos / pestañas (Nivel 6, paso 4). Para meter o sacar ventanas: SUPER+SHIFT+flechas (ver arriba)
hl.bind(mod .. " + T",              hl.dsp.group.toggle())                          -- convertir la ventana en grupo / deshacerlo
hl.bind(mod .. " + period",         hl.dsp.group.next())                            -- pestaña siguiente
hl.bind(mod .. " + comma",          hl.dsp.group.prev())                            -- pestaña anterior
hl.bind(mod .. " + SHIFT + period", hl.dsp.group.move_window({ forward = true }))   -- mover la pestaña a la derecha
hl.bind(mod .. " + SHIFT + comma",  hl.dsp.group.move_window({ forward = false }))  -- mover la pestaña a la izquierda
