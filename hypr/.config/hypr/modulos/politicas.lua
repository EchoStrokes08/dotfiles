-- Motor puro: sin IPC ni archivos; probado con Lua fuera del compositor.
local M = {}
M.perfiles = { cristal = true, lectura = true, minimo = true, rendimiento = true }
-- Ventanas que activan el modo juego automático: Roblox (Sober), los juegos de Steam (Proton: steam_app_<id>)
-- y los que van dentro de gamescope (FSR, scripts/juego-fsr.sh)
function M.es_juego(clase, entorno)
    return clase == "org.vinegarhq.Sober" or clase == "gamescope"
        or (type(clase) == "string" and clase:match("^steam_app_%d+$") ~= nil)
        or (type(entorno) == "string" and ("\0" .. entorno):match("%zSteamAppId=[1-9]%d*%z") ~= nil)
end
M.base = {
    general = { gaps_in = 4, gaps_out = 8, border_size = 2 },
    animations = { enabled = true },
    -- Cursor: que no estorbe al escribir ni al leer (se esconde al teclear y tras 5 s quieto)
    cursor = { hide_on_key_press = true, inactive_timeout = 5 },
    decoration = {
        -- Ventanas opacas: el cristal es para los paneles, no para el contenido (kitty lleva su propio fondo translúcido)
        rounding = 10, active_opacity = 1.0, inactive_opacity = 1.0,
        shadow = { enabled = true }, blur = { enabled = true },
    },
}
local function copiar(t)
    local r = {}
    for k, v in pairs(t) do r[k] = type(v) == "table" and copiar(v) or v end
    return r
end
function M.resolver(e)
    local c = copiar(M.base)
    local perfil = M.perfiles[e.perfil] and e.perfil or "cristal"
    local juego = e.juego == "si" or (e.juego ~= "no" and e.juego_auto == true)
    if perfil ~= "cristal" then
        c.decoration.active_opacity = 1
        c.decoration.inactive_opacity = 1
        c.decoration.blur.enabled = false
    end
    if perfil == "minimo" or perfil == "rendimiento" or juego then
        c.animations.enabled = false
        c.decoration.shadow.enabled = false
        c.decoration.blur.enabled = false
        c.decoration.active_opacity = 1
        c.decoration.inactive_opacity = 1
        c.decoration.rounding = 0
    end
    if juego then
        -- En juegos el ratón es del juego: esconderlo al pulsar Shift rompe el shift lock de Roblox
        c.cursor.hide_on_key_press = false
        c.cursor.inactive_timeout = 0
    end
    if perfil == "rendimiento" or juego then
        c.general.gaps_in = 0
        c.general.gaps_out = 0
        c.general.border_size = 1
    end
    if e.bateria then
        c.decoration.blur.enabled = false
        c.decoration.shadow.enabled = false
    end
    return {
        config = c, juego = juego,
        no_molestar = juego or e.presentacion == true or e.concentracion == true or e.privacidad == true or e.reunion == true,
    }
end
return M
