-- Sesiones de trabajo: un atajo monta un contexto entero (cada app en su workspace).
--   SUPER+ALT+Return  menú de sesiones (también en el lanzador: «sesión …»)
-- Lo que YA está abierto no se abre otra vez (se mira por "clase"), así que puedes lanzar la
-- misma sesión dos veces sin llenarte de ventanas duplicadas.
--
-- PERSONALIZAR: edita la tabla SESIONES. Cada app es { ws = workspace, clase = "class de la ventana"
-- (hyprctl clients, o SUPER+I), cmd = "comando" }. `icono` es un glifo de Nerd Font (código hex).
-- Firefox abre varias pestañas si le pasas varias direcciones.
--
-- Desde fuera:  hyprctl dispatch 'sesion.abrir("universidad") or hl.dsp.no_op()'
local p = require("modulos.programas")

local SESIONES = {
    {
        id = "universidad", nombre = "Universidad", icono = 0xF0474, ir_a = 3,
        apps = {
            { ws = 2, clase = "firefox",       cmd = "firefox https://www.coursera.org https://classroom.google.com" },
            { ws = 3, clase = "PacketTracer",  cmd = "/usr/lib/packettracer/packettracer.AppImage" },
            { ws = 4, clase = "sesion-notas",  cmd = p.terminal .. " --class sesion-notas -e nvim ~/Documents/notas.md" },
        },
    },
    {
        id = "programar", nombre = "Programar", icono = 0xF0169, ir_a = 3,
        apps = {
            { ws = 1, clase = "sesion-dotfiles", cmd = p.terminal .. " --class sesion-dotfiles --directory ~/dotfiles" },
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
            for _, a in ipairs(s.apps) do
                if not abierta(a.clase) then
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
        for _, a in ipairs(s.apps) do apps[#apps + 1] = tostring(a.ws) end
        -- en el comando no puede haber comillas simples (el JSON va entre ellas): [[…]] son las comillas largas de Lua
        ops[#ops + 1] = string.format(
            [=[{"icono":%d,"texto":"%s  ·  ws %s","cmd":"hyprctl dispatch \"sesion.abrir([[%s]]) or hl.dsp.no_op()\""}]=],
            s.icono, s.nombre, table.concat(apps, " "), s.id)
    end
    hl.exec_cmd("~/.config/hypr/scripts/menu.sh 'Sesiones de trabajo' '[" .. table.concat(ops, ",") .. "]'")
end

_G.sesion = { abrir = abrir, menu = menu }

hl.bind(p.mainMod .. " + ALT + Return", menu)
