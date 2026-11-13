-- Paleta de Hyprland. NO edites los colores aquí:
--   · la paleta activa la escribe ~/.config/hypr/scripts/tema.sh en ~/.local/state/tema/hyprland.lua
--   · los colores Ayu originales están en ~/.config/tema/ayu/hyprland.lua
-- Nombres por función (como Paleta.qml): acento, acento2, exito, aviso, peligro + neutros.
-- Uso en otro módulo:  local c = require("modulos.colores")
--                      c.rgba("acento", "ee")  ->  "rgba(f19618ee)"

-- Ayu de respaldo, por si todavía no existe la paleta activa
local M = {
    fondo = "0e1419", texto = "e5e1cf", acento = "f19618", acento2 = "36a3d9",
    exito = "b8cc52", aviso = "e6c446", peligro = "ff3333", seleccion = "243340", gris = "5c6773",
}

-- Archivos de estado anteriores a los nombres por función
local antiguos = { naranja = "acento", azul = "acento2", verde = "exito", amarillo = "aviso", rojo = "peligro" }

local activa = os.getenv("HOME") .. "/.local/state/tema/hyprland.lua"

-- Vuelve a leer la paleta activa (al cargar y cuando tema.sh la cambia en caliente)
function M.recargar()
    local ok, paleta = pcall(dofile, activa)
    if ok and type(paleta) == "table" then
        for nombre, hex in pairs(paleta) do M[antiguos[nombre] or nombre] = hex end
    end
end
M.recargar()

-- Arma "rgba(RRGGBBAA)". alpha en hex: "ff" = opaco, "00" = invisible
function M.rgba(nombre, alpha)
    return "rgba(" .. M[nombre] .. (alpha or "ff") .. ")"
end

return M
