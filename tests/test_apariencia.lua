-- apariencia.lua y colores.lua fuera del compositor: un «hl» falso que guarda lo que se configura.
package.path = './hypr/.config/hypr/?.lua;' .. package.path
local llamadas = {}
_G.hl = {
    config = function(t) llamadas[#llamadas + 1] = t end,
    workspace_rule = function() end,
    window_rule = function() end,
}
require('modulos.apariencia')
assert(type(_G.colores_tema) == 'function', 'falta colores_tema para tema.sh')

local function buscar(ruta)
    for i = #llamadas, 1, -1 do
        local v = llamadas[i]
        for _, k in ipairs(ruta) do v = type(v) == 'table' and v[k] or nil end
        if v ~= nil then return v end
    end
end
local borde = buscar({ 'general', 'col', 'active_border' })
assert(type(borde) == 'string' and borde:match('^rgba%(%x%x%x%x%x%x%x%x%)$'), 'borde activo: ' .. tostring(borde))
assert(buscar({ 'decoration', 'shadow', 'color' }):match('^rgba%('), 'sombra sin color')
assert(buscar({ 'general', 'border_size' }) == 2)

-- En caliente: solo colores, nada de tamaños ni efectos
local antes = #llamadas
_G.colores_tema()
assert(#llamadas == antes + 1, 'colores_tema debe hacer una sola llamada a hl.config')
local t = llamadas[#llamadas]
assert(t.general.border_size == nil and t.decoration.blur == nil, 'colores_tema toca algo más que colores')

-- Nombres antiguos en el archivo de estado se traducen
local c = require('modulos.colores')
for _, n in ipairs({ 'acento', 'acento2', 'exito', 'aviso', 'peligro', 'fondo', 'texto', 'seleccion', 'gris' }) do
    assert(type(c[n]) == 'string' and #c[n] == 6, 'color sin definir: ' .. n)
end
print('apariencia: ok')
