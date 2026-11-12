#!/usr/bin/env python3
"""Navegador visible persistente. IPC privado por socket Unix, sin puertos TCP."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
from urllib.parse import quote_plus, urlsplit

BASE = Path.home() / ".local/share/brujula/navegador"
PYTHON = BASE / "venv/bin/python"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", Path.home() / ".cache")) / "brujula-navegador"
SOCKET = RUNTIME / "control.sock"
CLASE = "agente-navegador"   # clase de la ventana, para la regla de Hyprland
INACTIVO = 600   # segundos sin peticiones antes de cerrar el navegador


def validar_url(url):
    u = urlsplit(url)
    if u.scheme not in {"http", "https"} or not u.hostname or u.username or u.password:
        raise ValueError("Solo direcciones HTTP/HTTPS sin credenciales.")
    return url


def disponible():
    return PYTHON.is_file() and (BASE / "listo").is_file()


def arrancar():
    """Lanza el servidor (y Chromium, oculto) sin esperar. El panel lo hace al abrirse para que
    la primera búsqueda no pague el arranque. Si ya está en marcha, el lock del servidor lo descarta."""
    if not disponible():
        return
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (RUNTIME / "errores.log").open("a") as log:
        subprocess.Popen([str(PYTHON), str(Path(__file__).resolve()), "servir"],
                         stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)


def llamar(accion, **args):
    if not disponible():
        raise ValueError("Falta instalar el navegador. Ejecuta ~/.config/hypr/scripts/agente-navegador-instalar.sh desde una terminal.")
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    def conectar():
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(60)
        try:
            s.connect(str(SOCKET))
        except OSError:
            s.close()
            raise
        return s
    try:
        s = conectar()
    except OSError:
        arrancar()
        for _ in range(150):
            time.sleep(.1)
            try:
                s = conectar()
                break
            except OSError:
                pass
        else:
            raise ValueError(f"El navegador no arrancó. Revisa {RUNTIME / 'errores.log'}.")
    with s:
        s.sendall(json.dumps({"accion": accion, **args}).encode() + b"\n")
        with s.makefile("rb") as f:
            respuesta = json.loads(f.readline(200000))
    if "error" in respuesta:
        raise ValueError(respuesta["error"])
    return respuesta["resultado"]


def navegar(url):
    return llamar("abrir", url=validar_url(url))


def buscar(consulta):
    # DuckDuckGo (versión HTML): Google muestra un captcha al navegador automatizado
    return llamar("buscar", url="https://html.duckduckgo.com/html/?q=" + quote_plus(consulta))


def leer():
    return llamar("leer")


def preparar(accion, selector="", texto="", url=""):
    if accion not in {"clic", "escribir", "tecla", "atras", "abrir", "cerrar"}:
        raise ValueError("Acción de navegador desconocida.")
    if accion == "abrir":
        validar_url(url)
    if accion in {"clic", "escribir"} and not selector:
        raise ValueError("Falta el selector CSS del elemento.")
    return f"Navegador: {accion}\nSelector: {selector}\nTexto: {texto}\nURL: {url}", \
        lambda: llamar(accion, selector=selector, texto=texto, url=url)


def servir():
    import fcntl
    from playwright.sync_api import sync_playwright
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (RUNTIME / "servidor.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        SOCKET.unlink(missing_ok=True)
        with sync_playwright() as pw:
            perfil = BASE / "perfil"
            perfil.mkdir(mode=0o700, parents=True, exist_ok=True)
            estado = {"cerrado": True, "visible": False}

            def lanzar(visible=False):
                # Navegador normal con ventana, pero Hyprland la manda al scratchpad oculto special:agente
                # (regla en modulos/scratchpads.lua). «mostrar» lo saca a la vista.
                # Si cierras la ventana, la siguiente petición vuelve a abrirlo, oculto.
                c = pw.chromium.launch_persistent_context(str(perfil), headless=False, args=["--class=" + CLASE],
                        accept_downloads=False, viewport={"width": 1200, "height": 800})
                estado.update(cerrado=False, visible=visible)
                c.on("close", lambda _: estado.update(cerrado=True))
                return c

            contexto = lanzar()
            pagina = contexto.pages[0] if contexto.pages else contexto.new_page()
            pagina.set_default_timeout(12000)
            with socket.socket(socket.AF_UNIX) as servidor:
                servidor.bind(str(SOCKET))
                os.chmod(SOCKET, 0o600)
                servidor.listen(8)
                servidor.settimeout(INACTIVO)
                try:
                    while True:
                        try:
                            conn, _ = servidor.accept()
                        except TimeoutError:   # sin usar un rato: se cierra y libera la RAM
                            break
                        with conn:
                            conn.settimeout(60)
                            try:
                                with conn.makefile("rb") as f:
                                    d = json.loads(f.readline(100000))
                                a = d["accion"]
                                if a == "cerrar":
                                    conn.sendall(b'{"resultado":"Navegador cerrado."}\n')
                                    break
                                if a == "mostrar":   # pasar a ventana visible, en la misma página
                                    url = d.get("url") or ("" if estado["cerrado"] or not contexto.pages else contexto.pages[-1].url)
                                    if estado["cerrado"]:
                                        contexto = lanzar()
                                    subprocess.run(["hyprctl", "eval", 'hl.dispatch(hl.dsp.workspace.toggle_special("agente"))'],
                                                   capture_output=True, timeout=5)
                                    a, d["url"] = "abrir", (url if url.startswith("http") else "https://duckduckgo.com/")
                                if estado["cerrado"]:
                                    if a == "leer":
                                        raise ValueError("El navegador está cerrado: abre primero una página.")
                                    contexto = lanzar()
                                if contexto.pages:
                                    pagina = contexto.pages[-1]
                                else:
                                    pagina = contexto.new_page()
                                    pagina.set_default_timeout(12000)
                                if pagina.is_closed():
                                    pagina = contexto.new_page()
                                    pagina.set_default_timeout(12000)
                                if a == "buscar":
                                    pagina.goto(validar_url(d["url"]), wait_until="domcontentloaded", timeout=45000)
                                    res = pagina.locator(".result").evaluate_all("""els => els.slice(0, 8).map(el => {
                                        const a = el.querySelector('.result__a'), s = el.querySelector('.result__snippet');
                                        let url = a ? a.href : '';
                                        try { const u = new URL(url); if (u.searchParams.get('uddg')) url = u.searchParams.get('uddg'); } catch (e) {}
                                        return (a ? a.innerText.trim() : '') + '\\n' + url + '\\n' + (s ? s.innerText.trim() : '');
                                    })""")
                                    respuesta = {"resultado": "\n\n".join(res) or "Sin resultados."}
                                    conn.sendall(json.dumps(respuesta, ensure_ascii=False).encode() + b"\n")
                                    continue
                                if a == "abrir":
                                    pagina.goto(validar_url(d["url"]), wait_until="domcontentloaded", timeout=45000)
                                elif a == "clic":
                                    pagina.locator(d["selector"]).click()
                                elif a == "escribir":
                                    pagina.locator(d["selector"]).fill(d["texto"])
                                elif a == "tecla":
                                    pagina.keyboard.press(d["texto"])
                                elif a == "atras":
                                    pagina.go_back(wait_until="domcontentloaded")
                                elif a != "leer":
                                    raise ValueError("Acción desconocida.")
                                resultado = f"URL: {pagina.url}\nTítulo: {pagina.title()}\n" + pagina.locator("body").inner_text()[:3000]
                                # Selectores reales para las siguientes acciones del modelo.
                                elementos = pagina.locator("a, button, input, textarea, select").evaluate_all("""els => els.filter(el => el.getClientRects().length).slice(0, 30).map(el => ({
                                    selector: el.id ? '#' + CSS.escape(el.id) : (() => {
                                        let p = [], n = el;
                                        while (n && n.tagName !== 'BODY') {
                                            const tag = n.tagName.toLowerCase();
                                            const sib = [...n.parentElement.children].filter(x => x.tagName === n.tagName);
                                            p.unshift(tag + ':nth-of-type(' + (sib.indexOf(n) + 1) + ')'); n = n.parentElement;
                                        } return 'body > ' + p.join(' > ');
                                    })(),
                                    texto: (el.innerText || el.getAttribute('aria-label') || el.getAttribute('placeholder') || '').slice(0, 100),
                                    href: el.getAttribute('href')
                                }))""")
                                resultado += "\nElementos: " + json.dumps(elementos, ensure_ascii=False)
                                respuesta = {"resultado": resultado[:18000]}
                            except Exception as e:
                                respuesta = {"error": str(e)[:1000]}
                            conn.sendall(json.dumps(respuesta, ensure_ascii=False).encode() + b"\n")
                finally:
                    if not estado["cerrado"]:
                        contexto.close()
                    SOCKET.unlink(missing_ok=True)


if __name__ == "__main__":
    if sys.argv[1:] == ["servir"]:
        servir()
    elif sys.argv[1:2] == ["mostrar"]:   # botón «Navegador» del panel: muestra/oculta su scratchpad
        print(llamar("mostrar", url=validar_url(sys.argv[2]) if len(sys.argv) > 2 else "")[:200])
