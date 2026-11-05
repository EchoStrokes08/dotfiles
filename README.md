# dotfiles: Hyprland + Ayu Dark Glass

Mi escritorio en Arch Linux: Hyprland 0.57 con su configuración en Lua, y todo el sistema con la
paleta **Ayu**, desde el arranque (GRUB → Plymouth → SDDM) hasta las apps. Los colores pueden
cambiar solos según el wallpaper, gracias a matugen.

## Instalar en un Arch nuevo

Solo necesitas un Arch recién instalado, con internet y un usuario con sudo. Luego, **un solo comando**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/EchoStrokes08/dotfiles/main/instalar.sh)
```

Clona este repo en `~/dotfiles` y lo instala todo: paquetes de pacman, AUR y Flatpak, enlaces con
stow, servicios, temas de arranque y apps. Puedes correrlo varias veces sin romper nada. Los archivos
que estorben se mueven a `~/.respaldo-dotfiles-FECHA/`, nunca se borran.

```bash
~/dotfiles/instalar.sh --simular        # ver qué haría, sin tocar nada
~/dotfiles/instalar.sh --sin-sistema    # solo tu usuario: sin /etc, servicios ni arranque
~/dotfiles/instalar.sh --solo dotfiles  # un único paso (repos paquetes aur flatpak dotfiles
                                        #   tema buds sistema arranque apps)
```

Cuando instales algo nuevo, actualiza las listas y haz commit:

```bash
~/dotfiles/instalar/actualizar-listas.sh
```

## Qué hay

| Paquete (stow) | Qué configura |
|---|---|
| `hypr` | Hyprland en Lua, partido en módulos (`modulos/`), scripts, hyprlock, hypridle, hyprpaper y los temas de arranque (`temas-arranque/`: SDDM, GRUB y Plymouth) |
| `tema` | Paleta Ayu y plantillas de matugen. `SUPER+SHIFT+T` cambia entre Ayu y los colores del wallpaper |
| `waybar` · `swaync` · `swayosd` · `fuzzel` | Barra, notificaciones y centro de control, indicador de volumen y brillo, lanzador |
| `quickshell` | Dashboard SUPER+D: reloj, espacios de trabajo, calendario, CPU/RAM/temperatura/batería, tiempo de pantalla y música (QML) |
| `kitty` · `zsh` | Terminal, prompt starship, plugins de zsh, fzf, zoxide y fastfetch |
| `gtk` | adw-gtk3 con colores Ayu e iconos Papirus-Ayu |
| `btop` · `nvim` · `vscode` · `firefox` · `vesktop` · `spicetify` | Apps con el tema Ayu |
| `wallpapers` | Mis fondos, en `~/Imágenes/wallpapers` |
| `instalar/` | Listas de paquetes y scripts de instalación (no es un paquete de stow) |

Buds Manager (para controlar los Redmi Buds desde Linux) vive en su propio repo,
[Buds-Manager](https://github.com/EchoStrokes08/Buds-Manager), y el instalador lo clona.

## Atajos principales

| Atajo | Acción |
|---|---|
| `SUPER+Q` / `SUPER+R` / `SUPER+E` | Terminal / lanzador / archivos |
| `SUPER+N` | Centro de control |
| `SUPER+SHIFT+W` / `SUPER+SHIFT+T` | Elegir wallpaper / alternar tema |
| `SUPER+SHIFT+G` | Modo juego |
| `SHIFT+PRINT` | Menú de capturas |
| `SUPER+SHIFT+V` | Historial del portapapeles |
| `SUPER+I` | Inspector de ventanas (class, título, tamaño) |
| `SUPER+TAB` | Cambiar de layout (dwindle → master → scrolling → monocle) |
