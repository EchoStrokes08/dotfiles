"""El sistema de diseño se cumple en todo el shell (escalas en quickshell/EstiloPanel.qml, docs/diseno.md).

Falla si aparece un tamaño de letra, radio o duración fuera de escala, un color escrito a mano fuera de
Paleta.qml, un nombre de color por tono (naranja, azul…) o una paleta de tema a la que le falte un color.
"""
import re
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
QS = RAIZ / "quickshell/.config/quickshell"
TEMA = RAIZ / "tema/.config/tema"
COLORES = ["fondo", "texto", "acento", "acento2", "exito", "aviso", "peligro", "seleccion", "gris"]


def escala(nombre):
    texto = (QS / "EstiloPanel.qml").read_text()
    m = re.search(rf"property var {nombre}:\s*\[([^\]]*)\]", texto)
    return {float(x) for x in m.group(1).split(",")}


def qml():
    return [(p, p.read_text()) for p in sorted(QS.glob("*.qml"))]


def literales(patron, texto):
    """(número de línea, valor) de cada «propiedad: número» literal."""
    for i, linea in enumerate(texto.splitlines(), 1):
        for m in re.finditer(patron, linea):
            yield i, float(m.group(1))


class Escalas(unittest.TestCase):
    def test_letra(self):
        permitidos = escala("escalaLetra")
        fuera = [f"{p.name}:{i} {v:g}" for p, t in qml()
                 for i, v in literales(r"pixelSize:\s*(\d+(?:\.\d+)?)(?![\d.])", t) if v not in permitidos]
        self.assertEqual(fuera, [], "tamaños de letra fuera de escala")

    def test_radio(self):
        permitidos = escala("escalaRadio")
        fuera = [f"{p.name}:{i} {v:g}" for p, t in qml()
                 for i, v in literales(r"(?<![\w.])radius:\s*(\d+(?:\.\d+)?)(?![\d.])", t) if v not in permitidos]
        self.assertEqual(fuera, [], "radios fuera de escala (círculos y píldoras: height / 2)")

    def test_espacio(self):
        permitidos = escala("escalaEspacio")
        patron = (r"(?<![\w.])(?:spacing|margins|leftMargin|rightMargin|topMargin|bottomMargin|padding"
                  r"|leftPadding|rightPadding|topPadding|bottomPadding):\s*(\d+(?:\.\d+)?)(?![\d.\w])")
        fuera = [f"{p.name}:{i} {v:g}" for p, t in qml() if p.name != "EstiloPanel.qml"
                 for i, v in literales(patron, t) if v not in permitidos]
        self.assertEqual(fuera, [], "espacios fuera de escala")

    def test_duracion(self):
        # Entre 100 y 499 ms son transiciones de interfaz: EstiloPanel.rapido / normal / lento.
        # Más cortas (micro-efectos: cava, sacudida) o más largas (ambientales: fundidos del escritorio) se permiten.
        fuera = [f"{p.name}:{i} {v:g}" for p, t in qml()
                 for i, v in literales(r"duration:\s*(\d+)(?![\d.])", t) if 100 <= v < 500]
        self.assertEqual(fuera, [], "duraciones de interfaz escritas a mano")


class Colores(unittest.TestCase):
    def test_sin_hex_fuera_de_paleta(self):
        fuera = [f"{p.name}:{i}" for p, t in qml() if p.name != "Paleta.qml"
                 for i, l in enumerate(t.splitlines(), 1) if re.search(r'"#[0-9a-fA-F]{6,8}"', l)]
        self.assertEqual(fuera, [], "colores escritos a mano: van en Paleta.qml")

    def test_nombres_por_funcion(self):
        viejos = [f"{p.name}:{i}" for p, t in qml()
                  for i, l in enumerate(t.splitlines(), 1)
                  if re.search(r"Paleta\.(naranja|azul|verde|amarillo|rojo|morado)\b", l)]
        self.assertEqual(viejos, [], "usa acento, acento2, exito, aviso o peligro")

    def test_paletas_completas(self):
        for carpeta in ("ayu", "ayu-claro", "plantillas"):
            css = (TEMA / carpeta / "colores.css").read_text()
            lua = (TEMA / carpeta / "hyprland.lua").read_text()
            for nombre in COLORES:
                self.assertRegex(css, rf"@define-color\s+{nombre}\s", f"{carpeta}/colores.css sin {nombre}")
                self.assertRegex(lua, rf"\b{nombre}\s*=", f"{carpeta}/hyprland.lua sin {nombre}")

    def test_paneles_no_translucidos(self):
        # Por debajo de EstiloPanel.opacidadPanel se lee lo que hay detrás del panel
        bajos = [f"{p.name}:{i}" for p, t in qml()
                 for i, v in literales(r"opacidad(?:Tarjeta)?:\s*(0?\.\d+)", t) if v < 0.93]
        self.assertEqual(bajos, [], "paneles por debajo de 0.93 de opacidad")


def luminancia(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contraste(a, b):
    la, lb = sorted([luminancia(a), luminancia(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


def mezcla(a, b, t):
    return "".join(f"{round(int(a[i:i + 2], 16) + (int(b[i:i + 2], 16) - int(a[i:i + 2], 16)) * t):02x}" for i in (0, 2, 4))


class Contraste(unittest.TestCase):
    """WCAG sobre el fondo: texto ≥ 7, texto secundario (tenue, gris) y peligro ≥ 4,5, acentos y estados ≥ 3."""
    MINIMOS = {"texto": 7, "tenue": 4.5, "gris": 4.5, "peligro": 4.5, "acento": 3, "acento2": 3, "exito": 3, "aviso": 3}

    def test_paletas_ayu(self):
        for carpeta in ("ayu", "ayu-claro"):
            css = (TEMA / carpeta / "colores.css").read_text()
            p = {m[1]: m[2] for m in re.finditer(r"@define-color\s+(\w+)\s+#([0-9a-fA-F]{6})", css)}
            claro = luminancia(p["fondo"]) > .5
            p["tenue"] = mezcla(p["fondo"], p["texto"], .82 if claro else .68)   # EstiloPanel.tenue
            for nombre, minimo in self.MINIMOS.items():
                with self.subTest(paleta=carpeta, color=nombre):
                    self.assertGreaterEqual(contraste(p[nombre], p["fondo"]), minimo)


class Componentes(unittest.TestCase):
    def test_cabeceras(self):
        # Antes del primer import solo comentarios, líneas en blanco y pragma (un comentario partido rompe el archivo)
        malos = []
        for p, t in qml():
            for i, l in enumerate(t.splitlines(), 1):
                if l.startswith("import "):
                    break
                if l.strip() and not l.lstrip().startswith(("//", "pragma ")):
                    malos.append(f"{p.name}:{i}")
        self.assertEqual(malos, [], "texto suelto antes de los import")

    def test_atajos_esenciales(self):
        # La chuleta abre con los esenciales: los marca una ★ en docs/atajos.md
        t = (RAIZ / "docs/atajos.md").read_text()
        self.assertIn("### Atajos de teclado", t)
        self.assertEqual(len(re.findall(r"^\| ★ `", t, re.M)), 15)

    def test_botones_compartidos(self):
        # Un botón con estilo propio se define una vez (BotonPanel, BotonCompacto), no dentro de cada panel
        locales = [f"{p.name}:{i}" for p, t in qml()
                   for i, l in enumerate(t.splitlines(), 1) if re.search(r"component \w+:\s*Button\b", l)]
        self.assertEqual(locales, [], "botones definidos dentro de un panel")


if __name__ == "__main__":
    unittest.main()
