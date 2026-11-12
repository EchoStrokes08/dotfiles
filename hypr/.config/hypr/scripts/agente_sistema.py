"""Herramientas generales del agente; preparar nunca ejecuta la acción."""
import os
from pathlib import Path
import shlex
import signal
import subprocess
import tempfile

HOME = Path.home()
LECTURA = {"pwd", "ls", "cat", "head", "tail", "wc", "stat", "df", "du", "free", "uname", "uptime", "whoami", "id"}


def ruta_personal(ruta):
    p = Path(ruta).expanduser().resolve()
    # Configuración y ejecutables pueden cambiar el sistema al siguiente inicio.
    if not p.is_relative_to(HOME) or p == HOME:
        return False
    partes = p.relative_to(HOME).parts
    return not any(x.startswith(".") for x in partes) and partes[0] not in {"dotfiles", "bin"}


def comando_automatico(argumentos):
    # Sin shell: no hay pipes, redirecciones, sustituciones ni evaluación de código.
    return bool(argumentos) and argumentos[0] in LECTURA and all(isinstance(a, str) for a in argumentos)


# ── niveles de permiso «amplio» y «total» ─────────────────────────────────
# Administrador: siempre se confirma (y pide la contraseña en una terminal).
ADMIN = {"sudo", "pkexec", "doas", "su", "run0", "pacman", "yay", "paru", "makepkg", "mount", "umount", "passwd"}
# Destructivo, irreversible o que puede ejecutar cualquier cosa por dentro: «amplio» lo confirma.
PELIGROSOS = {"rm", "rmdir", "shred", "dd", "truncate", "wipefs", "fdisk", "parted", "mkswap",
              "shutdown", "reboot", "poweroff", "halt", "kill", "pkill", "killall", "crontab", "chown", "chattr",
              "bash", "sh", "zsh", "fish", "dash", "python", "python3", "perl", "ruby", "node", "lua", "env", "xargs",
              "eval", "exec", "nohup", "setsid", "ssh", "scp", "rsync", "nc", "ncat", "socat", "kdeconnect-cli"}
# Subórdenes peligrosas de comandos por lo demás normales
PELIGROSAS_SUB = {"systemctl": {"poweroff", "reboot", "halt", "suspend", "hibernate", "disable", "mask", "stop", "kill", "isolate"},
                  "git": {"push", "reset", "clean", "rebase", "filter-branch", "gc"},
                  "flatpak": {"uninstall", "remove", "repair"},
                  "hyprctl": {"kill"}, "loginctl": {"terminate-session", "terminate-user", "kill-session"}}
# Opciones que envían datos fuera o borran: subir con curl/wget, borrar con find…
OPCIONES_PELIGROSAS = {"-d", "--data", "--data-binary", "--data-raw", "-F", "--form", "-T", "--upload-file",
                       "--post-data", "--post-file", "-delete", "-exec", "-execdir", "-ok", "--delete", "-X", "--request"}


def _nombre(a):
    return Path(a).name


def es_admin(argumentos):
    return bool(argumentos) and _nombre(argumentos[0]) in ADMIN


def es_peligroso(argumentos):
    if not argumentos:
        return True
    cmd = _nombre(argumentos[0])
    if cmd in ADMIN or cmd in PELIGROSOS or cmd.startswith(("mkfs", "python")):
        return True
    if any(a in PELIGROSAS_SUB.get(cmd, ()) for a in argumentos[1:]):
        return True
    if cmd in {"mv", "cp", "ln", "chmod", "tee", "install"} and any(ruta_sensible(a) for a in argumentos[1:] if not a.startswith("-")):
        return True
    if cmd == "sed" and any(a.startswith("-i") for a in argumentos[1:]):
        return any(ruta_sensible(a) for a in argumentos[1:] if not a.startswith("-"))
    return any(a in OPCIONES_PELIGROSAS for a in argumentos[1:] if cmd in {"curl", "wget", "find", "fd", "rsync"})


# Rutas que ejecutan código al iniciar sesión, guardan secretos o son del sistema
SENSIBLES = [".ssh", ".gnupg", ".zshrc", ".zshenv", ".zprofile", ".bashrc", ".bash_profile", ".profile",
             ".config/autostart", ".config/systemd", ".config/environment.d", ".config/hypr", ".config/ia",
             ".local/share/brujula/claves", ".local/bin", "bin", ".mozilla", ".pki", ".password-store"]


def ruta_sensible(ruta):
    try:
        p = Path(ruta).expanduser().resolve()
    except (OSError, RuntimeError):
        return True
    if not p.is_relative_to(HOME):
        return True
    rel = p.relative_to(HOME)
    # dotfiles: los enlaces de ~/.config apuntan aquí, así que se protege igual que el destino
    if rel.parts[:1] == ("dotfiles",):
        return True
    return any(rel == Path(s) or rel.is_relative_to(s) for s in SENSIBLES)


def preparar_comando(argumentos, directorio=None):
    if not isinstance(argumentos, list) or not argumentos or not all(isinstance(a, str) and "\0" not in a for a in argumentos):
        raise ValueError("Usa una lista de argumentos, sin shell.")
    cwd = Path(directorio or HOME).expanduser().resolve()
    if not cwd.is_dir():
        raise ValueError("El directorio no existe.")
    def hacer():
        # Archivo temporal: un comando con mucha salida no agota la RAM.
        with tempfile.TemporaryFile() as salida:
            p = subprocess.Popen(argumentos, cwd=cwd, stdin=subprocess.DEVNULL,
                                 stdout=salida, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                p.wait(timeout=90)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid, signal.SIGKILL)
                p.wait()
                raise ValueError("Comando detenido al superar 90 segundos.")
            salida.seek(0)
            texto = salida.read(16000).decode(errors="replace")
        return f"Código de salida: {p.returncode}\n{texto}"
    return f"Ejecutar en {cwd}:\n{shlex.join(argumentos)}", hacer


def leer_archivo(ruta):
    with Path(ruta).expanduser().open() as f:
        return f.read(16000)


def preparar_escritura(ruta, contenido):
    p = Path(ruta).expanduser().resolve()
    if not isinstance(contenido, str) or len(contenido) > 100000:
        raise ValueError("El contenido debe ser texto de hasta 100 000 caracteres.")
    def hacer():
        p.parent.mkdir(parents=True, exist_ok=True)
        copia = None
        if p.exists():
            import shutil
            fd, nombre = tempfile.mkstemp(prefix=p.name + ".", dir=_respaldos())
            os.close(fd)
            copia = Path(nombre)
            shutil.copy2(p, copia)
        # No sustituir enlaces: se muestra y escribe el destino resuelto.
        p.write_text(contenido)
        return f"Guardado {p}." + (f" Copia anterior: {copia}" if copia else "")
    return f"Escribir {p} ({len(contenido)} caracteres):\n{contenido}", hacer


def _respaldos():
    p = HOME / ".local/state/brujula/agente/respaldos"
    p.mkdir(mode=0o700, parents=True, exist_ok=True)
    return p
