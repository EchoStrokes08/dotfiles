package.path = './hypr/.config/hypr/?.lua;' .. package.path
local motor = require('modulos.politicas')
assert(motor.es_juego('JuegoLinux', 'SteamAppId=1243830\0OTRA=1\0'))
assert(motor.es_juego('JuegoLinux', 'OTRA=1\0SteamAppId=322170\0'))
assert(not motor.es_juego('steam', 'SteamAppId=0\0'))
assert(not motor.es_juego('navegador', 'OTRA_SteamAppId=322170\0'))
assert(not motor.es_juego('navegador', nil))
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
            if e.bateria or g or perfil == 'minimo' or perfil == 'rendimiento' then
                assert(not r.config.decoration.blur.enabled)
                assert(not r.config.decoration.shadow.enabled)
            end
            if g then
                assert(not r.config.animations.enabled)
                assert(r.config.decoration.active_opacity == 1)
                assert(r.config.general.gaps_out == 0)
                assert(not r.config.cursor.hide_on_key_press and r.config.cursor.inactive_timeout == 0)
            else
                assert(r.config.cursor.hide_on_key_press and r.config.cursor.inactive_timeout == 5)
            end
            casos = casos + 1
        end
    end
end
assert(motor.base.decoration.blur.enabled, 'El resolver mutó la configuración base')
assert(motor.resolver({perfil='cristal', juego='no'}).config.animations.enabled)
-- Un perfil desconocido cae en cristal; las ventanas son opacas en todos los perfiles.
assert(motor.resolver({perfil='desconocido'}).config.decoration.blur.enabled)
for perfil in pairs(motor.perfiles) do
    local d = motor.resolver({perfil=perfil, juego='no'}).config.decoration
    assert(d.active_opacity == 1 and d.inactive_opacity == 1, 'ventanas translúcidas en ' .. perfil)
end
-- Salir de juego no debe cancelar presentación ni ahorro por batería.
local r = motor.resolver({perfil='lectura', juego='no', presentacion=true, bateria=true})
assert(r.no_molestar and not r.config.decoration.blur.enabled)
-- Modo juego automático: Sober y juegos de Steam (Proton), no el cliente de Steam ni otras apps.
assert(motor.es_juego('org.vinegarhq.Sober'))
assert(motor.es_juego('steam_app_728880') and motor.es_juego('steam_app_322170') and motor.es_juego('gamescope'))
assert(not motor.es_juego('steam') and not motor.es_juego('steam_app_') and not motor.es_juego('xsteam_app_1'))
assert(not motor.es_juego(nil) and not motor.es_juego('kitty'))
-- Wine y Heroic (Epic/GOG)
assert(motor.es_juego('Game.EXE') and motor.es_juego('witcher3.exe') and motor.es_juego('steam_app_default'))
assert(not motor.es_juego('.exe') and not motor.es_juego('exe') and not motor.es_juego('heroic'))
assert(motor.es_juego('heroic', 'OTRA=1\0HEROIC_APP_NAME=Fortnite\0'))
assert(not motor.es_juego('heroic', 'HEROIC_APP_NAME=\0') and not motor.es_juego('x', 'XHEROIC_APP_NAME=a\0'))
print(casos .. ' combinaciones de política correctas')
-- Modo zen: con concentración se atenúan las ventanas inactivas; sin ella (o jugando), no
assert(motor.resolver({perfil='cristal', concentracion=true}).config.decoration.dim_inactive, 'Concentración sin atenuar')
assert(not motor.resolver({perfil='cristal'}).config.decoration.dim_inactive, 'Atenuado sin concentración')
assert(not motor.resolver({perfil='cristal', concentracion=true, juego='si'}).config.decoration.dim_inactive, 'Atenuado jugando')
assert(not motor.base.decoration.dim_inactive, 'El resolver mutó dim_inactive de la base')
