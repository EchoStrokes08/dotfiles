-- Paleta Ayu Dark: ÚNICO lugar donde se definen los colores de Hyprland.
-- Los mismos de ~/.config/waybar/ayu.css, kitty, swaync y GTK.
-- Uso en otro módulo:  local c = require("modulos.colores")
--                      c.rgba("naranja", "ee")  ->  "rgba(f19618ee)"
local M = {
    fondo     = "0e1419",  -- background
    texto     = "e5e1cf",  -- foreground
    naranja   = "f19618",  -- el color estrella de Ayu
    amarillo  = "e6c446",
    azul      = "36a3d9",
    verde     = "b8cc52",
    rojo      = "ff3333",
    seleccion = "243340",  -- selection_background
    gris      = "5c6773",
}

-- Arma "rgba(RRGGBBAA)". alpha en hex: "ff" = opaco, "00" = invisible
function M.rgba(nombre, alpha)
    return "rgba(" .. M[nombre] .. (alpha or "ff") .. ")"
end

return M
