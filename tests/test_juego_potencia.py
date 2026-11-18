"""Lógica de seguridad de potencia/juego-potencia: solo sube con juego, cargador y temperatura baja."""
import pathlib
import subprocess
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "potencia" / "juego-potencia"


def decidir(juego, ac, temp, cortado=0):
    salida = subprocess.run(["bash", str(SCRIPT), "decidir", str(juego), str(ac), str(temp), str(cortado)],
                            capture_output=True, text=True, check=True).stdout.split()
    return salida[0], int(salida[1])


class Decidir(unittest.TestCase):
    def test_solo_sube_con_las_tres_condiciones(self):
        self.assertEqual(decidir(1, 1, 60), ("subir", 0))
        for juego, ac in ((0, 1), (1, 0), (0, 0)):
            self.assertEqual(decidir(juego, ac, 60)[0], "fabrica", (juego, ac))

    def test_corte_por_calor_y_reanudacion_con_histeresis(self):
        self.assertEqual(decidir(1, 1, 85), ("fabrica", 1))
        self.assertEqual(decidir(1, 1, 84, cortado=1), ("fabrica", 1))   # aún caliente tras el corte
        self.assertEqual(decidir(1, 1, 78, cortado=1), ("fabrica", 1))
        self.assertEqual(decidir(1, 1, 77, cortado=1), ("subir", 0))     # ya enfrió

    def test_temperatura_ilegible_no_sube(self):
        self.assertEqual(decidir(1, 1, 999)[0], "fabrica")

    def test_estado_sin_servicio_no_necesita_root(self):
        r = subprocess.run(["bash", str(SCRIPT), "estado"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
