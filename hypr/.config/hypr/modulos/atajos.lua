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

    -- Ratón: SUPER + clic izquierdo mueve, SUPER + clic derecho redimensiona
    { mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true } },
    { mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true } },

    -- Workspaces: rueda del ratón y scratchpad "magic"
    { mod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }) },
    { mod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }) },
    { mod .. " + S",           hl.dsp.workspace.toggle_special("magic") },
    { mod .. " + SHIFT + S",   hl.dsp.window.move({ workspace = "special:magic" }) },

    -- Sesión
    { mod .. " + L", exec("loginctl lock-session") },  -- bloquear (pasa por hypridle → hyprlock)
    { mod .. " + M", hl.dsp.exit() },
    { "ALT + F4",    exec("wlogout") },

    -- Notificaciones (swaync)
    { mod .. " + N",         exec("swaync-client -t -sw") },  -- abrir/cerrar el panel
    { mod .. " + SHIFT + N", exec("swaync-client -d -sw") },  -- No molestar

    -- Portapapeles
    { mod .. " + SHIFT + V", exec("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy") },

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

    -- Redmi Buds: cambiar de modo / alternar ANC
    { mod .. " + B",         exec("~/.local/bin/buds mode next --notify") },
    { mod .. " + SHIFT + B", exec("~/.local/bin/buds mode toggle --notify") },

    -- Teclas multimedia
    { "XF86AudioRaiseVolume",  exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), repetible },
    { "XF86AudioLowerVolume",  exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      repetible },
    { "XF86AudioMute",         exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     repetible },
    { "XF86AudioMicMute",      exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   repetible },
    { "XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+"),                  repetible },
    { "XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"),                  repetible },
    { "XF86AudioNext",  exec("playerctl next"),       fijo },
    { "XF86AudioPause", exec("playerctl play-pause"), fijo },
    { "XF86AudioPlay",  exec("playerctl play-pause"), fijo },
    { "XF86AudioPrev",  exec("playerctl previous"),   fijo },
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
