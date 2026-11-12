#!/usr/bin/env python3
"""PC y móvil como uno solo (KDE Connect). Lo usa el panel Movil.qml (SUPER+ALT+M).

    movil.py estado                       JSON: móvil, batería, red, notificaciones, música, funciones
    movil.py responder <id> <texto>       contestar una notificación del móvil (WhatsApp, Telegram, SMS…)
    movil.py descartar <id>               quitarla del móvil
    movil.py musica <PlayPause|Next|Previous>   la música que suena en el móvil
    movil.py funcion <plugin> on|off      p. ej. kdeconnect_clipboard (portapapeles compartido)
    movil.py comandos                     instala en el móvil los mandos del PC (diapositivas, bloquear…)
    movil.py enlace                       abre en el móvil el enlace (o texto) que tienes copiado
    movil.py captura                      captura de pantalla directa al móvil
    movil.py pc <accion>                  lo que ejecutan los mandos desde el móvil
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

BUS = "org.kde.kdeconnect"
HOME = Path.home()
SCRIPTS = Path(__file__).resolve().parent
YO = str(HOME / ".config/hypr/scripts/movil.py")


def sh(args, timeout=4):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def lanzar(args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def osd(texto, icono="f011c"):
    lanzar(["qs", "ipc", "call", "osd", "mensaje", texto, icono])


def dbus(ruta, metodo, *args, interfaz=None):
    """busctl con salida JSON → el dato Python (o None si falla)."""
    firma = "".join("s" if isinstance(a, str) else "b" if isinstance(a, bool) else "i" for a in args)
    cmd = ["busctl", "--user", "--json=short", "call", BUS, ruta, interfaz, metodo]
    if args:
        cmd += [firma] + [("true" if a else "false") if isinstance(a, bool) else str(a) for a in args]
    salida = sh(cmd)
    try:
        datos = json.loads(salida)["data"] if salida else None
    except (ValueError, KeyError):
        return None
    return datos[0] if isinstance(datos, list) and len(datos) == 1 else datos


def propiedades(ruta, interfaz):
    d = dbus(ruta, "GetAll", interfaz, interfaz="org.freedesktop.DBus.Properties") or {}
    return {k: v.get("data") for k, v in d.items()} if isinstance(d, dict) else {}


def dispositivo():
    """(id, ruta D-Bus) del primer móvil emparejado y alcanzable, o (None, None)."""
    for ident in sh(["kdeconnect-cli", "-a", "--id-only"]).splitlines():
        if re.fullmatch(r"[\w-]+", ident):
            return ident, f"/modules/kdeconnect/devices/{ident}"
    return None, None


def emparejado():
    for ident in sh(["kdeconnect-cli", "-l", "--id-only"]).splitlines():
        if re.fullmatch(r"[\w-]+", ident):
            return ident
    return None


FUNCIONES = [
    ("kdeconnect_clipboard", "Portapapeles compartido", "Lo que copias en uno se puede pegar en el otro"),
    ("kdeconnect_notifications", "Avisos del móvil aquí", "Ves y contestas las notificaciones del móvil en el PC"),
    ("kdeconnect_sendnotifications", "Avisos del PC en el móvil", "Las notificaciones del PC llegan al móvil"),
    ("kdeconnect_pausemusic", "Pausar con las llamadas", "Si suena el móvil, la música del PC se pausa"),
    ("kdeconnect_runcommand", "Mandos del PC en el móvil", "Diapositivas, bloquear, música… desde el móvil"),
    ("kdeconnect_mprisremote", "Música del móvil aquí", "Controla desde el PC lo que suena en el móvil"),
]


def notificaciones(ruta):
    res = []
    for nid in dbus(ruta + "/notifications", "activeNotifications", interfaz="org.kde.kdeconnect.device.notifications") or []:
        if not re.fullmatch(r"[\w.:|-]+", nid):
            continue
        p = propiedades(f"{ruta}/notifications/{nid}", "org.kde.kdeconnect.device.notifications.notification")
        if not p or p.get("silent"):
            continue
        res.append({"id": nid, "app": p.get("appName", ""), "titulo": p.get("title", ""), "texto": p.get("text", ""),
                    "responder": bool(p.get("replyId")), "descartable": bool(p.get("dismissable")),
                    "icono": p.get("iconPath", "") if p.get("hasIcon") else ""})
    return res[::-1][:30]


def estado():
    ident, ruta = dispositivo()
    if not ident:
        return {"conectado": False, "emparejado": bool(emparejado()), "nombre": ""}
    dev = propiedades(ruta, "org.kde.kdeconnect.device")
    bat = propiedades(ruta + "/battery", "org.kde.kdeconnect.device.battery")
    red = propiedades(ruta + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report")
    mus = propiedades(ruta + "/mprisremote", "org.kde.kdeconnect.device.mprisremote")
    activas = {}
    for plugin, _, _ in FUNCIONES:
        activas[plugin] = dbus(ruta, "isPluginEnabled", plugin, interfaz="org.kde.kdeconnect.device") is True
    comandos = leer_comandos(ident)
    return {
        "conectado": True, "nombre": dev.get("name", "Móvil"), "id": ident,
        "via": " · ".join(dev.get("activeProviderNames") or []),
        "bateria": bat.get("charge", -1) if bat.get("hasBattery", True) else -1, "cargando": bool(bat.get("isCharging")),
        "red": {"tipo": red.get("cellularNetworkType", ""), "fuerza": red.get("cellularNetworkStrength", -1)},
        "notificaciones": notificaciones(ruta),
        "musica": {"titulo": mus.get("title", ""), "artista": mus.get("artist", ""), "reproduciendo": bool(mus.get("isPlaying")),
                   "reproductor": mus.get("player", ""), "portada": mus.get("localAlbumArtUrl", "")} if mus.get("title") else None,
        "funciones": [{"id": p, "nombre": n, "detalle": d, "activa": activas[p]} for p, n, d in FUNCIONES],
        "mandos": len(comandos), "mandos_nuestros": sum(1 for c in comandos.values() if YO in c.get("command", "")),
    }


# ── mandos del PC en el móvil (complemento «Ejecutar órdenes») ────────────
MANDOS = [
    ("siguiente", "▶ Diapositiva siguiente"), ("anterior", "◀ Diapositiva anterior"),
    ("musica", "⏯ Música del PC: pausar / seguir"), ("silenciar", "🔇 Silenciar el PC"),
    ("bloquear", "🔒 Bloquear el PC"), ("concentracion", "🎯 Concentración 25 min"),
    ("captura", "📸 Captura del PC al móvil"), ("copiado", "📋 Traer lo copiado en el PC"),
    ("suspender", "🌙 Suspender el PC"),
]


def ruta_comandos(ident):
    return HOME / ".config/kdeconnect" / ident / "kdeconnect_runcommand/config"


def leer_comandos(ident):
    try:
        texto = ruta_comandos(ident).read_text()
    except OSError:
        return {}
    m = re.search(r"^commands=@ByteArray\((.*)\)\s*$", texto, re.M)
    if not m:
        return {}
    try:
        return json.loads(m.group(1).replace("\\\\", "\\"))
    except ValueError:
        return {}


def instalar_comandos():
    ident, ruta = dispositivo()
    ident = ident or emparejado()
    if not ident:
        raise ValueError("No hay ningún móvil emparejado")
    comandos = {k: v for k, v in leer_comandos(ident).items() if YO not in v.get("command", "")}   # conserva los tuyos
    for accion, nombre in MANDOS:
        comandos[str(uuid.uuid5(uuid.NAMESPACE_URL, "movil-pc-" + accion))] = {"name": nombre, "command": f"{YO} pc {accion}"}
    archivo = ruta_comandos(ident)
    archivo.parent.mkdir(parents=True, exist_ok=True)
    # KConfig: el JSON va tal cual (solo ASCII: los emojis como \uXXXX) y cada «\» se escribe «\\»
    datos = json.dumps(comandos, ensure_ascii=True, separators=(",", ":"))
    contenido = "[General]\ncommands=@ByteArray(" + datos.replace("\\", "\\\\") + ")\n"
    fd, tmp = tempfile.mkstemp(dir=archivo.parent)
    with os.fdopen(fd, "w") as f:
        f.write(contenido)
    os.replace(tmp, archivo)
    if ruta:
        dbus(ruta, "reloadPlugins", interfaz="org.kde.kdeconnect.device")
    return {"mensaje": f"{len(MANDOS)} mandos listos en el móvil: KDE Connect → «Ejecutar orden»."}


def pc(accion):
    """Lo que hace cada mando del móvil. Solo acciones fijas: el móvil no puede mandar órdenes libres."""
    if accion == "siguiente":
        sh(["wtype", "-k", "Right"])
    elif accion == "anterior":
        sh(["wtype", "-k", "Left"])
    elif accion == "musica":
        sh(["playerctl", "play-pause"])
    elif accion == "silenciar":
        sh(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        osd("Silencio alternado desde el móvil", "f075f")
    elif accion == "bloquear":
        sh(["loginctl", "lock-session"])
    elif accion == "suspender":
        sh(["systemctl", "suspend"])
    elif accion == "concentracion":
        sh(["qs", "ipc", "call", "concentracion", "empezar", "25"])
    elif accion == "captura":
        captura()
    elif accion == "copiado":
        enlace(forzar_texto=True)
    else:
        raise ValueError("Mando desconocido")
    return {"mensaje": "Hecho"}


def captura():
    ident, _ = dispositivo()
    if not ident:
        raise ValueError("No hay ningún móvil conectado")
    carpeta = HOME / "Imágenes/screenshots"
    carpeta.mkdir(parents=True, exist_ok=True)
    archivo = carpeta / time.strftime("captura-movil-%Y%m%d-%H%M%S.png")
    sh(["grim", str(archivo)], timeout=10)
    if not archivo.exists():
        raise ValueError("No se pudo hacer la captura")
    sh(["kdeconnect-cli", "-d", ident, "--share", str(archivo)], timeout=20)
    osd("Captura enviada al móvil", "f0100")
    return {"mensaje": "Captura enviada al móvil."}


def enlace(forzar_texto=False):
    """Un enlace copiado se ABRE en el móvil; un texto llega a su portapapeles."""
    ident, _ = dispositivo()
    if not ident:
        raise ValueError("No hay ningún móvil conectado")
    texto = sh(["wl-paste", "-n"]).strip()
    if not texto:
        raise ValueError("No hay nada copiado")
    if not forzar_texto and re.fullmatch(r"https?://\S+", texto):
        sh(["kdeconnect-cli", "-d", ident, "--share", texto], timeout=10)
        osd("Abierto en el móvil", "f011c")
        return {"mensaje": "Enlace abierto en el móvil."}
    sh(["kdeconnect-cli", "-d", ident, "--share-text", texto], timeout=10)
    osd("Enviado al móvil", "f011c")
    return {"mensaje": "Texto enviado al móvil."}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    orden, args = sys.argv[1], sys.argv[2:]
    if orden == "estado":
        r = estado()
    elif orden == "comandos":
        r = instalar_comandos()
    elif orden == "pc" and args:
        r = pc(args[0])
    elif orden == "captura":
        r = captura()
    elif orden == "enlace":
        r = enlace()
    else:
        ident, ruta = dispositivo()
        if not ident:
            raise ValueError("No hay ningún móvil conectado")
        if orden == "responder" and len(args) >= 2:
            p = propiedades(f"{ruta}/notifications/{args[0]}", "org.kde.kdeconnect.device.notifications.notification")
            if not p.get("replyId"):
                raise ValueError("Esa notificación no admite respuesta")
            dbus(ruta + "/notifications", "sendReply", p["replyId"], " ".join(args[1:])[:2000], interfaz="org.kde.kdeconnect.device.notifications")
            r = {"mensaje": "Respuesta enviada desde el móvil."}
        elif orden == "descartar" and args and re.fullmatch(r"[\w.:|-]+", args[0]):
            dbus(f"{ruta}/notifications/{args[0]}", "dismiss", interfaz="org.kde.kdeconnect.device.notifications.notification")
            r = {"mensaje": "Notificación descartada."}
        elif orden == "musica" and args and args[0] in ("PlayPause", "Next", "Previous"):
            dbus(ruta + "/mprisremote", "sendAction", args[0], interfaz="org.kde.kdeconnect.device.mprisremote")
            r = {"mensaje": ""}
        elif orden == "funcion" and len(args) == 2 and args[0] in {f[0] for f in FUNCIONES} and args[1] in ("on", "off"):
            dbus(ruta, "setPluginEnabled", args[0], args[1] == "on", interfaz="org.kde.kdeconnect.device")
            r = {"mensaje": "Función " + ("activada" if args[1] == "on" else "desactivada") + "."}
        else:
            raise ValueError("Orden no válida")
    print(json.dumps(r, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
