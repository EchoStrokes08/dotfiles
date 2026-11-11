-- Motor puro: sin IPC ni archivos; probado con Lua fuera del compositor.
local M = {}
M.perfiles = { cristal = true, lectura = true, minimo = true, rendimiento = true }
M.base = {
    general = { gaps_in = 3.5, gaps_out = 7.5, border_size = 4 },
    animations = { enabled = true },
    decoration = {
        rounding = 3, active_opacity = 0.80, inactive_opacity = 0.70,
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
        pausar_replay = e.bateria == true or e.privacidad == true or perfil == "minimo" or e.reunion == true,
    }
end
return M
