#!/usr/bin/env python3
"""La impresora de casa (CUPS). Lo usa el panel Impresora.qml (SUPER+A y luego I).

    impresora.py estado              JSON: nombre, modelo, IP, si responde, estado y cola de trabajos
    impresora.py imprimir <archivo>… manda archivos a imprimir
    impresora.py elegir              abre un selector de archivos y los imprime
    impresora.py prueba              página de prueba de CUPS
    impresora.py cancelar <id>|todos quita trabajos de la cola
    impresora.py reactivar           vuelve a habilitar la cola si CUPS la pausó tras un error
    impresora.py reparar             busca la impresora en la red por su MAC y actualiza la IP si cambió
"""
import ipaddress
import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path

COLA = os.environ.get("IMPRESORA_COLA", "Epson")
MAC = "64:c6:d2:c8:88:73"          # la Epson L3250 de la red DEISY_SOTO
PRUEBA = Path("/usr/share/cups/data/default-testpage.pdf")
C = {**os.environ, "LC_ALL": "C"}  # salida de CUPS sin traducir, para leerla


def correr(*cmd, entrada=None):
    r = subprocess.run(cmd, capture_output=True, text=True, env=C, input=entrada)
    return r.returncode, r.stdout, r.stderr


def uri():
    _, out, _ = correr("lpstat", "-v", COLA)
    m = re.search(r"device for \S+: (\S+)", out)
    return m.group(1) if m else ""


def host(u):
    m = re.match(r"\w+://([^/:]+)", u)
    return m.group(1) if m else ""


def responde(h, puerto=631, espera=1.0):
    if not h:
        return False
    try:
        with socket.create_connection((h, puerto), timeout=espera):
            return True
    except OSError:
        return False


def leer_cola(texto):
    """Trabajos de `lpq` (LC_ALL=C): [{id, rango, dueno, archivo, tamano}]."""
    trabajos = []
    for linea in texto.splitlines():
        m = re.match(r"^(active|\d+\w*)\s+(\S+)\s+(\d+)\s+(.*?)\s+(\d+) bytes\s*$", linea)
        if m:
            trabajos.append({"rango": m[1], "dueno": m[2], "id": int(m[3]),
                             "archivo": m[4].strip(), "tamano": int(m[5])})
    return trabajos


def leer_estado(texto):
    """De `lpstat -p`: (estado, habilitada, mensaje)."""
    m = re.search(r"printer \S+ (?:is|now) (\w+)", texto)
    estado = m.group(1) if m else "desconocido"
    habilitada = "disabled" not in texto
    msg = ""
    for linea in texto.splitlines()[1:]:
        linea = linea.strip()
        if linea:
            msg = linea
            break
    return estado, habilitada, msg


def red():
    _, out, _ = correr("nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi")
    for linea in out.splitlines():
        if linea.startswith("yes:"):
            return linea[4:]
    return ""


def estado():
    u = uri()
    h = host(u)
    _, p, _ = correr("lpstat", "-p", COLA)
    est, habilitada, msg = leer_estado(p)
    _, q, _ = correr("lpq", "-P", COLA)
    _, opc, _ = correr("lpoptions", "-p", COLA)
    m = re.search(r"printer-make-and-model='([^']*)'", opc) or re.search(r"printer-make-and-model=(\S+)", opc)
    return {
        "instalada": bool(u),
        "cola": COLA,
        "modelo": re.sub(r"\s*-\s*IPP Everywhere$", "", m.group(1)) if m else "",
        "ip": h,
        "web": f"http://{h}/" if h else "",
        "tinta": f"http://{h}/PRESENTATION/HTML/TOP/PRTINFO.HTML" if h else "",
        "responde": responde(h),
        "estado": est,              # idle · printing · stopped
        "habilitada": habilitada,
        "mensaje": msg,
        "red": red(),
        "trabajos": leer_cola(q),
    }


def imprimir(archivos):
    archivos = [a for a in archivos if a and Path(a).is_file()]
    if not archivos:
        return 1
    codigo, _, err = correr("lp", "-d", COLA, *archivos)
    sys.stderr.write(err)
    return codigo


def elegir():
    r = subprocess.run(["zenity", "--file-selection", "--multiple", "--separator=\n",
                        "--title=Imprimir", f"--filename={Path.home()}/"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return 0                    # cancelado
    return imprimir(r.stdout.splitlines())


def cancelar(cual):
    if cual == "todos":
        return correr("cancel", "-a", COLA)[0]
    return correr("cancel", f"{COLA}-{int(cual)}")[0]


def reactivar():
    return correr("cupsenable", COLA)[0]


def buscar_ip(mac=MAC):
    """IP de la impresora en la red local, por su MAC (barre la /24 para llenar la tabla ARP)."""
    _, out, _ = correr("ip", "-4", "-o", "addr", "show", "scope", "global")
    redes = [ipaddress.ip_interface(m).network for m in re.findall(r"inet (\S+)", out)]
    for r in redes:
        if r.prefixlen < 24:
            continue
        procs = [subprocess.Popen(["ping", "-c1", "-W1", str(h)], stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL) for h in r.hosts()]
        for p in procs:
            p.wait()
    _, vecinos, _ = correr("ip", "neigh")
    for linea in vecinos.splitlines():
        if mac.lower() in linea.lower():
            return linea.split()[0]
    return ""


def reparar():
    if responde(host(uri())):
        return 0
    ip = buscar_ip()
    if not ip:
        print("No encuentro la impresora en esta red", file=sys.stderr)
        return 1
    return correr("sudo", "-n", "lpadmin", "-p", COLA, "-v", f"ipp://{ip}/ipp/print", "-E")[0]


def main(args):
    if not args or args[0] == "estado":
        print(json.dumps(estado(), ensure_ascii=False))
        return 0
    orden, resto = args[0], args[1:]
    if orden == "imprimir":
        return imprimir(resto)
    if orden == "elegir":
        return elegir()
    if orden == "prueba":
        return imprimir([str(PRUEBA)])
    if orden == "cancelar" and resto:
        return cancelar(resto[0])
    if orden == "reactivar":
        return reactivar()
    if orden == "reparar":
        return reparar()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
