#!/usr/bin/env python3
"""Copia TODOS los atajos del README (desde «### Atajos de teclado» hasta «### Comportamiento automático»:
teclado, ratón, lanzador, layouts y gestos) al apéndice A del manual, entre las marcas atajos:inicio/fin.
El README es la única fuente (también la lee la chuleta, SUPER+H): tras cambiar un atajo, documéntalo allí y
ejecuta:  ~/dotfiles/docs/actualizar-atajos.py
"""
import re
from pathlib import Path

DOT = Path(__file__).resolve().parent.parent
readme = (DOT / "README.md").read_text()
ini = readme.index("### Atajos de teclado")
fin = readme.index("### Comportamiento automático")
bloque = readme[ini:fin].strip()

manual_p = DOT / "docs" / "manual.md"
manual = manual_p.read_text()
patron = re.compile(r"(<!-- atajos:inicio[^\n]*-->\n).*?(<!-- atajos:fin -->)", re.S)
if not patron.search(manual):
    raise SystemExit("No encuentro las marcas atajos:inicio / atajos:fin en docs/manual.md")
nuevo = patron.sub(lambda m: m.group(1) + "\n" + bloque + "\n\n" + m.group(2), manual)
manual_p.write_text(nuevo)
print(f"Apéndice A actualizado: {bloque.count(chr(10) + '| ')} filas copiadas del README")
