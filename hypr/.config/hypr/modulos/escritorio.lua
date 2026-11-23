-- Coordinador de perfiles y motivos. Estado por instancia: sobrevive a reload, no a otro login.
local motor = require("modulos.politicas")
local p = require("modulos.programas")
local M = {}
local e = { perfil = "cristal", juego = "automatico", privacidad = false }
local runtime = os.getenv("XDG_RUNTIME_DIR")
local firma = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""):gsub("[^%w_%-]", "")
local archivo = runtime and (runtime .. "/hypr-escritorio-" .. firma .. ".state")
local ventanas_juego = {}
local function es_juego(w)
    if motor.es_juego(w.class) then return true end
    local pid = tonumber(w.pid)
    if not pid or pid <= 0 or pid % 1 ~= 0 then return false end
    local f = io.open("/proc/" .. string.format("%.0f", pid) .. "/environ", "rb")
    if not f then return false end
    local entorno = f:read("a")
    f:close()
    return motor.es_juego(w.class, entorno)
end
local function detectar_juegos(excluida)
    e.juego_auto = false
    ventanas_juego = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.address ~= excluida and es_juego(w) then
            e.juego_auto = true
            ventanas_juego[#ventanas_juego + 1] = tostring(w.address)
        end
    end
end
local function leer()
    local f = archivo and io.open(archivo, "r")
    if not f then return end
    for linea in f:lines() do
        local k, v = linea:match("^([%w_]+)=([%w_%-]+)$")
        if k == "perfil" and motor.perfiles[v] then e.perfil = v end
        if k == "juego" and (v == "si" or v == "no" or v == "automatico") then e.juego = v end
        if k == "privacidad" then e.privacidad = v == "true" end
        if k == "juego_espacio_manual" then e.juego_espacio_manual = tonumber(v) end
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
    detectar_juegos()
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
    f:write("juego_ventanas=" .. table.concat(ventanas_juego, ",") .. "\n")
    f:write("juego_espacio_manual=" .. tostring(e.juego == "si" and e.juego_espacio_manual or "") .. "\n")
    f:write("no_molestar=" .. tostring(r.no_molestar) .. "\n")
    f:close()
    os.rename(archivo .. ".tmp", archivo)
end
local perfil_kitty = nil
local privacidad_anterior = nil
local juego_anterior = nil
function M.sincronizar()
    local r = motor.resolver(e)
    hl.config(r.config)
    guardar(r)
    if perfil_kitty ~= e.perfil then
        perfil_kitty = e.perfil
        hl.exec_cmd('pkill -USR1 -x -u "$USER" kitty')
    end
    if r.juego ~= juego_anterior then
        juego_anterior = r.juego
        hl.exec_cmd("~/.config/hypr/scripts/juego-energia.sh " .. (r.juego and "inicio" or "fin") .. " escritorio")
    end
    hl.exec_cmd("qs ipc call notificaciones automatico " .. (r.no_molestar and "true" or "false"))
    -- La privacidad (también la de una reunión) pausa el replay y lo devuelve al terminar.
    -- Solo al cambiar: sincronizar también corre en cada cambio de ventanas.
    local privado = e.privacidad == true or e.reunion == true
    if privado ~= privacidad_anterior then
        privacidad_anterior = privado
        hl.exec_cmd("~/.config/hypr/scripts/replay.sh reconciliar")
    end
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
    local ws = valor == "si" and hl.get_active_workspace() or nil
    e.juego_espacio_manual = ws and ws.id or nil
    e.juego = valor
    M.sincronizar()
end
function M.alternar_juego()
    M.juego(motor.resolver(e).juego and "no" or "si")
end
function M.juego_activo() return motor.resolver(e).juego end
function M.ventanas_cambiaron(excluida)
    detectar_juegos(excluida)
    M.sincronizar()
end
leer()
detectar()
_G.escritorio = M
-- Agente: le hablas al escritorio (SUPER+O = «oye»)
hl.bind(p.mainMod .. " + O", hl.dsp.exec_cmd("qs ipc call agente toggle"))
-- Reabrir la última ventana cerrada, en su espacio y (si flotaba) con su tamaño y posición
hl.bind(p.mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/brujula.py reabrir"))
hl.bind(p.mainMod .. " + CTRL + P", M.privacidad)
hl.bind(p.mainMod .. " + CTRL + V", hl.dsp.exec_cmd("qs ipc call lanzador buscar 'pl '"))       -- plantillas, en el lanzador
hl.bind(p.mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("qs ipc call lanzador buscar proyecto"))  -- proyectos, en el lanzador
hl.bind(p.mainMod .. " + CTRL + O", hl.dsp.exec_cmd("~/.config/hypr/scripts/flujo.py abrir organizar"))
hl.bind(p.mainMod .. " + ALT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/flujo.py abrir seleccion"))
-- Una vez terminados todos los require, los módulos ya han comunicado batería y concentración.
hl.timer(M.sincronizar, { timeout = 250, type = "oneshot" })
hl.timer(function()
    local activa = reunion_activa()
    if e.reunion ~= activa then M.motivo("reunion", activa) end
end, { timeout = 5000, type = "repeat" })
return M
