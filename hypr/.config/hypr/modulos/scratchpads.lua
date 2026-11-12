-- Scratchpads con nombre (Nivel 6, paso 5)
-- Un scratchpad es un workspace especial que aparece encima de lo que estés haciendo y se esconde con la misma tecla.
-- La primera vez la app se abre sola (evento workspace.created). Si la app ya estaba abierta en otro sitio,
-- se la trae al scratchpad en vez de abrir otra copia.
--
--   SUPER+Return  terminal flotante
--   SUPER+Y       música (Spotify)
--   SUPER+CTRL+SHIFT+O notas (nvim en ~/Documents/notas.md)
--   SUPER+SHIFT+E archivos (yazi; SUPER+E sigue abriendo Thunar)
--   SUPER+S       "magic" (el de siempre, para lo que quieras: SUPER+SHIFT+S manda la ventana)
local p   = require("modulos.programas")
local mod = p.mainMod

local NOTAS = "~/Documents/notas.md"

local scratchpads = {
    { nombre = "terminal", tecla = "Return", clase = "scratch-terminal",
      comando = p.terminal .. " --class scratch-terminal" },
    { nombre = "musica",   tecla = "Y",      clase = "spotify",
      comando = p.spotify },
    { nombre = "notas",    tecla = "CTRL + SHIFT + O",      clase = "scratch-notas",
      comando = "mkdir -p ~/Documents && " .. p.terminal .. " --class scratch-notas -e nvim " .. NOTAS },
    { nombre = "archivos", tecla = "SHIFT + E", clase = "scratch-archivos",
      comando = p.terminal .. " --class scratch-archivos -e yazi" },
}

for _, s in ipairs(scratchpads) do
    local especial = "special:" .. s.nombre

    hl.bind(mod .. " + " .. s.tecla, function()
        -- ¿La app ya está abierta fuera de su scratchpad? Traerla sin abrir otra
        local w = hl.get_windows({ class = s.clase })[1]
        if w and w.workspace and w.workspace.name ~= especial then
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = especial, follow = false }))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(s.nombre))
    end)
end

-- Al crearse vacío un scratchpad (la primera vez que lo abres) lanza su app dentro.
-- (Sustituye a la regla on_created_empty, obsoleta desde Hyprland 0.57.)
local por_workspace = {}
for _, s in ipairs(scratchpads) do
    por_workspace["special:" .. s.nombre] = s.comando
end

hl.on("workspace.created", function(ws)
    if not (ws and ws.special and ws.is_empty) then return end
    local comando = por_workspace[ws.name] or por_workspace["special:" .. ws.name]
    if comando then
        hl.exec_cmd(comando, { workspace = ws.name })
    end
end)

-- Terminal, notas y archivos: flotantes, centradas y de tamaño cómodo (Spotify se queda en mosaico, ocupando el scratchpad)
hl.window_rule({
    name   = "scratch-flotantes",
    match  = { class = "^scratch-(terminal|notas|archivos)$" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.65)",
    center = true,
})

-- Navegador del agente (agente_navegador.py): trabaja oculto en su scratchpad, sin quitarte el foco.
-- El botón «Navegador» del panel del asistente lo muestra/oculta.
hl.window_rule({ name = "agente-navegador", match = { class = "^agente-navegador$" }, workspace = "special:agente silent" })

-- Música: más margen alrededor para que se note que "flota" sobre el escritorio.
-- Arriba/abajo poco margen: Spotify no baja de ~600 px de alto y con 60 (pantalla 1280×720 lógica
-- menos la barra) se quedaba en 558 y el contenido se salía del borde.
hl.workspace_rule({ workspace = "special:musica", gaps_out = { top = 25, right = 60, bottom = 25, left = 60 } })
