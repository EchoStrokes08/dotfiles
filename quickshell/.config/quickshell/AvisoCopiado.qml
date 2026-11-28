// AvisoCopiado: al copiar algo, la isla lo enseña un instante («Copiado · “texto…”»).
//   texto → las primeras palabras · enlace → su dominio · imagen → «Imagen copiada» · archivos → cuántos
//   contraseñas (aviso de KeePassXC/Bitwarden o una sola «palabra» con pinta de clave) → «••••••»
//   con la privacidad activa → solo «Copiado»
// Escucha con `wl-paste --watch` (un proceso, sin sondeos). No dice nada del contenido que ya había al arrancar.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: a
    property real arranque: Date.now()

    Process {
        id: vigia
        running: true
        // Por cada cambio: «tipos<TAB>principio del texto» en una línea
        command: ["wl-paste", "--watch", "sh", "-c",
            'T=$(wl-paste --list-types 2>/dev/null | tr "\\n" " "); ' +
            'case "$T" in *text/uri-list*|*image*) printf "%s\\t\\n" "$T"; cat >/dev/null ;; ' +
            '*) printf "%s\\t" "$T"; head -c 240 | tr "\\n\\t\\r" "   "; echo ;; esac'];
        stdout: SplitParser { onRead: l => a.copiado(l) }
        onExited: reintentar.restart()
    }
    Timer { id: reintentar; interval: 5000; onTriggered: vigia.running = true }

    function pareceClave(t) {
        if (t.length < 8 || t.length > 64 || /\s/.test(t) || /^(https?:|www\.|\/|~)/.test(t)) return false;
        const clases = [/[a-z]/, /[A-Z]/, /\d/, /[^A-Za-z0-9]/].filter(r => r.test(t)).length;
        return clases >= 3;
    }

    function copiado(l) {
        if (Date.now() - arranque < 1500) return;
        const i = l.indexOf("\t");
        const tipos = i >= 0 ? l.slice(0, i) : l;
        const texto = (i >= 0 ? l.slice(i + 1) : "").trim().replace(/\s+/g, " ");
        const g = cp => String.fromCodePoint(cp);
        if (tipos.trim() === "") return;
        if (EstadoEscritorio.privacidad) { Isla.mostrar(g(0xF018F), -1, "Copiado"); return; }
        if (/passwordManagerHint|x-kde-passwordManager/.test(tipos) || pareceClave(texto)) {
            Isla.mostrar(g(0xF0306), -1, "Copiado · ••••••"); return;
        }
        if (tipos.includes("image") && !tipos.includes("text/uri-list")) { Isla.mostrar(g(0xF02E9), -1, "Imagen copiada"); return; }
        if (tipos.includes("text/uri-list")) { Isla.mostrar(g(0xF0214), -1, "Archivos copiados"); return; }
        if (texto === "") return;
        const url = /^https?:\/\/([^\/\s?#]+)/.exec(texto);
        if (url) { Isla.mostrar(g(0xF0337), -1, "Enlace copiado · " + url[1].replace(/^www\./, "")); return; }
        Isla.mostrar(g(0xF018F), -1, "Copiado · “" + (texto.length > 42 ? texto.slice(0, 40).trim() + "…" : texto) + "”");
    }
}
