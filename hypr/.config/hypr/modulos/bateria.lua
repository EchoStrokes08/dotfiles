-- Batería: con el cargador desconectado, quita lo que más gasta GPU (blur y sombras; las
-- animaciones se quedan: sin ellas cuesta seguir qué pasa). Al enchufarlo vuelve todo como estaba.
--
-- Quién hace qué:
--   · Quickshell (Cargador.qml) vigila el cargador (UPower) y al cambiar llama aquí:
--       hyprctl dispatch 'bateria.ahorro() or hl.dsp.no_op()'
--       hyprctl dispatch 'bateria.normal() or hl.dsp.no_op()'
--     y además cambia el perfil de power-profiles-daemon (ahorro / el que tenías antes).
--   · Este archivo, al cargarse (o tras cualquier `hyprctl reload`, como al salir del modo juego),
--     mira el cargador él mismo: si estás con batería, vuelve a aplicar el ahorro.

local function con_cargador()
    -- ADP0 en este portátil; se aceptan otros nombres (AC, ACAD…) por si cambia de equipo
    for _, nombre in ipairs({ "ADP0", "ADP1", "AC", "AC0", "ACAD" }) do
        local f = io.open("/sys/class/power_supply/" .. nombre .. "/online", "r")
        if f then
            local v = f:read("l"); f:close()
            return v == "1"
        end
    end
    return true   -- sobremesa sin batería: siempre "enchufado"
end

local function ahorro()
    hl.config({
        decoration = {
            shadow = { enabled = false },
            blur   = { enabled = false },
        },
    })
end

local function normal()
    -- El modo juego también apaga cosas: si está activo, no tocar (al salir de él se recarga todo)
    if modo_juego and modo_juego.activo() then return end
    hl.exec_cmd("hyprctl reload")   -- vuelve a leer apariencia.lua y animaciones.lua tal cual
end

_G.bateria = { ahorro = ahorro, normal = normal, con_cargador = con_cargador }

if not con_cargador() then ahorro() end
