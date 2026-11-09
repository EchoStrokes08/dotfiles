#!/usr/bin/env python3
"""Servicio de dictado: tiene el modelo Whisper cargado en memoria y transcribe los audios que le manden.

Lo arranca dictado.sh al empezar a grabar (así el modelo se carga MIENTRAS hablas) y se cierra solo
tras 10 min sin uso, para no ocupar RAM. Todo en local: el audio no sale del equipo.

    dictado.py servir              el servicio (escucha en $XDG_RUNTIME_DIR/dictado.sock)
    dictado.py transcribir ARCHIVO pide la transcripción al servicio y la imprime

Modelo: ~/.config/dictado/modelo  (base = rápido, ~2 s · small = más preciso, ~6 s · por defecto base)
"""
import os, socket, sys, threading, time, warnings

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
SOCK = os.path.join(RUN, "dictado.sock")
INACTIVO = 600  # s sin uso → se cierra


def modelo_elegido():
    try:
        with open(os.path.expanduser("~/.config/dictado/modelo")) as f:
            return f.read().strip() or "base"
    except OSError:
        return "base"


def servir():
    warnings.filterwarnings("ignore")
    if os.path.exists(SOCK):
        try:  # ¿ya hay otro sirviendo?
            s = socket.socket(socket.AF_UNIX); s.connect(SOCK); s.close(); return
        except OSError:
            os.unlink(SOCK)
    srv = socket.socket(socket.AF_UNIX)
    srv.bind(SOCK)          # primero el socket: el cliente ya puede conectar y esperar a que cargue
    srv.listen(4)
    import whisper
    modelo = whisper.load_model(modelo_elegido())
    ultimo = [time.time()]

    def vigilar():
        while time.time() - ultimo[0] < INACTIVO:
            time.sleep(15)
        os.unlink(SOCK); os._exit(0)
    threading.Thread(target=vigilar, daemon=True).start()

    while True:
        con, _ = srv.accept()
        with con:
            ruta = con.recv(4096).decode().strip()
            ultimo[0] = time.time()
            try:
                r = modelo.transcribe(
                    ruta, language="es", fp16=False, condition_on_previous_text=False,
                    # una frase de ejemplo con puntuación hace que Whisper escriba con puntos y tildes
                    initial_prompt="Hola, ¿qué tal? Esto es un dictado en español, con puntuación correcta.")
                texto = r["text"].strip()
            except Exception as e:  # noqa: BLE001
                texto = f"\0error: {e}"
            con.sendall(texto.encode())
            ultimo[0] = time.time()


def transcribir(ruta):
    for _ in range(600):  # hasta 60 s esperando a que el servicio exista (la primera carga)
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(SOCK); break
        except OSError:
            time.sleep(0.1)
    else:
        sys.exit("el servicio de dictado no arrancó")
    s.sendall(os.path.abspath(ruta).encode())
    s.shutdown(socket.SHUT_WR)
    datos = b"".join(iter(lambda: s.recv(65536), b""))
    print(datos.decode(), end="")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "servir":
        servir()
    elif len(sys.argv) >= 3 and sys.argv[1] == "transcribir":
        transcribir(sys.argv[2])
    else:
        print(__doc__); sys.exit(1)
