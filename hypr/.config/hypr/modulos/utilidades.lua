-- Funciones reutilizables para los atajos.
local M = {}

-- "Enfocar o abrir": devuelve una función para hl.bind.
-- Si ya hay una ventana con esa class la enfoca; si no, ejecuta el comando.
-- Ver la class de una ventana: hyprctl clients
function M.enfocar_o_abrir(clase, comando)
    return function()
        local ventana = hl.get_windows({ class = clase })[1]
        if ventana then
            hl.dispatch(hl.dsp.focus({ window = ventana }))
        else
            hl.dispatch(hl.dsp.exec_cmd(comando))
        end
    end
end

-- Registra una lista de atajos de golpe: { {"teclas", dispatcher, opciones?}, ... }
function M.atajos(lista)
    for _, a in ipairs(lista) do
        hl.bind(a[1], a[2], a[3])
    end
end

return M
