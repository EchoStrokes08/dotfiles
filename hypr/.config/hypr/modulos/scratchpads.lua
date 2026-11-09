-- Scratchpads con nombre (Nivel 6, paso 5)
-- Un scratchpad es un workspace especial que aparece encima de lo que estés haciendo y se esconde con la misma tecla.
-- La primera vez la app se abre sola (on_created_empty). Si la app ya estaba abierta en otro sitio,
-- se la trae al scratchpad en vez de abrir otra copia.
--
--   SUPER+Return  terminal flotante
--   SUPER+Y       música (Spotify)
--   SUPER+O       notas (nvim en ~/Documents/notas.md)
--   SUPER+S       "magic" (el de siempre, para lo que quieras: SUPER+SHIFT+S manda la ventana)
local p   = require("modulos.programas")
local mod = p.mainMod

local NOTAS = "~/Documents/notas.md"

local scratchpads = {
    { nombre = "terminal", tecla = "Return", clase = "scratch-terminal",
      comando = p.terminal .. " --class scratch-terminal" },
    { nombre = "musica",   tecla = "Y",      clase = "spotify",
      comando = p.spotify },
    { nombre = "notas",    tecla = "O",      clase = "scratch-notas",
      comando = "mkdir -p ~/Documents && " .. p.terminal .. " --class scratch-notas -e nvim " .. NOTAS },
}

for _, s in ipairs(scratchpads) do
    local especial = "special:" .. s.nombre

    -- Al crearse vacío (la primera vez que lo abres) lanza su app dentro
    hl.workspace_rule({ workspace = especial, on_created_empty = s.comando })

    hl.bind(mod .. " + " .. s.tecla, function()
        -- ¿La app ya está abierta fuera de su scratchpad? Traerla sin abrir otra
        local w = hl.get_windows({ class = s.clase })[1]
        if w and w.workspace and w.workspace.name ~= especial then
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = especial, follow = false }))
        end
        hl.dispatch(hl.dsp.workspace.toggle_special(s.nombre))
    end)
end

-- Terminal y notas: flotantes, centradas y de tamaño cómodo (Spotify se queda en mosaico, ocupando el scratchpad)
hl.window_rule({
    name   = "scratch-flotantes",
    match  = { class = "^scratch-(terminal|notas)$" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.65)",
    center = true,
})

-- Música: más margen alrededor para que se note que "flota" sobre el escritorio
hl.workspace_rule({ workspace = "special:musica", gaps_out = 60 })
