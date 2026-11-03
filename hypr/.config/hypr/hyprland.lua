-- ============================================================
--  Hyprland de Oscar · tema Ayu Dark · config modular (Lua)
--  Wiki: https://wiki.hypr.land/configuring/
-- ============================================================
--
-- Cada archivo de modulos/ hace UNA cosa. Para cambiar algo, abre el que toca:
--
--   colores.lua     paleta Ayu (único sitio con colores) + función rgba()
--   programas.lua   terminal, lanzador, tecla principal… (los usan los atajos)
--   utilidades.lua  funciones propias: enfocar_o_abrir, atajos en lista
--   monitores.lua   pantallas
--   entorno.lua     variables de entorno (cursor, Qt, flatpak)
--   autostart.lua   lo que arranca al iniciar sesión
--   apariencia.lua  bordes, huecos, opacidad, sombras, blur, layouts
--   animaciones.lua curvas y animaciones
--   entrada.lua     teclado, touchpad, gestos
--   sistema.lua     opciones misc, capas, permisos
--   reglas.lua      reglas de ventanas y capas
--   atajos.lua      todos los atajos normales
--   submaps.lua     modos "redimensionar" y "lanzar"
--
-- Cada require es un ámbito separado: si un módulo tiene un error, los demás
-- se siguen cargando (y Hyprland muestra el error arriba). Revisar con:
--   hyprctl configerrors

require("modulos.monitores")
require("modulos.entorno")
require("modulos.autostart")
require("modulos.apariencia")
require("modulos.animaciones")
require("modulos.entrada")
require("modulos.sistema")
require("modulos.reglas")
require("modulos.atajos")
require("modulos.submaps")
