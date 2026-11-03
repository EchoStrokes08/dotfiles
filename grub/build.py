#!/usr/bin/env python3
"""Genera el tema de GRUB «Ayu Dark Glass» (a juego con hyprlock).

Uso:  python3 build.py [wallpaper]      (necesita python-pillow y grub-mkfont)
Sale en ./ayu-dark-glass/  → luego: sudo ./install.sh
"""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageEnhance

HERE = Path(__file__).resolve().parent
OUT = HERE / "ayu-dark-glass"
OUT.mkdir(exist_ok=True)
WALL = Path(sys.argv[1] if len(sys.argv) > 1 else "~/Imágenes/wallpapers/galaxia.jpg").expanduser()
FONTS = Path("/usr/share/fonts/TTF")
W, H = 1920, 1080

# Paleta Ayu
BG, TXT, DIM = (11, 14, 20), (229, 225, 207), (92, 103, 115)
ORANGE, BLUE, GREEN = (241, 150, 24), (54, 163, 217), (194, 217, 76)

def font(style, size):
    return ImageFont.truetype(str(FONTS / f"JetBrainsMonoNerdFont-{style}.ttf"), size)

def hgradient(w, h, a, b):
    """Degradado horizontal a→b (RGBA opaco)."""
    g = Image.new("RGBA", (w, h))
    px = g.load()
    for x in range(w):
        t = x / max(w - 1, 1)
        c = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
        for y in range(h):
            px[x, y] = c
    return g

