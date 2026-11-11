package.path = './hypr/.config/hypr/?.lua;' .. package.path
local motor = require('modulos.politicas')
local casos = 0
for perfil in pairs(motor.perfiles) do
    for _, juego in ipairs({'si', 'no', 'automatico'}) do
        for mascara = 0, 63 do
            local e = {perfil=perfil, juego=juego, juego_auto=mascara & 1 ~= 0,
                bateria=mascara & 2 ~= 0, presentacion=mascara & 4 ~= 0,
                concentracion=mascara & 8 ~= 0, privacidad=mascara & 16 ~= 0, reunion=mascara & 32 ~= 0}
            local r = motor.resolver(e)
            local g = juego == 'si' or (juego == 'automatico' and e.juego_auto)
            assert(r.juego == g)
            assert(r.no_molestar == (g or e.presentacion or e.concentracion or e.privacidad or e.reunion))
            assert(r.pausar_replay == (e.bateria or e.privacidad or perfil == 'minimo' or e.reunion))
            if e.bateria or g or perfil == 'minimo' or perfil == 'rendimiento' then
                assert(not r.config.decoration.blur.enabled)
                assert(not r.config.decoration.shadow.enabled)
            end
            if g then
                assert(not r.config.animations.enabled)
                assert(r.config.decoration.active_opacity == 1)
                assert(r.config.general.gaps_out == 0)
            end
            casos = casos + 1
        end
    end
end
assert(motor.base.decoration.blur.enabled, 'El resolver mutó la configuración base')
assert(motor.resolver({perfil='cristal', juego='no'}).config.animations.enabled)
assert(motor.resolver({perfil='desconocido'}).config.decoration.active_opacity == 0.8)
-- Salir de juego no debe cancelar presentación ni ahorro por batería.
local r = motor.resolver({perfil='lectura', juego='no', presentacion=true, bateria=true})
assert(r.no_molestar and not r.config.decoration.blur.enabled)
print(casos .. ' combinaciones de política correctas')
