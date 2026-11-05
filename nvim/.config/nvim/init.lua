-- Neovim — config base para aprender (Neovim 0.12, un solo archivo)
-- Abrir este archivo:  nvim ~/.config/nvim/init.lua      Recargar: reinicia nvim
-- Es Lua, igual que hyprland.lua: vim.opt = opciones, vim.keymap.set = atajos.

-- ── Opciones ────────────────────────────────────────────────────────────
vim.g.mapleader = " "              -- <leader> = Espacio (prefijo de tus atajos)
local o = vim.opt
o.number = true                    -- números de línea
o.relativenumber = true            -- …relativos: "5j" baja 5 sin contar
o.cursorline = true                -- resalta la línea del cursor
o.termguicolors = true             -- colores de 24 bits (los de Ayu)
o.mouse = "a"                      -- ratón en todos los modos
o.clipboard = "unnamedplus"        -- y/p usan el portapapeles del sistema (wl-copy)
o.expandtab = true                 -- Tab inserta espacios…
o.shiftwidth = 4                   -- …4 por nivel
o.tabstop = 4
o.ignorecase = true                -- buscar sin distinguir mayúsculas…
o.smartcase = true                 -- …salvo que escribas alguna
o.scrolloff = 8                    -- deja 8 líneas de margen al desplazarte
o.signcolumn = "yes"
o.undofile = true                  -- deshacer incluso tras cerrar el archivo
o.showmode = false                 -- el modo ya lo muestra lualine

-- ── Plugins (vim.pack: el gestor integrado de Neovim 0.12) ───────────────
-- La primera vez pregunta si instalar: responde y. Actualizar: :lua vim.pack.update()
vim.pack.add({
    "https://github.com/Shatur/neovim-ayu",       -- tema Ayu
    "https://github.com/nvim-lualine/lualine.nvim", -- barra de estado
})

-- Tema: Ayu Dark con el fondo transparente (se ve la opacidad y el blur de kitty)
require("ayu").setup({
    mirage = false,
    overrides = {
        Normal      = { bg = "None" },
        NormalNC    = { bg = "None" },
        SignColumn  = { bg = "None" },
        LineNr      = { fg = "#5c6773" },
        CursorLineNr = { fg = "#f19618", bold = true },
    },
})
vim.cmd.colorscheme("ayu-dark")

require("lualine").setup({
    options = {
        theme = "ayu_dark",
        section_separators   = { left = "\u{e0b4}", right = "\u{e0b6}" },
        component_separators = { left = "\u{e0b5}", right = "\u{e0b7}" },
    },
})

-- ── Atajos ──────────────────────────────────────────────────────────────
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>write<cr>",  { desc = "Guardar" })
map("n", "<leader>q", "<cmd>quit<cr>",   { desc = "Salir" })
map("n", "<Esc>",     "<cmd>nohlsearch<cr>", { desc = "Quitar resaltado de búsqueda" })
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "Explorador de archivos (netrw)" })
map("v", "J", ":m '>+1<cr>gv=gv",        { desc = "Mover selección abajo" })
map("v", "K", ":m '<-2<cr>gv=gv",        { desc = "Mover selección arriba" })

-- Parpadeo naranja al copiar (y), para ver qué se copió
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function() vim.hl.on_yank({ timeout = 200 }) end,
})
