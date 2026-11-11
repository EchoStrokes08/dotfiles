-- Compatibilidad de atajos/barra con el coordinador: estado explícito, sin recargar Hyprland.
local c = require("modulos.escritorio")
_G.modo_juego = { alternar = c.alternar_juego, activo = c.juego_activo }
hl.bind(require("modulos.programas").mainMod .. " + SHIFT + G", c.alternar_juego)
hl.on("window.open", function(w)
    if w and w.class == "org.vinegarhq.Sober" then c.ventanas_cambiaron() end
end)
hl.on("window.close", function(w)
    if w and w.class == "org.vinegarhq.Sober" then c.ventanas_cambiaron(w.address) end
end)
