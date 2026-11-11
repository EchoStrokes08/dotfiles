-- Autostart: https://wiki.hypr.land/configuring/core/autostart/
-- "hyprland.start" ocurre UNA vez al iniciar sesión (no al recargar la config).
local p = require("modulos.programas")

hl.on("hyprland.start", function()
    -- Apps
    hl.exec_cmd(p.terminal)
    hl.exec_cmd("firefox")

    -- Escritorio
    -- hl.exec_cmd("waybar")   -- sustituida por la barra de Quickshell (para volver: quitar el -- y matar qs)
    hl.exec_cmd("awww-daemon")      -- fondo de pantalla con transiciones (antes hyprpaper, que queda de respaldo)
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper.sh restaurar")   -- vuelve a poner el último wallpaper elegido
    hl.exec_cmd("~/.config/hypr/scripts/tiempo-pantalla.py")   -- escucha eventos: tiempo de pantalla por app
    hl.exec_cmd("qs")               -- Quickshell: barra superior + dashboard SUPER+D (~/.config/quickshell)
    -- hl.exec_cmd("swayosd-server")   -- sustituido por el OSD de Quickshell (OSD.qml)
    hl.exec_cmd("hyprsunset")   -- luz nocturna: horario en ~/.config/hypr/hyprsunset.conf
    hl.exec_cmd("hypridle")   -- escucha "lock-session" y bloquea por inactividad
    -- (las notificaciones las sirve Quickshell; swaync está enmascarado: systemctl --user mask swaync)

    -- Servicios
    hl.exec_cmd("wl-paste --type text --watch cliphist store")    -- historial del portapapeles
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")        -- ventana de contraseña de admin
    hl.exec_cmd("systembus-notify")                               -- pasa a notificaciones los avisos del sistema (earlyoom)
    hl.exec_cmd("kdeconnect-indicator")                           -- KDE Connect: móvil (icono en la bandeja)
    hl.exec_cmd("~/.config/hypr/scripts/sonido.sh restaurar")    -- EasyEffects: último perfil de sonido de las bocinas
    hl.exec_cmd("~/.config/hypr/scripts/lugar.sh vigilar")       -- reglas por lugar: al cambiar de Wi-Fi (~/.config/lugares.conf)
    hl.exec_cmd("udiskie")                                        -- monta USB solos y avisa (~/.config/udiskie)
    hl.exec_cmd("~/.config/hypr/scripts/replay.sh reconciliar")        -- replay de 30 s en RAM
end)
