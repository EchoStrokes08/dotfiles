-- Tema de colores y wallpapers (Nivel 4: theming dinámico)
--   SUPER+SHIFT+T  alterna entre colores Ayu y colores sacados del wallpaper
--   SUPER+CTRL+T   alterna entre tema claro y oscuro
--   Automático (APAGADO de serie): claro de día y oscuro de noche. Encenderlo: tema.sh auto on
--   Menú de wallpapers (SUPER+SHIFT+W) también tiene la opción.
-- Scripts: ~/.config/hypr/scripts/tema.sh y wallpaper.sh · plantillas: ~/.config/tema/
local p   = require("modulos.programas")
local mod = p.mainMod
local TEMA = "~/.config/hypr/scripts/tema.sh"

hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(TEMA .. " alternar"))
hl.bind(mod .. " + CTRL + T",  hl.dsp.exec_cmd(TEMA .. " variante"))

-- Rotación de wallpaper cada 17,5 minutos (antes lo hacía hyprpaper con timeout = 600).
-- Al recargar la config el temporizador vuelve a empezar desde cero.
local MINUTOS = 17.5
hl.timer(function()
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper.sh aleatorio")
end, { timeout = MINUTOS * 60 * 1000, type = "repeat" })

-- ---------- Tema automático por hora ----------
-- En Bogotá amanece ~5:45 y anochece ~17:50 todo el año, así que un horario fijo basta.
local CLARO_DESDE  = 6 * 60 + 30   -- 6:30
local OSCURO_DESDE = 18 * 60       -- 18:00
local ESTADO = os.getenv("HOME") .. "/.local/state/tema/"

local function leer(nombre)
    local f = io.open(ESTADO .. nombre, "r")
    if not f then return nil end
    local v = f:read("l"); f:close()
    return v
end

-- Solo se actúa al CRUZAR una hora: "ultimo_auto" guarda lo último que tocaba. Así, si cambias
-- el tema a mano, se respeta hasta el siguiente cambio de horario (igual que la luz nocturna).
local function revisar_hora()
    if leer("auto") ~= "on" then return end   -- apagado salvo que lo enciendas (tema.sh auto on)
    local t = os.date("*t")
    local minutos = t.hour * 60 + t.min
    local toca = (minutos >= CLARO_DESDE and minutos < OSCURO_DESDE) and "claro" or "oscuro"
    if toca == leer("ultimo_auto") then return end
    -- cambiar de tema recarga la config, y eso sacaría del modo juego: se espera a que termine
    if modo_juego and modo_juego.activo() then return end
    hl.exec_cmd(TEMA .. " automatico " .. toca)
end

hl.timer(revisar_hora, { timeout = 60 * 1000, type = "repeat" })
hl.timer(revisar_hora, { timeout = 3000, type = "oneshot" })   -- y poco después de cargar (inicio de sesión)
