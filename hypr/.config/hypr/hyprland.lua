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
--   layouts.lua     atajos que se adaptan al layout (dwindle, master, scrolling)
--   scratchpads.lua terminal, música y notas que aparecen y se esconden con una tecla
--   modo_juego.lua  SUPER+SHIFT+G o automático con Roblox: sin efectos ni notificaciones
--   tema.lua        colores Ayu o del wallpaper (SUPER+SHIFT+T) y rotación de fondos
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
require("modulos.modo_juego")
require("modulos.bateria")         -- sin cargador: sin blur ni sombras (lo avisa Quickshell, Cargador.qml)
require("modulos.concentracion")   -- SUPER+SHIFT+F (temporizador en Quickshell)
require("modulos.scratchpads")     -- SUPER+Return / Y / O: terminal, música y notas que aparecen y desaparecen
require("modulos.layouts")         -- SUPER+plus/minus/Z/X: hacen lo equivalente en dwindle, master y scrolling
require("modulos.tema")
