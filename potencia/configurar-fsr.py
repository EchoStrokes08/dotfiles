#!/usr/bin/env python3
"""Aplica FSR a los juegos instalados de las bibliotecas de Steam, con Steam cerrado."""
import argparse
from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

# Excepción ya acordada: conservar la imagen original de Geometry Dash.
EXCLUIDOS = {"322170"}
HERRAMIENTAS = re.compile(r"^(?:Proton(?:\b|_)|Steam Linux Runtime\b|Steamworks Common Redistributables\b|SteamVR\b)", re.I)
PATRON = re.compile(r'\s+|//[^\n]*|"(?:\\.|[^"\\])*"|[{}]|.', re.DOTALL)


def analizar(texto):
    tokens = [t for t in PATRON.finditer(texto) if not t.group().isspace() and not t.group().startswith("//")]
    indice = 0

    def objeto(anidado=False):
        nonlocal indice
        entradas = {}
        while indice < len(tokens):
            clave = tokens[indice]
            if clave.group() == "}" and anidado:
                indice += 1
                return entradas, clave.start()
            if not clave.group().startswith('"'):
                raise ValueError("Formato VDF no reconocido")
            nombre = json.loads(clave.group())
            indice += 1
            if indice >= len(tokens) or nombre in entradas:
                raise ValueError("VDF incompleto o con claves duplicadas")
            valor = tokens[indice]
            indice += 1
            if valor.group() == "{":
                hijos, cierre = objeto(True)
                entradas[nombre] = (hijos, valor.start(), cierre)
            elif valor.group().startswith('"'):
                entradas[nombre] = (json.loads(valor.group()), valor.start(), valor.end())
            else:
                raise ValueError("Valor VDF no reconocido")
        if anidado:
            raise ValueError("Objeto VDF sin cierre")
        return entradas, len(texto)

    return objeto()[0]


def configurar(texto, ids, comando):
    nodo = analizar(texto)
    for clave in ("UserLocalConfigStore", "Software", "Valve", "Steam"):
        nodo = nodo[clave][0]
    nodo, _, cierre_apps = nodo["apps"]
    cambios = []
    nuevos = []
    for appid in ids:
        if not re.fullmatch(r"[1-9][0-9]*", appid):
            raise ValueError("Identificador de aplicación no válido")
        if appid not in nodo:
            nuevos.append(appid)
            continue
        hijos, _, cierre = nodo[appid]
        if "LaunchOptions" in hijos:
            previo, inicio, fin = hijos["LaunchOptions"]
            # Respeta opciones particulares que no pertenecen a este ajuste.
            if previo not in ("", "gamemoderun %command%", comando):
                continue
            if previo != comando:
                cambios.append((inicio, fin, json.dumps(comando)))
        else:
            inicio = texto.rfind("\n", 0, cierre) + 1
            sangria = texto[inicio:cierre]
            if sangria.strip():
                raise ValueError("El cierre VDF no está en una línea independiente")
            cambios.append((inicio, inicio, sangria + '\t"LaunchOptions"\t\t' + json.dumps(comando) + "\n"))
    if nuevos:
        inicio = texto.rfind("\n", 0, cierre_apps) + 1
        sangria = texto[inicio:cierre_apps]
        if sangria.strip():
            # También admite objetos VDF compactos sin reescribir el documento.
            inicio = cierre_apps
            sangria = ""
        contenido = ""
        for appid in nuevos:
            contenido += (f'\n{sangria}\t"{appid}"\n{sangria}\t{{\n'
                          f'{sangria}\t\t"LaunchOptions"\t\t{json.dumps(comando)}\n{sangria}\t}}\n')
        cambios.append((inicio, inicio, contenido))
    for inicio, fin, valor in sorted(cambios, reverse=True):
        texto = texto[:inicio] + valor + texto[fin:]
    analizar(texto)
    return texto


