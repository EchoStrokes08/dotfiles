-- Ratón: clic izquierdo selecciona; otro clic sobre el que ya está seleccionado lo abre
-- (carpeta → entra, archivo → su app). El clic derecho sigue abriendo directamente.
-- Por defecto yazi solo abre con clic derecho.
function Entity:click(event, up)
	if up or event.is_middle then
		return
	end
	local h = cx.active.current.hovered
	local ya_seleccionado = h and h.url == self._file.url
	ya.emit("reveal", { self._file.url })
	if event.is_right or ya_seleccionado then
		ya.emit("open", {})
	end
end
