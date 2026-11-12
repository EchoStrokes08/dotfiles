-- Coordinador de perfiles y motivos. Estado por instancia: sobrevive a reload, no a otro login.
local motor = require("modulos.politicas")
local p = require("modulos.programas")
local M = {}
local e = { perfil = "cristal", juego = "automatico", privacidad = false }
local runtime = os.getenv("XDG_RUNTIME_DIR")
local firma = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""):gsub("[^%w_%-]", "")
local archivo = runtime and (runtime .. "/hypr-escritorio-" .. firma .. ".state")
local function leer()
    local f = archivo and io.open(archivo, "r")
    if not f then return end
    for linea in f:lines() do
        local k, v = linea:match("^(%w+)=(%w+)$")
        if k == "perfil" and motor.perfiles[v] then e.perfil = v end
        if k == "juego" and (v == "si" or v == "no" or v == "automatico") then e.juego = v end
        if k == "privacidad" then e.privacidad = v == "true" end
    end
    f:close()
end
local function reunion_activa()
    local f = runtime and io.open(runtime .. "/hypr-reunion-" .. firma .. ".json", "r")
    if not f then return false end
    local fin = tonumber(f:read("a"):match('"fin"%s*:%s*(%d+)')) or 0
    f:close()
    return fin > os.time()
end
local function detectar()
    e.juego_auto = false
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "org.vinegarhq.Sober" then e.juego_auto = true end
    end
    e.presentacion = false
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= "eDP-1" then e.presentacion = true end
    end
    local f = io.open(os.getenv("HOME") .. "/.local/state/concentracion/activo", "r")
    e.reunion = reunion_activa()
    e.concentracion = f ~= nil
    if f then f:close() end
end
local function guardar(r)
    if not archivo then return end
    local f = io.open(archivo .. ".tmp", "w")
    if not f then return end
    for _, k in ipairs({ "perfil", "juego", "privacidad", "bateria", "presentacion", "concentracion", "reunion" }) do
        f:write(k .. "=" .. tostring(e[k] or false) .. "\n")
    end
    f:write("privacidad_activa=" .. tostring(e.privacidad == true or e.reunion == true) .. "\n")
    f:write("juego_activo=" .. tostring(r.juego) .. "\n")
    f:write("no_molestar=" .. tostring(r.no_molestar) .. "\n")
    f:write("pausar_replay=" .. tostring(r.pausar_replay) .. "\n")
    f:close()
    os.rename(archivo .. ".tmp", archivo)
end
function M.sincronizar()
    local r = motor.resolver(e)
    hl.config(r.config)
    guardar(r)
    hl.exec_cmd("qs ipc call notificaciones automatico " .. (r.no_molestar and "true" or "false"))
    hl.exec_cmd("~/.config/hypr/scripts/replay.sh reconciliar")
    hl.exec_cmd("qs ipc call barra refrescar modo-juego")
end
function M.perfil(nombre)
    if not motor.perfiles[nombre] then return end
    e.perfil = nombre
    M.sincronizar()
    hl.exec_cmd("qs ipc call osd mensaje 'Perfil: " .. nombre .. "' f03d8")
end
function M.motivo(nombre, activo)
    if nombre ~= "bateria" and nombre ~= "concentracion" and nombre ~= "presentacion" and nombre ~= "reunion" then return end
    e[nombre] = activo == true
    M.sincronizar()
end
function M.privacidad()
    e.privacidad = not e.privacidad
    M.sincronizar()
    local texto = e.privacidad and "Privacidad manual activada" or e.reunion and "Privacidad mantenida por reunión" or "Privacidad desactivada"
    hl.exec_cmd("qs ipc call osd mensaje '" .. texto .. "' f033e")
end
function M.juego(valor)
    if valor ~= "si" and valor ~= "no" and valor ~= "automatico" then return end
    e.juego = valor
    M.sincronizar()
end
function M.alternar_juego()
    M.juego(motor.resolver(e).juego and "no" or "si")
end
function M.juego_activo() return motor.resolver(e).juego end
function M.ventanas_cambiaron(excluida)
    e.juego_auto = false
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= excluida and w.class == "org.vinegarhq.Sober" then e.juego_auto = true end
    end
    M.sincronizar()
end
leer()
detectar()
_G.escritorio = M
hl.bind(p.mainMod .. " + CTRL + SPACE", hl.dsp.exec_cmd("~/.config/hypr/scripts/escritorio.py menu"))
-- Brújula: hoy, línea de tiempo, contexto automático y sesión anterior (scripts/brujula.py)
hl.bind(p.mainMod .. " + CTRL + B", hl.dsp.exec_cmd("qs ipc call brujula toggle"))
hl.bind(p.mainMod .. " + CTRL + P", M.privacidad)
hl.bind(p.mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd("qs ipc call mesa abrir ventanas"))
hl.bind(p.mainMod .. " + CTRL + V", hl.dsp.exec_cmd("qs ipc call mesa abrir plantillas"))
hl.bind(p.mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("~/.config/hypr/scripts/flujo.py abrir continuidad"))
hl.bind(p.mainMod .. " + CTRL + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/flujo.py abrir organizar"))
hl.bind(p.mainMod .. " + ALT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/flujo.py abrir seleccion"))
-- Una vez terminados todos los require, los módulos ya han comunicado batería y concentración.
hl.timer(M.sincronizar, { timeout = 250, type = "oneshot" })
hl.timer(function()
    local activa = reunion_activa()
    if e.reunion ~= activa then M.motivo("reunion", activa) end
end, { timeout = 5000, type = "repeat" })
return M
