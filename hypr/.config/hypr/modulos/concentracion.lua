-- Modo concentración: esconde las apps que distraen mientras dura una sesión.
-- Aquí solo se mueven las ventanas; el temporizador, el menú (SUPER+SHIFT+F), la cuenta atrás de
-- la barra y "No molestar" son de Quickshell (~/.config/quickshell/Concentracion.qml).
--
-- El estado vive en archivos (~/.local/state/concentracion/): así sobrevive a "hyprctl reload",
-- que reinicia todo el Lua (lo hacen el modo juego y tema.sh).
--   hyprctl dispatch 'concentracion.empezar() or hl.dsp.no_op()'
--   hyprctl dispatch 'concentracion.terminar() or hl.dsp.no_op()'

-- Apps que distraen (su class; se ve con SUPER+I). Spotify no está: la música ayuda a concentrarse.
local DISTRAEN = {
    ["com.rtosta.zapzap"]   = true,   -- WhatsApp
    ["discord"]             = true,
    ["vesktop"]             = true,
    ["org.vinegarhq.Sober"] = true,   -- Roblox
    ["steam"]               = true,
}

local ESCONDITE = "special:concentracion"
local DIR       = os.getenv("HOME") .. "/.local/state/concentracion"
local ACTIVO    = DIR .. "/activo"     -- existe = sesión en marcha
local ORIGEN    = DIR .. "/origen"     -- una línea por ventana escondida: "dirección workspace"

local function activo()
    local f = io.open(ACTIVO)
    if f then f:close() return true end
    return false
end

-- Mover SIN seguir a la ventana: follow = false (si no, Hyprland te llevaría al escondite)
local function mover(w, destino)
    hl.dispatch(hl.dsp.window.move({ workspace = destino, window = w, follow = false }))
end

local function esconder(w)
    if not (w and DISTRAEN[w.class]) then return end
    if w.workspace and w.workspace.name == ESCONDITE then return end
    local f = io.open(ORIGEN, "a")
    if f then
        f:write(w.address .. " " .. tostring(w.workspace and w.workspace.id or 1) .. "\n")
        f:close()
    end
    mover(w, ESCONDITE)
end

local function empezar()
    if activo() then return end
    os.execute("mkdir -p '" .. DIR .. "'")
    io.open(ACTIVO, "w"):close()
    for _, w in ipairs(hl.get_windows()) do esconder(w) end
    require("modulos.escritorio").motivo("concentracion", true)
end

local function terminar()
    -- leer de dónde venía cada ventana
    local origen = {}
    local f = io.open(ORIGEN)
    if f then
        for linea in f:lines() do
            local dir, ws = linea:match("^(%S+)%s+(%S+)$")
            if dir then origen[dir] = tonumber(ws) or ws end
        end
        f:close()
    end
    require("modulos.escritorio").motivo("concentracion", false)
    os.remove(ACTIVO)
    os.remove(ORIGEN)
    -- devolver cada una a su workspace (si se abrió durante la sesión, al 1)
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.name == ESCONDITE then
            mover(w, origen[w.address] or 1)
        end
    end
end

-- Si abres una app que distrae durante la sesión, se esconde sola
hl.on("window.open", function(w)
    if activo() then esconder(w) end
end)

-- Global: Quickshell la llama con hyprctl dispatch
_G.concentracion = { empezar = empezar, terminar = terminar, activo = activo }