def glow_text(canvas, xy, text, fnt, fill, glow=None, radius=10, anchor="mm", spacing=0):
    """Texto con resplandor/sombra, como shadow_* de hyprlock."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    draw_text(d, xy, text, fnt, glow or (0, 0, 0, 160), anchor, spacing)
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    canvas.alpha_composite(layer)
    draw_text(ImageDraw.Draw(canvas), xy, text, fnt, fill, anchor, spacing)

def draw_text(d, xy, text, fnt, fill, anchor, spacing):
    if not spacing:
        d.text(xy, text, font=fnt, fill=fill, anchor=anchor)
        return
    # letter_spacing manual (como <span letter_spacing> de hyprlock)
    widths = [d.textlength(ch, font=fnt) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = xy[0] - total / 2 if anchor[0] == "m" else xy[0] - (total if anchor[0] == "r" else 0)
    for ch, w in zip(text, widths):
        d.text((x, xy[1]), ch, font=fnt, fill=fill, anchor="l" + anchor[1])
        x += w + spacing

# ───────────────────────── FONDO ─────────────────────────
src = Image.open(WALL).convert("RGB")
s = max(W / src.width, H / src.height)
src = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
l, t = (src.width - W) // 2, (src.height - H) // 2
bg = src.crop((l, t, l + W, t + H))
bg = bg.filter(ImageFilter.GaussianBlur(18))                  # blur_passes/blur_size
bg = ImageEnhance.Color(bg).enhance(1.2)                       # vibrancy
bg = ImageEnhance.Contrast(bg).enhance(0.9)                    # contrast
bg = ImageEnhance.Brightness(bg).enhance(0.62).convert("RGBA") # brightness

# viñeta suave: oscurece los bordes para que el centro respire
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse((-W * 0.25, -H * 0.35, W * 1.25, H * 1.35), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(220))
shade = Image.new("RGBA", (W, H), BG + (150,))
shade.putalpha(Image.eval(vig, lambda v: round(150 * (1 - v / 255))))
bg.alpha_composite(shade)

cx = W // 2

# Logo de Arch con degradado naranja→azul y resplandor
logo_f = font("Regular", 150)
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).text((cx, 205), "\U000f08c7", font=logo_f, fill=255, anchor="mm")
glow = Image.new("RGBA", (W, H), BLUE + (0,))
glow.putalpha(mask.filter(ImageFilter.GaussianBlur(24)).point(lambda v: v * 0.55))
bg.alpha_composite(glow)
box = mask.getbbox()
g = hgradient(box[2] - box[0], box[3] - box[1], ORANGE, BLUE)
full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
full.paste(g, box[:2])
full.putalpha(mask)
bg.alpha_composite(full)

# Saludo
glow_text(bg, (cx, 345), "¿a dónde vamos hoy, oscar?", font("Italic", 26), TXT + (190,), radius=6)

# Barrita decorativa (como el shape de hyprlock)
bar = hgradient(70, 4, ORANGE, BLUE)
bm = Image.new("L", (70, 4), 0)
ImageDraw.Draw(bm).rounded_rectangle((0, 0, 69, 3), 2, fill=255)
bar.putalpha(bm)
bg.alpha_composite(bar, (cx - 35, 388))

# Tarjeta de cristal detrás del menú
CARD = (660, 428, 1260, 680)
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(sh).rounded_rectangle((CARD[0], CARD[1] + 10, CARD[2], CARD[3] + 10), 28, fill=(0, 0, 0, 150))
bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(card).rounded_rectangle(CARD, 28, fill=BG + (150,), outline=TXT + (22,), width=1)
bg.alpha_composite(card)

# Barra inferior (igual que en hyprlock)
small, small_b = font("Regular", 17), font("Bold", 15)
d = ImageDraw.Draw(bg)
y = H - 46
d.text((48, y), "\U000f030c", font=small, fill=BLUE, anchor="lm")
d.text((80, y), "↑ ↓  elegir     \U000f0311  arrancar", font=small, fill=TXT + (170,), anchor="lm")
d.text((W - 48, y), "e  editar   ·   c  consola", font=small, fill=TXT + (170,), anchor="rm")
d.text((W - 340, y), "", font=small, fill=ORANGE, anchor="rm")
lock_w = d.textlength("\U000f033e  ", font=small_b)
draw_text(d, (cx + lock_w / 2, y), "ARRANQUE", small_b, TXT + (128,), "mm", 6)
d.text((cx - 70, y), "\U000f033e", font=small_b, fill=ORANGE, anchor="mm")

# grano fino contra el banding
noise = Image.effect_noise((W, H), 14)
bg = Image.blend(bg.convert("RGB"), Image.merge("RGB", (noise,) * 3), 0.025)
bg.save(OUT / "background.png", optimize=True)

# ───────────────── PÍLDORA DE SELECCIÓN (9-slice) ─────────────────
# El menú mide 552 px; GRUB estira las piezas centrales, así que el degradado se conserva.
PW, PH, R = 552, 56, 28
pill = Image.new("RGBA", (PW, PH), (0, 0, 0, 0))
outer = Image.new("L", (PW * 4, PH * 4), 0)
ImageDraw.Draw(outer).rounded_rectangle((0, 0, PW * 4 - 1, PH * 4 - 1), R * 4, fill=255)
inner = Image.new("L", (PW * 4, PH * 4), 0)
ImageDraw.Draw(inner).rounded_rectangle((8, 8, PW * 4 - 9, PH * 4 - 9), R * 4 - 8, fill=255)
outer, inner = (m.resize((PW, PH), Image.LANCZOS) for m in (outer, inner))
border = hgradient(PW, PH, ORANGE, BLUE)
ring = ImageChops.subtract(outer, inner)  # solo el aro del borde
border.putalpha(ring)
fill = hgradient(PW, PH, ORANGE, BLUE)
fill.putalpha(inner.point(lambda v: round(v * 0.13)))  # cristal teñido
pill.alpha_composite(fill)
pill.alpha_composite(border)

T, M = 20, PH - 40  # alto de las piezas superiores/inferiores y central
cols = {"w": (0, R), "": (R, PW - R), "e": (PW - R, PW)}
rows = {"n": (0, T), "": (T, T + M), "s": (T + M, PH)}
for rk, (y0, y1) in rows.items():
    for ck, (x0, x1) in cols.items():
        name = (rk + ck) or "c"
        pill.crop((x0, y0, x1, y1)).save(OUT / f"select_{name}.png")

# ───────────────── BARRA DE CUENTA ATRÁS ─────────────────
hgradient(64, 4, ORANGE, BLUE).save(OUT / "progress_highlight_c.png")
Image.new("RGBA", (8, 4), TXT + (30,)).save(OUT / "progress_bar_c.png")

# ───────────────── ICONOS DEL MENÚ ─────────────────
icons = OUT / "icons"
icons.mkdir(exist_ok=True)
def icon(glyph, color, names):
    im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((64, 64), glyph, font=font("Regular", 104), fill=color, anchor="mm")
    im = im.resize((32, 32), Image.LANCZOS)
    for n in names:
        im.save(icons / f"{n}.png")
icon("", BLUE, ["arch", "archlinux", "gnu-linux", "linux", "os"])
icon("", ORANGE, ["efi", "uefi", "uefi-firmware", "firmware", "settings"])
icon("\U000f0425", (255, 51, 51), ["shutdown", "poweroff"])
icon("\U000f0709", GREEN, ["restart", "reboot"])

# ───────────────── FUENTES (.pf2) ─────────────────
RANGES = "0x20-0x7E,0xA0-0x17F,0x2014-0x2014,0x2026-0x2026,0x2190-0x2193,0x23CE-0x23CE"
for style, size, name in [("Bold", 22, "Ayu Menu"), ("Regular", 22, "Ayu Menu"),
                          ("Regular", 16, "Ayu Small"), ("Regular", 18, "Ayu Term")]:
    subprocess.run(["grub-mkfont", "-s", str(size), "-n", name, "-r", RANGES,
                    "-o", str(OUT / f"{name.lower().replace(' ', '-')}-{style.lower()}-{size}.pf2"),
                    str(FONTS / f"JetBrainsMonoNerdFont-{style}.ttf")], check=True)

(OUT / "theme.txt").write_text((HERE / "theme.txt").read_text())
print("Tema generado en", OUT)
