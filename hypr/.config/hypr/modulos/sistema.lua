-- Opciones varias del compositor
hl.config({
    misc = {
        force_default_wallpaper    = 0,     -- sin fondos de la mascota
        disable_hyprland_logo      = true,
        vrr                        = 2,     -- VRR solo en pantalla completa (si el monitor lo soporta)
        allow_session_lock_restore = true,  -- si hyprlock se cae, se puede relanzar sin perder la sesión
    },
    layers = {
        -- capas nuevas (notificaciones, menús) se dibujan encima de una ventana a pantalla completa
        allow_new_top_layers_over_existing_fullscreen = true,
    },
})

-- Permisos (requieren reiniciar Hyprland): https://wiki.hypr.land/configuring/core/advanced-configuration/permissions/
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
