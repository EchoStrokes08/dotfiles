-- Filtros de pantalla (shaders): un programa de GPU que recolorea TODA la pantalla.
--   SUPER+ALT+S  menú de filtros (Quickshell)
--   grises     escala de grises: para leer o concentrarse sin colores que distraigan
--   papel      tono sepia de poco contraste, tipo libro: lectura larga
--   vivo       colores más saturados y con algo más de contraste: juegos y vídeo
--   invertido  invierte la luminosidad sin cambiar los tonos: un PDF blanco pasa a oscuro
-- Los shaders están en ~/.config/hypr/shaders/*.frag (GLSL). El elegido se recuerda en
-- ~/.local/state/hypr/shader y se vuelve a poner al recargar la config o iniciar sesión.
-- No salen en las capturas ni grabaciones: solo cambian lo que ves.
--
-- Desde fuera:  hyprctl dispatch 'shader.poner("grises") or hl.dsp.no_op()'   ("" = quitar)
local p = require("modulos.programas")

local HOME    = os.getenv("HOME")
local CARPETA = HOME .. "/.config/hypr/shaders/"
local ESTADO  = HOME .. "/.local/state/hypr/shader"
local NOMBRES = { grises = "Escala de grises", papel = "Papel (sepia)", vivo = "Colores vivos", invertido = "Invertido" }

local function actual()
    local f = io.open(ESTADO, "r")
    if not f then return "" end
    local v = f:read("l") or ""; f:close()
    return NOMBRES[v] and v or ""
end

local function aplicar(nombre)
    hl.config({ decoration = { screen_shader = NOMBRES[nombre] and (CARPETA .. nombre .. ".frag") or "" } })
end

local function poner(nombre)
    if not NOMBRES[nombre] then nombre = "" end
    aplicar(nombre)
    os.execute("mkdir -p '" .. HOME .. "/.local/state/hypr'")
    local f = io.open(ESTADO, "w")
    if f then f:write(nombre, "\n"); f:close() end
    local texto = nombre == "" and "Filtro de pantalla: ninguno" or ("Filtro: " .. NOMBRES[nombre])
    hl.exec_cmd("qs ipc call osd mensaje '" .. texto .. "' f03d8")
end

_G.shader = { poner = poner, actual = actual }

hl.bind(p.mainMod .. " + ALT + S", hl.dsp.exec_cmd("qs ipc call menu shaders"))

if actual() ~= "" then aplicar(actual()) end
