-- lua tests/test_sesiones.lua : las apps elegidas en Mesa sustituyen a las de serie
package.path = './hypr/.config/hypr/?.lua;' .. package.path
local dir = os.tmpname(); os.remove(dir)
os.execute('mkdir -p ' .. dir .. '/mesa-trabajo/sesiones')
local getenv = os.getenv
os.getenv = function(k) if k == 'XDG_STATE_HOME' then return dir end return getenv(k) end

local lanzadas, ventanas = {}, { { class = 'kitty' } }
hl = {
    get_windows = function() return ventanas end,
    exec_cmd = function(cmd, reglas) lanzadas[#lanzadas + 1] = { cmd = cmd, ws = reglas and reglas.workspace } end,
    dispatch = function() end, bind = function() end,
    dsp = { focus = function() end },
}
require('modulos.sesiones')
local function abrir(id) lanzadas = {}; sesion.abrir(id); local r = {}; for _, l in ipairs(lanzadas) do if not l.cmd:match('^qs ') then r[#r + 1] = l end end; return r end

-- sin elección: las de serie
assert(#abrir('descanso') == 2)

-- con elección: solo las elegidas, en su espacio; las ya abiertas no se repiten
local f = io.open(dir .. '/mesa-trabajo/sesiones/descanso.tsv', 'w')
f:write('5\tobsidian\tObsidian\tobsidian --flag\n9\tkitty\tKitty\tkitty\nbasura\n11\tx\tx\tx\n')
f:close()
local r = abrir('descanso')
assert(#r == 1 and r[1].cmd == 'obsidian --flag' and r[1].ws == '5', 'elegidas')

-- lista vacía: no abre nada
io.open(dir .. '/mesa-trabajo/sesiones/descanso.tsv', 'w'):close()
assert(#abrir('descanso') == 0)

-- exportar escribe las de serie con su nombre
sesion.exportar()
local base = io.open(dir .. '/mesa-trabajo/sesiones/programar.base.tsv'):read('a')
assert(base:find('1\tsesion-dotfiles\tTerminal en dotfiles\t', 1, true))
os.execute('rm -rf ' .. dir)
print('sesiones: ok')
