#!/usr/bin/env python3
"""Capturas de referencia de todos los paneles de Quickshell (no es una prueba automática).

    python3 tests/capturas.py antes          -> ~/.cache/capturas-escritorio/antes/*.png
    python3 tests/capturas.py despues ~/x    -> ~/x/despues/*.png

Abre cada panel un instante sobre la ventana que tengas delante, lo captura y lo cierra.
Conviene lanzarlo dos veces: con una web clara detrás y con una ventana oscura.
Las imágenes salen fuera del repo porque recogen lo que haya en pantalla (chats, portapapeles…).
No toques el teclado mientras corre (~25 s).
"""
import json
import subprocess
import sys
import time
from pathlib import Path

PANELES = [
    ("dashboard",        ["dashboard", "abrir"],               ["dashboard", "cerrar"]),
    ("lanzador",         ["lanzador", "toggle"],               ["lanzador", "toggle"]),
    ("lanzador-busqueda", ["lanzador", "buscar", "fire"],      ["lanzador", "toggle"]),
    ("centro-control",   ["notificaciones", "toggle"],         ["notificaciones", "toggle"]),
    ("vista",            ["vista", "toggle"],                  ["vista", "toggle"]),
    ("brujula",          ["brujula", "abrir", "hoy"],          ["brujula", "cerrar"]),
    ("mesa",             ["mesa", "abrir", "ventanas"],        ["mesa", "cerrar"]),
    ("agente",           ["agente", "toggle"],                 ["agente", "toggle"]),
    ("chuleta",          ["chuleta", "toggle"],                ["chuleta", "toggle"]),
    ("centro-escritorio", ["centroEscritorio", "toggle"],      ["centroEscritorio", "cerrar"]),
    ("conexiones",       ["conexiones", "wifi"],               ["conexiones", "toggle"]),
    ("wallpapers",       ["wallpapers", "toggle"],             ["wallpapers", "toggle"]),
    ("portapapeles",     ["portapapeles", "toggle"],           ["portapapeles", "toggle"]),
    ("menu",             ["menu", "capturas"],                 ["menu", "cerrar"]),
    ("movil",            ["movil", "abrir"],                   ["movil", "cerrar"]),
    ("flujo",            ["flujo", "abrir", "proyectos"],      ["flujo", "cerrar"]),
]


def qs(*args):
    subprocess.run(["qs", "ipc", "call", *args], capture_output=True)


def capturar(ruta):
    time.sleep(1.0)   # que termine la animación de entrada
    subprocess.run(["grim", "-s", "1", str(ruta)], check=True)


def main():
    etiqueta = sys.argv[1] if len(sys.argv) > 1 else "capturas"
    base = Path(sys.argv[2]).expanduser() if len(sys.argv) > 2 else Path.home() / ".cache/capturas-escritorio"
    destino = base / etiqueta
    destino.mkdir(parents=True, exist_ok=True)

    capturar(destino / "00-pantalla.png")
    for nombre, abrir, cerrar in PANELES:
        qs(*abrir)
        capturar(destino / f"{nombre}.png")
        qs(*cerrar)
        time.sleep(0.4)

    # Escritorio vacío (widgets): un workspace sin ventanas y vuelta al de antes
    activo = json.loads(subprocess.run(["hyprctl", "activeworkspace", "-j"],
                                       capture_output=True, text=True).stdout)["id"]
    # los espacios especiales no traen id en Hyprland 0.57
    ocupados = {w.get("id") for w in json.loads(subprocess.run(["hyprctl", "workspaces", "-j"],
                                                               capture_output=True, text=True).stdout)}
    libre = next(n for n in range(1, 11) if n not in ocupados)
    qs("dashboard", "irA", str(libre))
    capturar(destino / "escritorio.png")
    qs("dashboard", "irA", str(activo))

    print(destino)


if __name__ == "__main__":
    main()
