import sys
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
# recorte "cover" a 1920x1080
W,H=1920,1080; r=max(W/im.width,H/im.height)
im=im.resize((round(im.width*r),round(im.height*r)),Image.LANCZOS)
l=(im.width-W)//2; t=(im.height-H)//2; im=im.crop((l,t,l+W,t+H))
im.save(f"{out}/sddm-ayu/background.jpg",quality=92)
# GRUB: fondo desenfocado y oscurecido como el de hyprlock (no admite blur en vivo)
g=im.filter(ImageFilter.GaussianBlur(14))
g=ImageEnhance.Brightness(g).enhance(0.45); g=ImageEnhance.Contrast(g).enhance(0.9)
g.save(f"{out}/grub-ayu/background.png")
# Caja de menú: cristal oscuro 9-slice (menu_*.png) y selección (select_*.png)
def slices(prefix, fill, border, rad=14, bw=2):
    s=(rad+2)*2+4
    big=Image.new("RGBA",(s,s),(0,0,0,0)); d=ImageDraw.Draw(big)
    d.rounded_rectangle((0,0,s-1,s-1),radius=rad,fill=fill,outline=border,width=bw if border else 0)
    c=rad+2; m=s-2*c
    parts={"nw":(0,0,c,c),"n":(c,0,c+m,c),"ne":(c+m,0,s,c),"w":(0,c,c,c+m),"c":(c,c,c+m,c+m),
           "e":(c+m,c,s,c+m),"sw":(0,c+m,c,s),"s":(c,c+m,c+m,s),"se":(c+m,c+m,s,s)}
    for k,b in parts.items(): big.crop(b).save(f"{out}/grub-ayu/{prefix}_{k}.png")
slices("menu",(11,14,20,200),(54,163,217,255))        # 0b0e14 + borde azul
slices("select",(241,150,24,60),(241,150,24,255),rad=10)  # naranja translúcido
