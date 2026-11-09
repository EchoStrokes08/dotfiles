-- Atajos que se adaptan al layout (Nivel 6, paso 8)
-- Las mismas teclas hacen "lo equivalente" en cada layout. SUPER+TAB cambia de layout (atajos.lua).
--
--   tecla               dwindle               master                   scrolling
--   SUPER + plus        división más grande   área principal más ancha columna más ancha (anchos fijos)
--   SUPER + minus       división más pequeña  área principal más fina  columna más estrecha
--   SUPER + Z           llevar a la raíz      cambiar con la principal centrar la columna
--   SUPER + X           invertir la división  girar la orientación     meter/sacar de la columna anterior
--   SUPER+SHIFT+plus    —                     una principal más        —
--   SUPER+SHIFT+minus   —                     una principal menos      —
--
-- Mensajes de cada layout: https://wiki.hypr.land/configuring/layouts/
local p   = require("modulos.programas")
local mod = p.mainMod

-- Layout del workspace activo (o del scratchpad abierto, si lo hay)
local function layout_actual()
    local ws = hl.get_active_special_workspace() or hl.get_active_workspace()
    return ws and ws.tiled_layout or "dwindle"
end

-- acciones = { dwindle = dispatcher, master = ..., scrolling = ... }; si el layout no tiene, no hace nada
local function segun_layout(acciones)
    return function()
        local accion = acciones[layout_actual()]
        if accion then hl.dispatch(accion) end
    end
end

local msg = hl.dsp.layout

hl.bind(mod .. " + plus", segun_layout({
    dwindle   = msg("splitratio +0.1"),
    master    = msg("mfact +0.05"),
    scrolling = msg("colresize +conf"),
}), { repeating = true })

hl.bind(mod .. " + minus", segun_layout({
    dwindle   = msg("splitratio -0.1"),
    master    = msg("mfact -0.05"),
    scrolling = msg("colresize -conf"),
}), { repeating = true })

hl.bind(mod .. " + Z", segun_layout({
    dwindle   = msg("movetoroot"),
    master    = msg("swapwithmaster"),
    scrolling = msg("center"),
}))

hl.bind(mod .. " + X", segun_layout({
    dwindle   = msg("swapsplit"),
    master    = msg("orientationnext"),
    scrolling = msg("consume_or_expel prev"),
}))

hl.bind(mod .. " + SHIFT + plus",  segun_layout({ master = msg("addmaster") }))
hl.bind(mod .. " + SHIFT + minus", segun_layout({ master = msg("removemaster") }))
