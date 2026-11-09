-- Autostart: https://wiki.hypr.land/configuring/core/autostart/
-- "hyprland.start" ocurre UNA vez al iniciar sesión (no al recargar la config).
local p = require("modulos.programas")

hl.on("hyprland.start", function()
    -- Apps
    hl.exec_cmd(p.terminal)
    hl.exec_cmd("firefox")

    -- Escritorio
    -- hl.exec_cmd("waybar")   -- sustituida por la barra de Quickshell (para volver: quitar el -- y matar qs)
    hl.exec_cmd("hyprpaper")
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
    hl.exec_cmd("udiskie")                                        -- monta USB solos y avisa (~/.config/udiskie)
    hl.exec_cmd("~/.config/hypr/scripts/replay.sh start")        -- replay de 30 s en RAM
end)
