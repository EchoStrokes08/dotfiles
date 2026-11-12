-- Variables de entorno: https://wiki.hypr.land/configuring/core/environment-variables/
-- Se leen al arrancar las apps: los cambios solo afectan a lo que se abra después
-- (algunas, como el cursor, piden cerrar sesión).

-- Cursor Bibata naranja (a juego con Ayu) para Hyprland y apps XWayland
hl.env("XCURSOR_SIZE",     "24")
hl.env("HYPRCURSOR_SIZE",  "24")
hl.env("XCURSOR_THEME",    "Bibata-Modern-Amber")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Amber")

-- Apps Qt: que usen el tema GTK (colores oscuros) en vez del suyo por defecto
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Apps de flatpak (WhatsApp/zapzap, Roblox/Sober) en el menú de fuzzel
hl.env("XDG_DATA_DIRS", "/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:" .. os.getenv("HOME") .. "/.local/share/flatpak/exports/share")
