-- Modo presentación: al conectar un proyector, TV o monitor (HDMI/USB-C) aparece un menú
--   Duplicar · Extender a la derecha · Solo la externa · Solo el portátil
-- y se activa No molestar (que no salgan notificaciones delante de la clase). Al desconectarlo,
-- todo vuelve: pantalla del portátil encendida y No molestar apagado.
--   SUPER+ALT+P       volver a abrir el menú (con algo conectado)
--   hyprctl dispatch 'pantalla.duplicar("HDMI-A-1") or hl.dsp.no_op()'   (también extender / solo_externa / solo_portatil)
-- Probar sin cables:  hyprctl output create headless   (crea una pantalla falsa; quitarla: hyprctl output remove HEADLESS-2)
local p   = require("modulos.programas")
local INTERNA = "eDP-1"

local function externa()   -- el primer monitor que no es el del portátil
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= INTERNA then return m.name end
    end
end

-- OJO: hl.monitor COMBINA con la regla anterior de esa salida (no la sustituye). Por eso cada opción
-- dice explícitamente mirror = "" y disabled = false: si no, un «duplicar» o «solo la externa» de antes
-- se quedaría pegado.
local function interna_encendida()
    hl.monitor({ output = INTERNA, mode = "preferred", position = "0x0", scale = "auto", mirror = "", disabled = false })
end

local pantalla = {}
function pantalla.duplicar(nombre)
    nombre = nombre or externa(); if not nombre then return end
    interna_encendida()
    hl.monitor({ output = nombre, mode = "preferred", position = "auto", scale = "auto", mirror = INTERNA, disabled = false })
end
function pantalla.extender(nombre)
    nombre = nombre or externa(); if not nombre then return end
    interna_encendida()
    hl.monitor({ output = nombre, mode = "preferred", position = "auto-right", scale = "auto", mirror = "", disabled = false })
end
function pantalla.solo_externa(nombre)
    nombre = nombre or externa(); if not nombre then return end
    hl.monitor({ output = nombre, mode = "preferred", position = "0x0", scale = "auto", mirror = "", disabled = false })
    hl.monitor({ output = INTERNA, mirror = "", disabled = true })
end
function pantalla.solo_portatil(nombre)
    nombre = nombre or externa(); if not nombre then return end
    interna_encendida()
    hl.monitor({ output = nombre, mirror = "", disabled = true })
end
function pantalla.menu(nombre)
    nombre = nombre or externa()
    if not nombre then
        hl.exec_cmd("notify-send -a Pantallas 'No hay ninguna pantalla externa conectada'")
        return
    end
    hl.exec_cmd("qs ipc call menu pantalla " .. nombre)
end
_G.pantalla = pantalla

hl.bind(p.mainMod .. " + ALT + P", function() pantalla.menu() end)

hl.on("monitor.added", function(m)
    if not m or m.name == INTERNA then return end
    require("modulos.escritorio").motivo("presentacion", true)
    -- un instante para que el monitor termine de aparecer antes de enseñar el menú
    hl.exec_cmd("sleep 1; qs ipc call menu pantalla " .. m.name)
end)

hl.on("monitor.removed", function(m)
    if not m or m.name == INTERNA then return end
    interna_encendida()   -- por si estaba en «solo la externa»: nunca quedarse sin pantalla
    local quedan = false
    for _, otra in ipairs(hl.get_monitors()) do
        if otra.name ~= INTERNA and otra.name ~= m.name then quedan = true end
    end
    require("modulos.escritorio").motivo("presentacion", quedan)
    hl.exec_cmd("qs ipc call osd mensaje 'Pantalla externa desconectada' f0379")
end)
