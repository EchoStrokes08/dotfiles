-- Programas y tecla principal que usan los demás módulos.
-- Cambiar aquí el terminal o el lanzador lo cambia en TODOS los atajos.
return {
    mainMod     = "SUPER",   -- tecla "Windows"
    terminal    = "kitty",
    fileManager = "thunar",
    menu        = "qs ipc call lanzador toggle",   -- lanzador propio (Quickshell); antes: "fuzzel"
    whatsapp    = "gtk-launch com.rtosta.zapzap",
    roblox      = "gamemoderun flatpak run org.vinegarhq.Sober",
    spotify     = "flatpak run com.spotify.Client",
    opera       = os.getenv("HOME") .. "/.config/hypr/scripts/opera-gx.py",   -- Opera GX con el mod ORION (paleta y wallpaper)
    nebula      = os.getenv("HOME") .. "/.local/opt/nebula/app/AppRun",   -- AppImage extraído (sin FUSE: no bloquea la suspensión; ver scripts/nebula-extraer.sh)
}
