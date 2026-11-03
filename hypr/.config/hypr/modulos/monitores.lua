-- Monitores: https://wiki.hypr.land/configuring/core/monitors/
-- "preferred" = la resolución nativa; "auto" = posición y escala automáticas.
-- Para un segundo monitor, añadir otro hl.monitor con output = "HDMI-A-1" (ver: hyprctl monitors)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
