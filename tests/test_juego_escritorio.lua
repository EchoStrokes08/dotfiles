-- Coordinación del escritorio con los ajustes de energía sin usar la sesión gráfica.
package.path = './hypr/.config/hypr/?.lua;' .. package.path
local getenv = os.getenv
local runtime = os.tmpname()
os.remove(runtime)
assert(os.execute('mkdir ' .. string.format('%q', runtime)))
os.getenv = function(k)
    if k == 'XDG_RUNTIME_DIR' then return runtime end
    if k == 'HYPRLAND_INSTANCE_SIGNATURE' then return 'prueba' end
    return getenv(k)
end
local ventanas, ordenes = {}, {}
package.loaded['modulos.programas'] = { mainMod = 'SUPER' }
hl = {
    get_windows = function() return ventanas end,
    get_active_workspace = function() return { id = 3 } end,
    get_monitors = function() return {{ name = 'eDP-1' }} end,
    config = function() end,
    exec_cmd = function(cmd) ordenes[#ordenes + 1] = cmd end,
    bind = function() end,
    timer = function() end,
    dsp = { exec_cmd = function() return function() end end },
}
local c = require('modulos.escritorio')
local function estado(clave)
    local f = assert(io.open(runtime .. '/hypr-escritorio-prueba.state'))
    local texto = f:read('a')
    f:close()
    return texto:match(clave .. '=([^\n]*)\n')
end
local function contar(texto)
    local n = 0
    for _, cmd in ipairs(ordenes) do
        if cmd:find(texto, 1, true) then n = n + 1 end
    end
    return n
end
c.sincronizar()
assert(contar('fin escritorio') == 1)
ventanas = {{class='steam_app_322170', address='juego1'}}
c.ventanas_cambiaron()
assert(c.juego_activo())
assert(estado('juego_ventanas') == 'juego1')
assert(contar('inicio escritorio') == 1)
ventanas[2] = {class='org.vinegarhq.Sober', address='juego2'}
c.ventanas_cambiaron()
assert(contar('inicio escritorio') == 1, 'no debe reaplicar al abrir otro juego')
assert(estado('juego_ventanas') == 'juego1,juego2')
c.ventanas_cambiaron('juego1')
assert(c.juego_activo(), 'el otro juego sigue abierto')
assert(estado('juego_ventanas') == 'juego2', 'debe quitar solo la ventana cerrada')
ventanas = {{class='org.vinegarhq.Sober', address='juego2'}}
c.ventanas_cambiaron('juego2')
assert(not c.juego_activo())
assert(estado('juego_ventanas') == '')
assert(contar('fin escritorio') == 2)
ventanas = {{class='navegador', address='otra'}}
c.ventanas_cambiaron()
assert(contar('fin escritorio') == 2, 'una ventana normal no reaplica ajustes')
c.juego('si')
assert(c.juego_activo() and contar('inicio escritorio') == 2)
assert(estado('juego_espacio_manual') == '3', 'modo manual solo en su espacio inicial')
c.juego('automatico')
assert(not c.juego_activo() and contar('fin escritorio') == 3)
assert(estado('juego_espacio_manual') == '')
os.remove(runtime .. '/hypr-escritorio-prueba.state')
os.remove(runtime)
print('Modo juego: activación, varios juegos, restauración y control manual correctos')
