-- Submaps (modos de teclado): https://wiki.hypr.land/configuring/core/binds/submaps/
-- Si te quedas atrapado en uno:  hyprctl dispatch 'hl.dsp.submap("reset")'
local p   = require("modulos.programas")
local u   = require("modulos.utilidades")
local mod = p.mainMod

-- Modo "redimensionar": SUPER+SHIFT+R; flechas cambian tamaño (mantener = repetir); Esc o Enter salen
hl.bind(mod .. " + SHIFT + R", hl.dsp.submap("redimensionar"))
hl.define_submap("redimensionar", function()
    local paso = 30  -- píxeles por pulsación
    hl.bind("right", hl.dsp.window.resize({ x =  paso, y = 0,     relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -paso, y = 0,     relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,     y =  paso, relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,     y = -paso, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Modo "lanzar": SUPER+A y luego UNA letra. Se cierra solo; cualquier otra tecla cancela.
hl.bind(mod .. " + A", hl.dsp.submap("lanzar"))
hl.define_submap("lanzar", "reset", function()
    hl.bind("F", u.enfocar_o_abrir("firefox", "firefox"))
    hl.bind("T", hl.dsp.exec_cmd(p.terminal))
    hl.bind("E", hl.dsp.exec_cmd(p.fileManager))
    hl.bind("W", u.enfocar_o_abrir("com.rtosta.zapzap", p.whatsapp))
    hl.bind("G", hl.dsp.exec_cmd(p.roblox))
    hl.bind("S", u.enfocar_o_abrir("spotify", p.spotify))
    hl.bind("catchall", hl.dsp.submap("reset"))
end)
