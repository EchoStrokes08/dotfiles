-- Sesiones de trabajo: un atajo monta un contexto entero (cada app en su workspace).
--   SUPER+ALT+Return  menú de sesiones (también en el lanzador: «sesión …»)
-- Lo que YA está abierto no se abre otra vez (se mira por "clase"), así que puedes lanzar la
-- misma sesión dos veces sin llenarte de ventanas duplicadas.
--
-- PERSONALIZAR: desde Mesa (SUPER+CTRL+V → Rutinas → «Apps»), o editando la tabla SESIONES
-- (son las apps de serie; lo elegido en Mesa tiene prioridad). Cada app es { ws = workspace, clase = "class de la ventana"
-- (hyprctl clients, o SUPER+I), cmd = "comando", nombre = "opcional, para Mesa" }. `icono` es un glifo de Nerd Font (código hex).
-- Firefox abre varias pestañas si le pasas varias direcciones.
--
-- Desde fuera:  hyprctl dispatch 'sesion.abrir("universidad") or hl.dsp.no_op()'
local p = require("modulos.programas")

local SESIONES = {
    {
        id = "universidad", nombre = "Universidad", icono = 0xF0474, ir_a = 3,
        apps = {
            { ws = 2, clase = "firefox",       cmd = "firefox https://www.coursera.org https://classroom.google.com" },
            { ws = 3, clase = "PacketTracer",  nombre = "Packet Tracer", cmd = "/usr/lib/packettracer/packettracer.AppImage" },
            { ws = 4, clase = "sesion-notas",  nombre = "Notas (nvim)", cmd = p.terminal .. " --class sesion-notas -e nvim ~/Documents/notas.md" },
        },
    },
    {
        id = "programar", nombre = "Programar", icono = 0xF0169, ir_a = 3,
        apps = {
            { ws = 1, clase = "sesion-dotfiles", nombre = "Terminal en dotfiles", cmd = p.terminal .. " --class sesion-dotfiles --directory ~/dotfiles" },
            { ws = 2, clase = "firefox",         cmd = "firefox" },
            { ws = 3, clase = "code-oss",        cmd = "code" },
        },
    },
    {
        id = "descanso", nombre = "Descanso", icono = 0xF075A, ir_a = 2,
        apps = {
            { ws = 2, clase = "firefox", cmd = "firefox https://www.youtube.com" },
            { ws = 9, clase = "vesktop", cmd = "vesktop" },
        },
    },
}

-- Apps elegidas desde Mesa → Rutinas (sustituyen a las de la tabla). Una línea por app:
--   ws <TAB> clase <TAB> nombre <TAB> comando
local DIR = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/mesa-trabajo/sesiones/"

local function elegidas(id)
    local f = io.open(DIR .. id .. ".tsv", "r")
    if not f then return nil end
    local apps = {}
    for linea in f:lines() do
        local ws, clase, _, cmd = linea:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(.+)$")
        ws = tonumber(ws)
        if ws and ws >= 1 and ws <= 10 and cmd then apps[#apps + 1] = { ws = ws, clase = clase, cmd = cmd } end
    end
    f:close()
    return apps
end

local function apps_de(s) return elegidas(s.id) or s.apps end

-- Mesa pide las apps de serie para enseñarlas (y poder restaurarlas): <id>.base.tsv
local function exportar()
    for _, s in ipairs(SESIONES) do
        local f = io.open(DIR .. s.id .. ".base.tsv", "w")
        if not f then return end
        for _, a in ipairs(s.apps) do f:write(a.ws, "\t", a.clase, "\t", a.nombre or a.clase, "\t", a.cmd, "\n") end
        f:close()
    end
end

local function abierta(clase)
    for _, w in ipairs(hl.get_windows()) do
        if w.class and w.class:lower():find(clase:lower(), 1, true) then return true end
    end
    return false
end

local function abrir(id)
    for _, s in ipairs(SESIONES) do
        if s.id == id then
            local nuevas = 0
            for _, a in ipairs(apps_de(s)) do
                if a.clase == "" or not abierta(a.clase) then
                    hl.exec_cmd(a.cmd, { workspace = tostring(a.ws) })
                    nuevas = nuevas + 1
                end
            end
            if s.ir_a then hl.dispatch(hl.dsp.focus({ workspace = s.ir_a })) end
            local texto = nuevas == 0 and (s.nombre .. ": ya estaba todo abierto") or ("Sesión: " .. s.nombre)
            hl.exec_cmd("qs ipc call osd mensaje '" .. texto .. "' f0e1b")
            return
        end
    end
end

-- Menú de Quickshell con las sesiones de la tabla (así no hay que repetirlas en el QML)
local function menu()
    local ops = {}
    for _, s in ipairs(SESIONES) do
        local apps = {}
        for _, a in ipairs(apps_de(s)) do apps[#apps + 1] = tostring(a.ws) end
        -- en el comando no puede haber comillas simples (el JSON va entre ellas): [[…]] son las comillas largas de Lua
        ops[#ops + 1] = string.format(
            [=[{"icono":%d,"texto":"%s  ·  ws %s","cmd":"hyprctl dispatch \"sesion.abrir([[%s]]) or hl.dsp.no_op()\""}]=],
            s.icono, s.nombre, table.concat(apps, " "), s.id)
    end
    hl.exec_cmd("~/.config/hypr/scripts/menu.sh 'Sesiones de trabajo' '[" .. table.concat(ops, ",") .. "]'")
end

_G.sesion = { abrir = abrir, menu = menu, exportar = exportar }

hl.bind(p.mainMod .. " + ALT + Return", menu)