def juegos_instalados(steam):
    bibliotecas = {steam.resolve()}
    archivo = steam / "steamapps/libraryfolders.vdf"
    if archivo.is_file():
        for datos, _, _ in analizar(archivo.read_text())["libraryfolders"][0].values():
            if isinstance(datos, dict) and "path" in datos:
                bibliotecas.add(Path(datos["path"][0]).resolve())
    juegos = {}
    for biblioteca in sorted(bibliotecas):
        for manifiesto in sorted((biblioteca / "steamapps").glob("appmanifest_*.acf")):
            datos = analizar(manifiesto.read_text())["AppState"][0]
            appid = datos["appid"][0]
            nombre = datos["name"][0]
            if not re.fullmatch(r"[1-9][0-9]*", appid):
                continue
            if appid in EXCLUIDOS or HERRAMIENTAS.match(nombre) or not (int(datos["StateFlags"][0]) & 4):
                continue
            juegos[appid] = nombre
    return juegos


def steam_abierto():
    resultado = subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "steam"], stdout=subprocess.DEVNULL).returncode
    if resultado not in (0, 1):
        raise ValueError("No se pudo comprobar si Steam está cerrado")
    return resultado == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simular", action="store_true")
    parser.add_argument("--automatico", action="store_true", help="espera sin modificar archivos si Steam está abierto")
    args = parser.parse_args()
    if not args.simular and steam_abierto():
        if args.automatico:
            return
        raise ValueError("Cierra Steam completamente (Steam → Salir) y vuelve a ejecutar el instalador")
    bloqueo = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "orion-fsr"
    bloqueo.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (bloqueo / "lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        aplicar(args)


def aplicar(args):
    steam = Path.home() / ".local/share/Steam"
    comando = str(Path.home() / ".config/hypr/scripts/juego-fsr.sh") + " %command%"
    if not (Path.home() / ".config/hypr/scripts/juego-fsr.sh").is_file():
        raise ValueError("No se encuentra el lanzador juego-fsr.sh")
    planes = []
    juegos = juegos_instalados(steam)
    for ruta in sorted((steam / "userdata").glob("*/config/localconfig.vdf")):
        original = ruta.read_text()
        apps = analizar(original)["UserLocalConfigStore"][0]["Software"][0]["Valve"][0]["Steam"][0]["apps"][0]
        ids = list(juegos)
        if ids:
            planes.append((ruta, original, configurar(original, ids, comando)))
            if args.simular:
                for appid in ids:
                    previo = apps.get(appid, ({}, 0, 0))[0].get("LaunchOptions", ("", 0, 0))[0]
                    if previo not in ("", "gamemoderun %command%", comando):
                        print(f"Se conserva la configuración propia: {juegos[appid]}")
                    else:
                        print(f"FSR 720p: {juegos[appid]}")
    if not planes:
        if not args.automatico:
            print("No hay juegos instalados pendientes de configurar")
        return
    if args.simular:
        print("Simulación: no se modificó Steam")
        return
    for ruta, original, nuevo in planes:
        if nuevo == original:
            continue
        if steam_abierto():
            if args.automatico:
                return
            raise ValueError("Steam se abrió; no se modifica su configuración")
        if ruta.read_text() != original:
            raise ValueError("Steam cambió el archivo durante la operación; reintenta con Steam cerrado")
        copia = ruta.with_name("localconfig.vdf.antes-fsr-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        shutil.copy2(ruta, copia)
        fd, temporal = tempfile.mkstemp(prefix=".fsr-", dir=ruta.parent)
        try:
            with os.fdopen(fd, "w") as salida:
                salida.write(nuevo)
            shutil.copymode(ruta, temporal)
            os.replace(temporal, ruta)
        finally:
            Path(temporal).unlink(missing_ok=True)
        print(f"Copia de seguridad: {copia}")
    if not args.automatico:
        print("Listo. Abre Steam y lanza el juego. Geometry Dash conserva su resolución original.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit(str(error))
