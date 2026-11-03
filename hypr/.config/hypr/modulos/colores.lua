-- Paleta de Hyprland. NO edites los colores aquí:
--   · la paleta activa la escribe ~/.config/hypr/scripts/tema.sh en ~/.local/state/tema/hyprland.lua
--   · los colores Ayu originales están en ~/.config/tema/ayu/hyprland.lua
-- Uso en otro módulo:  local c = require("modulos.colores")
--                      c.rgba("naranja", "ee")  ->  "rgba(f19618ee)"

-- Ayu de respaldo, por si todavía no existe la paleta activa
local M = {
    fondo = "0e1419", texto = "e5e1cf", naranja = "f19618", amarillo = "e6c446", azul = "36a3d9",
    verde = "b8cc52", rojo = "ff3333", seleccion = "243340", gris = "5c6773",
}

local activa = os.getenv("HOME") .. "/.local/state/tema/hyprland.lua"
local ok, paleta = pcall(dofile, activa)
if ok and type(paleta) == "table" then
    for nombre, hex in pairs(paleta) do M[nombre] = hex end
end

-- Arma "rgba(RRGGBBAA)". alpha en hex: "ff" = opaco, "00" = invisible
function M.rgba(nombre, alpha)
    return "rgba(" .. M[nombre] .. (alpha or "ff") .. ")"
end

return M
