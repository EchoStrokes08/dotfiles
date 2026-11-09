-- Monitores: https://wiki.hypr.land/configuring/core/monitors/
-- Ver nombres, resoluciones y escalas: hyprctl monitors
local p   = require("modulos.programas")
local mod = p.mainMod

-- Pantalla del portátil
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto" })

-- Cualquier otro monitor que conectes (HDMI, USB-C): resolución nativa, a la DERECHA del portátil
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })

-- Ejemplos para cuando tengas uno concreto (descomentar y ajustar el nombre de hyprctl monitors):
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "auto-left", scale = 1 })   -- a la izquierda, 144 Hz
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })  -- duplicar (proyector)

-- Workspaces 6-10 en el monitor externo cuando esté conectado (si no, se quedan en el portátil)
-- for i = 6, 10 do hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1" }) end

-- Atajos entre monitores ("+1" = el siguiente, "-1" = el anterior; con uno solo no hacen nada)
hl.bind(mod .. " + CTRL + right",         hl.dsp.focus({ monitor = "+1" }))                 -- foco al otro monitor
hl.bind(mod .. " + CTRL + left",          hl.dsp.focus({ monitor = "-1" }))
hl.bind(mod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ monitor = "+1" }))           -- mandar la ventana
hl.bind(mod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mod .. " + CTRL + ALT + right",   hl.dsp.workspace.move({ monitor = "+1" }))        -- mandar el workspace entero

-- Al conectar/desconectar: menú duplicar/extender + No molestar → modulos/presentacion.lua
