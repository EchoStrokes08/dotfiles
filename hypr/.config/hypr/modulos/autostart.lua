-- Autostart: https://wiki.hypr.land/configuring/core/autostart/
-- "hyprland.start" ocurre UNA vez al iniciar sesión (no al recargar la config).
local p = require("modulos.programas")

hl.on("hyprland.start", function()
    -- Apps
    hl.exec_cmd(p.terminal)
    hl.exec_cmd("firefox")

    -- Escritorio
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")   -- escucha "lock-session" y bloquea por inactividad
    -- (swaync no hace falta: lo arranca systemd/D-Bus al llegar la primera notificación)

    -- Servicios
    hl.exec_cmd("wl-paste --type text --watch cliphist store")    -- historial del portapapeles
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")        -- ventana de contraseña de admin
    hl.exec_cmd("~/.config/hypr/scripts/replay.sh start")        -- replay de 30 s en RAM
end)
