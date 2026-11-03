-- Tema de colores y wallpapers (Nivel 4: theming dinámico)
--   SUPER+SHIFT+T  alterna entre colores Ayu y colores sacados del wallpaper
--   Menú de wallpapers (SUPER+SHIFT+W) también tiene la opción.
-- Scripts: ~/.config/hypr/scripts/tema.sh y wallpaper.sh · plantillas: ~/.config/tema/
local p   = require("modulos.programas")
local mod = p.mainMod

hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/tema.sh alternar"))

-- Rotación de wallpaper cada 10 minutos (antes lo hacía hyprpaper con timeout = 600).
-- Al recargar la config el temporizador vuelve a empezar desde cero.
local MINUTOS = 10
hl.timer(function()
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper.sh aleatorio")
end, { timeout = MINUTOS * 60 * 1000, type = "repeat" })
