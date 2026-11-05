-- Modo juego: quita todo lo que cuesta GPU o distrae (animaciones, blur, sombras,
-- transparencia, huecos) y activa "No molestar" en swaync.
--   · SUPER+SHIFT+G lo activa o desactiva a mano
--   · se activa SOLO al abrir Roblox y se desactiva al cerrar la última ventana de Roblox
-- Desactivar = recargar la config (vuelve todo a como está en los demás módulos).
-- Waybar muestra el estado (módulo custom/modo-juego, señal 9) y con un clic lo alterna:
--   hyprctl dispatch 'modo_juego.alternar() or hl.dsp.no_op()'

local p = require("modulos.programas")

local JUEGOS = { ["org.vinegarhq.Sober"] = true }  -- añadir aquí más classes de juegos

local function activo()
    -- el estado se lee de Hyprland, así sobrevive aunque este archivo se recargue
    return hl.get_config("animations.enabled") == false
end

local function activar()
    if activo() then return end
    hl.config({
        general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
        animations = { enabled = false },
        decoration = {
            rounding         = 0,
            active_opacity   = 1.0,
            inactive_opacity = 1.0,
            shadow           = { enabled = false },
            blur             = { enabled = false },
        },
    })
    hl.exec_cmd("swaync-client -dn; pkill -RTMIN+9 waybar; swayosd-client --custom-message 'Modo juego activado' --custom-icon input-gaming-symbolic")  -- OSD: No molestar ocultaría una notificación
end

local function desactivar()
    if not activo() then return end
    hl.exec_cmd("swaync-client -df; hyprctl reload; pkill -RTMIN+9 waybar; swayosd-client --custom-message 'Modo juego desactivado' --custom-icon input-gaming-symbolic")
end

local function alternar()
    if activo() then desactivar() else activar() end
end

hl.bind(p.mainMod .. " + SHIFT + G", alternar)

-- Global (visible para hyprctl dispatch): así waybar puede alternar el modo con un clic
_G.modo_juego = { alternar = alternar, activo = activo }

-- Automático con los juegos de la lista
hl.on("window.open", function(w)
    if w and JUEGOS[w.class] then activar() end
end)

hl.on("window.close", function(w)
    if not (w and JUEGOS[w.class]) then return end
    -- ¿queda alguna otra ventana de un juego abierta?
    for _, otra in ipairs(hl.get_windows()) do
        if otra.address ~= w.address and JUEGOS[otra.class] then return end
    end
    desactivar()
end)
