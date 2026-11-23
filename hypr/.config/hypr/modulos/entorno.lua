-- Variables de entorno: https://wiki.hypr.land/configuring/core/environment-variables/
-- Se leen al arrancar las apps: los cambios solo afectan a lo que se abra después
-- (algunas, como el cursor, piden cerrar sesión).

-- Cursor Bibata neutro (blanco): no depende de la paleta, que puede venir del wallpaper
hl.env("XCURSOR_SIZE",     "24")
hl.env("HYPRCURSOR_SIZE",  "24")
hl.env("XCURSOR_THEME",    "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")

-- Apps Qt: que usen el tema GTK (colores oscuros) en vez del suyo por defecto
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-- Apps de flatpak (WhatsApp/zapzap, Roblox/Sober) en el menú de fuzzel
hl.env("XDG_DATA_DIRS", "/usr/local/share:/usr/share:/var/lib/flatpak/exports/share:" .. os.getenv("HOME") .. "/.local/share/flatpak/exports/share")

-- Mismo mapa de respaldo para clientes Wayland arrancados por el compositor.
hl.env("XKB_DEFAULT_LAYOUT", "latam")

-- Textos de las apps en español (Thunar, GTK, Qt…). Solo LC_MESSAGES: LANG sigue en C.UTF-8 para que
-- números, fechas y la salida de los scripts no cambien. Los servicios de systemd/D-Bus lo toman de
-- ~/.config/environment.d/81-idioma.conf. Ojo: nmcli traduce «yes» → «sí»; quien lo lea, con LC_ALL=C.
hl.env("LC_MESSAGES", "es_MX.UTF-8")
hl.env("LANGUAGE",    "es_MX:es")
