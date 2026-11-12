// Lanzador (SUPER+R): apps y mucho más, todo con la misma lista.
//   firefox            apps (sin tildes, letras salteadas: «ffx») + acciones del sistema (apagar, atajos, OCR…)
//   2*(3+4) · 5 km a mi · 100 USD a COP · 30 °C a °F      calculadora y conversor (qalc) → Enter copia
//   g método simplex · yt … · w … · gh …                   buscar en Google / YouTube / Wikipedia / GitHub
//   :fuego · :sigma · :≤                                   emojis y símbolos → Enter los escribe
//   /apuntes   (solo «/» = recientes)                      archivos de tu carpeta personal → Enter los abre
//   recordar 20m entregar el taller · recordar 18:30 …     recordatorio (ver Recordatorios.qml)
//   v texto   ventanas abiertas → ir a ella          n texto   buscar en tus notas → abrir en esa línea
//   c texto   historial del portapapeles → copiar    t texto   pestañas abiertas de Firefox
//   p nombre  contraseñas (Bitwarden/pass) → escribirla donde esté el cursor
//   ia pregunta   asistente local (ollama)           nota texto   apuntar una línea en notas.md
//   d texto   DENTRO de PDF, Word y apuntes          h texto   historial de Firefox
//   a texto   atajos de teclado                      l texto   línea de tiempo (dónde viste algo y cuándo)
//   s texto   ajustes: «s claro», «s lectura», «s regla programar»… → Enter lo aplica
//   b texto   todo a la vez. Sin prefijo, con 3+ letras, también salen debajo de las apps (búsqueda universal)
//   (v, n, c, t, p, d, h, a, l y b los resuelve ~/.config/hypr/scripts/buscar.py)
// Teclas: ↑↓ / Tab moverse · Enter elegir · Esc o clic fuera cierra.
// Las apps que más abres suben (contador en ~/.local/state/quickshell/lanzador.json).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: ventana

    property bool abierto: false
    property bool mostrar: false
    property var usos: ({})              // { "firefox.desktop": 12, … }

    onAbiertoChanged: {
        if (abierto) {
            cierre.stop(); mostrar = true;
            buscador.text = "";
            lista.currentIndex = 0;
            buscador.forceActiveFocus();
            recientes.reload();
        } else cierre.restart();
    }
    Timer { id: cierre; interval: 220; onTriggered: ventana.mostrar = false }

    function abrirCon(t) { abierto = true; buscador.text = t; }        // qs ipc call lanzador buscar …
    function lanzarPrimero(t) { buscador.text = t; elegir(resultados[0]); }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-lanzador"
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function g(cp) { return String.fromCodePoint(cp); }

    // ── Contador de usos (persistente) ──────────────────────────────────
    readonly property string rutaUsos: Quickshell.env("HOME") + "/.local/state/quickshell/lanzador.json"
    FileView {
        id: archivoUsos
        path: ventana.rutaUsos
        onLoaded: { try { ventana.usos = JSON.parse(text()); } catch (e) { ventana.usos = {}; } }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"])

    // ── Utilidades de búsqueda ──────────────────────────────────────────
    function normalizar(s) { return (s ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }
    function salteado(q, t) {   // ¿están las letras de q en orden dentro de t? → puntaje (0 = no)
        let i = 0, huecos = 0, ultimo = -1;
        for (let j = 0; j < t.length && i < q.length; j++) {
            if (t[j] === q[i]) { if (ultimo >= 0) huecos += j - ultimo - 1; ultimo = j; i++; }
        }
        return i === q.length ? Math.max(1, 25 - huecos) : 0;
    }
    function puntajeApp(app, q) {
        const nombre = normalizar(app.name);
        if (q === "") return 1;
        if (nombre.startsWith(q)) return 100;
        if (nombre.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 80;
        if (nombre.includes(q)) return 60;
        const otros = [app.genericName, ...(app.keywords ?? []), app.id].map(normalizar);
        if (otros.some(t => t.startsWith(q))) return 45;
        if (otros.some(t => t.includes(q))) return 35;
        if (normalizar(app.comment).includes(q)) return 15;
        return salteado(q, nombre);
    }

    // ── Acciones del sistema (salen al buscar su nombre o una palabra clave) ──
    readonly property string scripts: "~/.config/hypr/scripts/"
    readonly property var acciones: [
        { n: "Atajos de teclado",       d: "Chuleta con todos los atajos · SUPER+H",       i: 0xF030C, k: "chuleta ayuda teclas", c: "qs ipc call chuleta toggle" },
        { n: "Bloquear",                d: "Bloquear la pantalla · SUPER+L",               i: 0xF033E, k: "lock",                 c: "loginctl lock-session" },
        { n: "Suspender",               d: "Dormir el equipo",                             i: 0xF04B2, k: "dormir sleep",         c: "systemctl suspend" },
        { n: "Reiniciar",               d: "Reiniciar el equipo",                          i: 0xF0709, k: "reboot",               c: "systemctl reboot" },
        { n: "Apagar",                  d: "Apagar el equipo",                             i: 0xF0425, k: "poweroff shutdown",    c: "systemctl poweroff" },
        { n: "Cerrar sesión",           d: "Salir de Hyprland",                            i: 0xF0343, k: "logout salir",         c: "hyprctl dispatch 'hl.dsp.exit()'" },
        { n: "Wi-Fi y Bluetooth",       d: "Redes y dispositivos · SUPER+K",               i: 0xF0928, k: "red wifi bluetooth",   c: "qs ipc call conexiones toggle" },
        { n: "Centro de control",       d: "Volumen, botones rápidos, notificaciones · SUPER+N", i: 0xF0493, k: "notificaciones", c: "qs ipc call notificaciones toggle" },
        { n: "Vista general",           d: "Todas las ventanas en miniatura · SUPER+TAB arriba", i: 0xF0570, k: "overview ventanas", c: "qs ipc call vista toggle" },
        { n: "Copiar texto de la pantalla", d: "OCR de una zona · SUPER+SHIFT+X",          i: 0xF0EF1, k: "ocr leer texto",       c: scripts + "ocr.sh" },
        { n: "Dictar",                  d: "Escribir con la voz · SUPER+ALT+D",            i: 0xF036C, k: "voz dictado whisper",  c: scripts + "dictado.sh" },
        { n: "Traducir selección",      d: "Traducir el texto seleccionado · SUPER+ALT+T", i: 0xF05CA, k: "traductor translate",  c: scripts + "traducir.sh" },
        { n: "Grabar pantalla",         d: "Región, pantalla o GIF · SUPER+ALT+R",         i: 0xF044A, k: "video grabacion rec",  c: scripts + "grabar.sh" },
        { n: "Capturas",                d: "Menú de capturas · SHIFT+PRINT",               i: 0xF0E51, k: "screenshot",           c: scripts + "capturas.sh" },
        { n: "Selector de color",       d: "Copiar el color de un píxel · SUPER+SHIFT+C",  i: 0xF0266, k: "color picker hex",     c: scripts + "selector-color.sh" },
        { n: "Luz nocturna",            d: "Pantalla cálida sí/no · SUPER+ALT+N",          i: 0xF0594, k: "noche sunset",         c: scripts + "luz-nocturna.sh" },
        { n: "Continuar proyecto", d: "Próximo paso, recursos y aplicaciones guardadas · SUPER+CTRL+Enter", i: 0xF0E1B, k: "continuidad memoria proyecto retomar", c: "qs ipc call flujo abrir continuidad" },
        { n: "Organizar por tarea", d: "Previsualizar y aplicar un layout · SUPER+CTRL+O", i: 0xF03D8, k: "comparar programar investigar columnas ordenar", c: "qs ipc call flujo abrir organizar" },
        { n: "Acciones de selección", d: "Capturar texto y elegir qué hacer · SUPER+ALT+C", i: 0xF0394, k: "seleccion texto transformar resumir traducir", c: "~/.config/hypr/scripts/flujo.py abrir seleccion" },
        { n: "Mesa de trabajo", d: "Buscar, mover y aparcar ventanas · SUPER+ALT+ESPACIO", i: 0xF03D8, k: "premium ventanas aparcar organizar", c: "qs ipc call mesa abrir ventanas" },
        { n: "Plantillas de texto", d: "Textos reutilizables con fecha y hora · SUPER+CTRL+V", i: 0xF0394, k: "fragmentos snippets biblioteca copiar", c: "qs ipc call mesa abrir plantillas" },
        { n: "Reunión temporizada", d: "Privacidad, No molestar y suspensión pausada", i: 0xF0306, k: "presentacion reunion videollamada temporizador", c: "qs ipc call mesa abrir reunion" },
        { n: "Rutinas", d: "Aplicaciones, perfil y concentración en una acción", i: 0xF0E1B, k: "estudiar programar descansar preparar", c: "qs ipc call mesa abrir rutinas" },
        { n: "Centro del escritorio", d: "Perfiles, privacidad, checkpoints y diagnóstico · SUPER+CTRL+ESPACIO", i: 0xF03D8, k: "perfil sistema avanzado checkpoint diagnostico", c: "qs ipc call centroEscritorio toggle" },
        { n: "Modo juego",              d: "Sin efectos ni notificaciones · SUPER+SHIFT+G", i: 0xF0297, k: "game",                c: "hyprctl dispatch 'modo_juego.alternar() or hl.dsp.no_op()'" },
        { n: "Concentración",           d: "Temporizador con No molestar · SUPER+SHIFT+F", i: 0xF04FE, k: "pomodoro foco",        c: "qs ipc call menu concentracion" },
        { n: "Cambiar colores",         d: "Ayu ↔ colores del wallpaper · SUPER+SHIFT+T",  i: 0xF03D8, k: "tema paleta",          c: scripts + "tema.sh alternar" },
        { n: "Wallpapers",              d: "Elegir fondo · SUPER+SHIFT+W",                 i: 0xF0E09, k: "fondo",                c: "qs ipc call wallpapers toggle" },
        { n: "Portapapeles",            d: "Historial · SUPER+SHIFT+V",                    i: 0xF0147, k: "clipboard historial",  c: "qs ipc call portapapeles toggle" },
        { n: "Buscar el móvil",         d: "Hacer sonar el móvil (KDE Connect)",           i: 0xF011C, k: "telefono celular kdeconnect", c: scripts + "movil.sh sonar" },
        { n: "KDE Connect",             d: "Emparejar el móvil, enviar archivos",           i: 0xF011C, k: "movil telefono celular android", c: scripts + "movil.sh app" },
        { n: "Sesiones de trabajo",     d: "Universidad, programar, descanso · SUPER+ALT+Enter", i: 0xF0E1B, k: "sesion contexto universidad programar", c: "hyprctl dispatch 'sesion.menu() or hl.dsp.no_op()'" },
        { n: "Asistente (IA)",          d: "Resumir, corregir, explicar o traducir lo seleccionado · SUPER+ALT+A", i: 0xF06A9, k: "ia inteligencia resumir corregir explicar ollama", c: scripts + "ia.sh" },
        { n: "Nota rápida",             d: "Apuntar una línea en notas.md · SUPER+SHIFT+O", i: 0xF039A, k: "notas apuntar anotar",  c: "qs ipc call nota abrir" },
        { n: "Móvil",                   d: "Avisos y respuestas, música, archivos y mandos · SUPER+ALT+M", i: 0xF011C, k: "telefono celular enviar whatsapp responder notificaciones", c: scripts + "movil.sh menu" },
        { n: "Resumen del día",         d: "Clima, eventos, recordatorios y actualizaciones", i: 0xF05A8, k: "manana hoy agenda",    c: "qs ipc call resumen mostrar" },
        { n: "Actualizar el sistema",   d: "Con snapshot, noticias de Arch y revisión final", i: 0xF03D6, k: "update paquetes pacman yay seguro", c: scripts + "actualizaciones.sh instalar" },
        { n: "Deshacer la última actualización", d: "Devolver / a su snapshot anterior (snapper)", i: 0xF099B, k: "rollback volver snapshot actualizacion rota", c: scripts + "actualizaciones.sh deshacer" },
        { n: "Salud del sistema",       d: "Disco, batería, respaldo, snapshots, servicios…", i: 0xF05E0, k: "estado diagnostico smart temperatura disco bateria", c: "qs ipc call brujula abrir salud" },
        { n: "Reabrir ventana cerrada", d: "La última que cerraste, en su sitio · SUPER+SHIFT+Z", i: 0xF099B, k: "deshacer cerrar recuperar ventana", c: scripts + "brujula.py reabrir" },
        { n: "Cerrar el día",           d: "Guarda la sesión, silencia y baja la luz",       i: 0xF0594, k: "jornada fin dormir noche terminar", c: scripts + "brujula.py jornada cerrar" },
        { n: "Filtro de pantalla",      d: "Grises, papel, vivo, invertido · SUPER+ALT+S", i: 0xF03D8, k: "shader grises sepia",   c: "qs ipc call menu shaders" },
        { n: "Sonido de las bocinas",   d: "Perfil música / voz / sin efectos · SUPER+ALT+E", i: 0xF057E, k: "audio ecualizador easyeffects", c: scripts + "sonido.sh menu" },
        { n: "Brújula", d: "Tu día, línea de tiempo, contexto y sesión · SUPER+CTRL+B", i: 0xF018B, k: "hoy sugerencias asistente dia", c: "qs ipc call brujula abrir hoy" },
        { n: "Línea de tiempo", d: "Qué tuviste delante y cuándo", i: 0xF0954, k: "historial actividad timeline ayer", c: "qs ipc call brujula abrir linea" },
        { n: "Contexto automático", d: "Reglas que adaptan el escritorio a lo que haces", i: 0xF0493, k: "reglas automatico perfil adaptar", c: "qs ipc call brujula abrir contexto" },
        { n: "Restaurar sesión anterior", d: "Reabrir las apps de antes del reinicio en sus espacios", i: 0xF099B, k: "recuperar reabrir reinicio cuelgue", c: "qs ipc call brujula abrir sesion" },
        { n: "Copia de seguridad ahora", d: "Con el disco TOSHIBA conectado",              i: 0xF0E26, k: "respaldo backup",      c: "kitty -e sh -c 'respaldo ahora; read -p \"Enter para cerrar\" x'" }
    ]
    function puntajeAccion(a, q) {
        if (q.length < 2) return 0;
        const n = normalizar(a.n);
        if (n.startsWith(q)) return 90;
        if (n.split(/\s+/).some(w => w.startsWith(q))) return 70;
        if (normalizar(a.k).split(/\s+/).some(w => w.startsWith(q))) return 55;
        return 0;
    }

    // ── Emojis y símbolos ───────────────────────────────────────────────
    property var emojis: []           // [{ e, n }] de /usr/share/unicode/emoji/emoji-test.txt (nombres en inglés)
    FileView {
        path: "/usr/share/unicode/emoji/emoji-test.txt"
        onLoaded: {
            const res = [];
            for (const l of text().split("\n")) {
                const m = l.match(/; fully-qualified\s+#\s+(\S+)\s+E[\d.]+\s+(.+)$/);
                if (m && !/skin tone/.test(m[2])) res.push({ e: m[1], n: m[2] });
            }
            ventana.emojis = res;
        }
    }
    // palabras en español → nombre inglés del emoji (las más usadas)
    readonly property var esEmoji: ({ fuego: "fire", corazon: "red heart", risa: "face with tears of joy", reir: "rolling on the floor",
        llorar: "loudly crying", triste: "sad", feliz: "grinning", sonrisa: "smiling face", guino: "winking", beso: "kissing",
        enojado: "angry", pensar: "thinking", pensando: "thinking", ojos: "eyes", pulgar: "thumbs up", bien: "thumbs up", mal: "thumbs down",
        aplausos: "clapping", rezar: "folded hands", gracias: "folded hands", fiesta: "party", estrella: "star", sol: "sun", luna: "moon",
        cohete: "rocket", libro: "book", lapiz: "pencil", calendario: "calendar", reloj: "clock", dinero: "money", ok: "ok hand",
        musculo: "flexed biceps", calavera: "skull", fantasma: "ghost", perro: "dog face", gato: "cat face", flor: "flower",
        cafe: "hot beverage", pizza: "pizza", torta: "birthday cake", regalo: "gift", check: "check mark", cruz: "cross mark",
        alerta: "warning", bombilla: "light bulb", idea: "light bulb", computador: "laptop", telefono: "mobile phone",
        musica: "musical note", balon: "soccer ball", futbol: "soccer ball", colombia: "flag: colombia", trofeo: "trophy",
        cien: "hundred points", sudor: "sweat", frio: "cold face", calor: "hot face", dormir: "sleeping", vomito: "vomiting",
        mano: "waving hand", hola: "waving hand", saludo: "waving hand", chao: "waving hand", arcoiris: "rainbow", nube: "cloud",
        lluvia: "rain", rayo: "high voltage", nieve: "snowflake", casa: "house", carro: "automobile", escuela: "school" })
    readonly property var simbolos: [
        ["≤", "menor o igual"], ["≥", "mayor o igual"], ["≠", "distinto diferente"], ["≈", "aproximado"], ["±", "mas menos"],
        ["×", "por multiplicar"], ["÷", "dividir"], ["√", "raiz"], ["∞", "infinito"], ["∑", "sumatoria sigma mayuscula"],
        ["∏", "productoria"], ["∫", "integral"], ["∂", "derivada parcial"], ["∆", "delta mayuscula incremento"], ["∇", "nabla gradiente"],
        ["π", "pi"], ["σ", "sigma"], ["μ", "mu media"], ["λ", "lambda"], ["α", "alfa"], ["β", "beta"], ["γ", "gamma"],
        ["δ", "delta"], ["ε", "epsilon"], ["θ", "theta"], ["ρ", "rho"], ["φ", "phi fi"], ["ω", "omega"], ["Ω", "omega mayuscula ohmio"],
        ["°", "grado grados"], ["→", "flecha derecha"], ["←", "flecha izquierda"], ["⇒", "implica"], ["⇔", "si y solo si equivalente"],
        ["∈", "pertenece"], ["∉", "no pertenece"], ["⊂", "subconjunto"], ["⊆", "subconjunto igual"], ["∪", "union"], ["∩", "interseccion"],
        ["∅", "vacio conjunto"], ["∀", "para todo"], ["∃", "existe"], ["¬", "negacion no"], ["∧", "y logico and"], ["∨", "o logico or"],
        ["²", "al cuadrado"], ["³", "al cubo"], ["½", "medio"], ["¼", "cuarto"], ["€", "euro"], ["£", "libra"], ["©", "copyright"],
        ["®", "registrado"], ["™", "marca"], ["✓", "visto check"], ["✗", "equis"], ["•", "punto vineta"], ["…", "puntos suspensivos"],
        ["—", "raya guion largo"], ["«", "comillas abrir"], ["»", "comillas cerrar"], ["¿", "interrogacion abrir"], ["¡", "exclamacion abrir"]
    ]
    function buscarEmojis(q) {
        q = normalizar(q.trim());
        if (!q) return [];
        const res = [];
        for (const s of simbolos) if (s[0] === q || normalizar(s[1]).split(" ").some(w => w.startsWith(q))) res.push({ e: s[0], n: s[1] });
        const ingles = Object.keys(esEmoji).filter(k => k.startsWith(q)).map(k => esEmoji[k]);
        // puntaje: nombre exacto > empieza igual > contiene (así «:fuego» da 🔥 antes que ❤️‍🔥)
        const nota = n => {
            let p = 0;
            for (const t of [...ingles, q]) {
                if (n === t) p = Math.max(p, 100);
                else if (n.startsWith(t + " ") || n.startsWith(t)) p = Math.max(p, 60 - n.length / 10);
                else if (n.split(/[\s:-]+/).some(w => w.startsWith(t))) p = Math.max(p, 30 - n.length / 10);
                else if (t !== q && n.includes(t)) p = Math.max(p, 10);
            }
            return p;
        };
        const emo = emojis.map(x => ({ x: x, p: nota(x.n.toLowerCase()) })).filter(r => r.p > 0)
                          .sort((a, b) => b.p - a.p).slice(0, 40 - res.length).map(r => r.x);
        return [...res, ...emo];
    }

    // ── Calculadora (qalc) y archivos (fd): procesos asíncronos ─────────
    property string calcEntrada: ""
    property string calcResultado: ""
    Process {
        id: calc
        stdout: StdioCollector { onStreamFinished: ventana.calcResultado = this.text.trim().split("\n").pop() }
    }
    property var archivos: []
    Process {
        id: buscaArchivos
        stdout: StdioCollector {
            onStreamFinished: ventana.archivos = this.text.split("\n").filter(l => l).map(r => r.replace(/\/$/, ""))
        }
    }
    // Búsquedas que resuelve un script (buscar.py): ventanas, notas, portapapeles, pestañas y contraseñas
    readonly property var externosTipos: ({ v: ["ventanas", "Ventanas abiertas", 0xF05AF], n: ["notas", "Buscar en tus notas", 0xF039A],
                                            c: ["portapapeles", "Historial del portapapeles", 0xF0147], t: ["pestanas", "Pestañas de Firefox", 0xF0239],
                                            p: ["claves", "Contraseñas", 0xF030B], d: ["documentos", "Dentro de tus documentos", 0xF0219],
                                            h: ["historial", "Historial de Firefox", 0xF02DA], a: ["atajos", "Atajos de teclado", 0xF030C],
                                            l: ["linea", "Tu línea de tiempo", 0xF0954], b: ["todo", "Búsqueda universal", 0xF0349],
                                            s: ["ajustes", "Ajustes: aplicar una opción", 0xF0493] })
    property var externos: []
    property string externosDe: ""       // texto para el que valen los resultados
    Process {
        id: buscaExterno
        property string para: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try { ventana.externos = JSON.parse(this.text); } catch (e) { ventana.externos = []; }
                ventana.externosDe = buscaExterno.para;
            }
        }
    }
    // Búsqueda universal: con 3+ letras, documentos, historial, notas, línea de tiempo… debajo de las apps
    property var todos: []
    property string todosDe: ""
    Process {
        id: buscaTodo
        property string para: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try { ventana.todos = JSON.parse(this.text); } catch (e) { ventana.todos = []; }
                ventana.todosDe = buscaTodo.para;
            }
        }
    }
    FileView { id: recientes; path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel" }
    function listaRecientes() {
        const res = [], re = /<bookmark href="file:\/\/([^"]+)"[^>]*modified="([^"]+)"/g;
        let m; const t = recientes.text();
        while ((m = re.exec(t)) !== null) res.push({ ruta: decodeURIComponent(m[1]), fecha: m[2] });
        return res.sort((a, b) => b.fecha.localeCompare(a.fecha)).slice(0, 25).map(x => x.ruta);
    }
    Timer {
        id: espera; interval: 180
        onTriggered: {
            const t = buscador.text;
            if (ventana.modo === "calc") {
                // «5 km a mi» → «5 km to -mi» (el - pide un solo número, no «3 mi + 188 yd»)
                const expr = t.replace(/^=\s*/, "").replace(/\s+a\s+(\S+)\s*$/i, " to -$1").replace(/\s+en\s+(\S+)\s*$/i, " to -$1");
                calc.running = false; ventana.calcEntrada = t;
                calc.command = ["qalc", "-t", expr]; calc.running = true;
            } else if (ventana.modo === "externo") {
                const m = t.match(/^(\w+)\s+(.*)$/);
                buscaExterno.running = false; buscaExterno.para = t;
                buscaExterno.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/buscar.py", ventana.externosTipos[m[1].toLowerCase()][0], m[2]];
                buscaExterno.running = true;
            } else if (ventana.modo === "apps" && t.trim().length >= 3) {
                buscaTodo.running = false; buscaTodo.para = t;
                buscaTodo.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/buscar.py", "todo", t.trim()];
                buscaTodo.running = true;
            } else if (ventana.modo === "archivos" && t.length > 2) {
                buscaArchivos.running = false;
                buscaArchivos.command = ["fd", "-i", "--max-results", "40", "--exclude", ".cache", "--", t.slice(1).trim(), Quickshell.env("HOME")];
                buscaArchivos.running = true;
            }
        }
    }

    // ── Modo según lo escrito ───────────────────────────────────────────
    readonly property var webs: ({ g: ["Google", "https://www.google.com/search?q="], yt: ["YouTube", "https://www.youtube.com/results?search_query="],
                                   w: ["Wikipedia", "https://es.wikipedia.org/w/index.php?search="], gh: ["GitHub", "https://github.com/search?q="] })
    readonly property string modo: {
        const t = buscador.text;
        if (/^(recordar|rec)\s/i.test(t)) return "recordar";
        if (/^ia\s+\S/i.test(t)) return "ia";
        if (/^nota\s+\S/i.test(t)) return "nota";
        const pe = t.match(/^(\w+)\s/);
        if (pe && externosTipos[pe[1].toLowerCase()]) return "externo";
        if (t.startsWith(":")) return "emoji";
        if (t.startsWith("/")) return "archivos";
        const p = t.match(/^(\w+)\s+\S/);
        if (p && webs[p[1].toLowerCase()]) return "web";
        if (t.startsWith("=") || /^[\d(.\-√π]/.test(t.trim()) && /[\d)]/.test(t)) return "calc";
        return "apps";
    }
    onModoChanged: { calcResultado = ""; archivos = []; externos = []; todos = []; }
    Connections { target: buscador; function onTextChanged() { espera.restart(); } }

    // Cada resultado: { nombre, detalle, icono (nombre de icono de app) | glifo (código) | texto (emoji), accion() }
    readonly property var resultados: {
        const t = buscador.text, q = normalizar(t.trim());
        if (modo === "recordar") {
            const r = Recordatorios.interpretar(t.replace(/^(recordar|rec)\s+/i, ""));
            return r ? [{ nombre: r.texto, detalle: "Recordar " + Recordatorios.cuandoTexto(r.cuando), glifo: 0xF0020,
                          accion: () => { Recordatorios.agregar(r.cuando, r.texto);
                                          Quickshell.execDetached(["notify-send", "-a", "Recordatorio", "-u", "low",
                                              "Te lo recuerdo " + Recordatorios.cuandoTexto(r.cuando), r.texto]); } }]
                     : [{ nombre: "¿Cuándo?", detalle: "Ej.: recordar 20m beber agua · recordar 18:30 llamar · recordar mañana 7:00 examen", glifo: 0xF0020, accion: null }];
        }
        if (modo === "ia") {
            const pregunta = t.replace(/^ia\s+/i, "");
            return [{ nombre: pregunta, detalle: "Preguntar al asistente local (sin internet)", glifo: 0xF06A9,
                      accion: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/ia.sh", "preguntar", pregunta]) }];
        }
        if (modo === "nota") {
            const nota = t.replace(/^nota\s+/i, "");
            return [{ nombre: nota, detalle: "Apuntarlo en ~/Documents/notas.md", glifo: 0xF039A,
                      accion: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/nota.sh", nota]) }];
        }
        if (modo === "externo") {
            const tipo = externosTipos[t.match(/^(\w+)/)[1].toLowerCase()];
            if (externosDe !== t && externos.length === 0)
                return [{ nombre: tipo[1], detalle: "Buscando…", glifo: tipo[2], accion: null }];
            if (externos.length === 0)
                return [{ nombre: "Sin resultados", detalle: tipo[1], glifo: tipo[2], accion: null }];
            return externos.map(x => ({ nombre: x.nombre, detalle: x.detalle, glifo: x.glifo, grupo: x.grupo,
                                        accion: x.cmd && x.cmd.length ? () => Quickshell.execDetached(x.cmd) : null }));
        }
        if (modo === "emoji")
            return buscarEmojis(t.slice(1)).map(x => ({ nombre: x.n, detalle: "Enter: escribirlo (y queda copiado)", texto: x.e,
                accion: () => Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy; sleep 0.25; wtype "$1"', "_", x.e]) }));
        if (modo === "archivos") {
            const rutas = t.trim() === "/" ? listaRecientes() : archivos;
            const casa = Quickshell.env("HOME");
            return rutas.map(r => ({ nombre: r.split("/").pop(), detalle: (t.trim() === "/" ? "Reciente · " : "") + r.replace(casa, "~"),
                                     glifo: /\.[a-z0-9]{1,5}$/i.test(r) ? 0xF0214 : 0xF024B, accion: () => Quickshell.execDetached(["xdg-open", r]) }));
        }
        if (modo === "web") {
            const p = t.match(/^(\w+)\s+(.+)$/), w = webs[p[1].toLowerCase()];
            return [{ nombre: p[2], detalle: "Buscar en " + w[0], glifo: 0xF059F, accion: () => Quickshell.execDetached(["xdg-open", w[1] + encodeURIComponent(p[2])]) }];
        }
        const res = [];
        if (modo === "calc") {
            const ok = calcResultado && calcEntrada === t && !/^error|warning/i.test(calcResultado);
            res.push({ nombre: ok ? calcResultado : "…", detalle: ok ? "= " + t.replace(/^=\s*/, "") + "   ·   Enter: copiar el resultado" : "Calculando…",
                       glifo: 0xF00EC, accion: ok ? (r => () => Quickshell.execDetached(["wl-copy", r]))(calcResultado) : null });
            if (t.startsWith("=")) return res;
        }
        const apps = DesktopEntries.applications.values
            .map(app => ({ app: app, p: puntajeApp(app, q) })).filter(r => r.p > 0)
            .map(r => ({ app: r.app, p: r.p + Math.min(30, (usos[r.app.id] ?? 0) * 3) }));
        const accs = acciones.map(a => ({ a: a, p: puntajeAccion(a, q) })).filter(r => r.p > 0);
        const mezcla = [...apps.map(r => ({ p: r.p, item: { nombre: r.app.name, detalle: r.app.genericName || r.app.comment || "",
                                                            icono: r.app.icon, accion: () => lanzarApp(r.app) } })),
                        ...accs.map(r => ({ p: r.p, item: { nombre: r.a.n, detalle: r.a.d, glifo: r.a.i, accion: () => sh(r.a.c) } }))]
            .sort((a, b) => b.p - a.p || a.item.nombre.localeCompare(b.item.nombre)).slice(0, 40).map(x => x.item);
        // lo universal solo vale si es de lo que hay escrito ahora (no de una búsqueda anterior)
        const universal = (todosDe === t && q.length >= 3) ? todos : [];
        if (universal.length && mezcla.length) mezcla.forEach(x => x.grupo = "Apps y acciones");
        res.push(...mezcla);
        res.push(...universal.map(x => ({ nombre: x.nombre, detalle: x.detalle, glifo: x.glifo, grupo: x.grupo,
                                          accion: x.cmd && x.cmd.length ? () => Quickshell.execDetached(x.cmd) : null })));
        if (q && res.length === 0)   // nada: ofrecer buscarlo en internet
            res.push({ nombre: t.trim(), detalle: "Buscar en Google", glifo: 0xF059F,
                       accion: () => Quickshell.execDetached(["xdg-open", webs.g[1] + encodeURIComponent(t.trim())]) });
        return res;
    }

    function lanzarApp(app) {
        if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e", ...app.command]);
        else app.execute();
        const u = Object.assign({}, usos);
        u[app.id] = (u[app.id] ?? 0) + 1;
        usos = u;
        archivoUsos.setText(JSON.stringify(u, null, 1));
    }
    function elegir(r) {
        if (!r || !r.accion) return;
        abierto = false;
        r.accion();
    }

    // ── Velo + clic fuera ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: ventana.abierto ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: ventana.abierto = false }
    }

    // ── La tarjeta ──────────────────────────────────────────────────────
    Rectangle {
        id: tarjeta
        width: 600
        height: columna.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 + (ventana.abierto ? 0 : -12)
        opacity: ventana.abierto ? 1 : 0
        scale: ventana.abierto ? 1 : 0.98
        Behavior on y       { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale   { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        radius: 16
        color: Qt.alpha(Paleta.fondo, 0.90)
        border { width: 1; color: Qt.alpha(Paleta.naranja, 0.35) }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: columna
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // Campo de búsqueda
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 11
                color: Qt.alpha(Paleta.texto, 0.06)
                border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.naranja, 0.5) : "transparent" }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text {   // el icono cambia según el modo
                        text: ventana.g(({ apps: 0xF0349, calc: 0xF00EC, web: 0xF059F, emoji: 0xF0785, archivos: 0xF024B, recordar: 0xF0020, externo: 0xF0349, ia: 0xF06A9, nota: 0xF039A })[ventana.modo] ?? 0xF0349)
                        color: Paleta.naranja
                        font { family: Paleta.fuente; pixelSize: 15 }
                    }
                    TextInput {
                        id: buscador
                        Layout.fillWidth: true
                        color: Paleta.texto
                        selectionColor: Qt.alpha(Paleta.naranja, 0.4)
                        font { family: Paleta.fuente; pixelSize: 16 }
                        clip: true
                        onTextChanged: lista.currentIndex = 0

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: buscador.text === ""
                            text: "Apps, =cálculos, g web, :emoji, /archivos, recordar…"
                            color: Paleta.gris
                            font: buscador.font
                        }

                        Keys.onEscapePressed: ventana.abierto = false
                        Keys.onReturnPressed: ventana.elegir(ventana.resultados[lista.currentIndex])
                        Keys.onEnterPressed: ventana.elegir(ventana.resultados[lista.currentIndex])
                        Keys.onDownPressed: lista.incrementCurrentIndex()
                        Keys.onUpPressed: lista.decrementCurrentIndex()
                        Keys.onTabPressed: lista.incrementCurrentIndex()
                        Keys.onBacktabPressed: lista.decrementCurrentIndex()
                    }
                    Text {
                        text: ventana.resultados.length
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 11 }
                    }
                }
            }

            // Resultados
            ListView {
                id: lista
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 7 * 52 + 26)
                clip: true
                model: ventana.resultados
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: true
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                delegate: Item {
                    id: fila
                    required property var modelData
                    required property int index
                    // encabezado al empezar un grupo nuevo (búsqueda universal)
                    readonly property bool cabecera: !!modelData.grupo && (index === 0 || ventana.resultados[index - 1]?.grupo !== modelData.grupo)
                    readonly property bool actual: lista.currentIndex === index
                    width: lista.width
                    height: 52 + (cabecera ? 26 : 0)

                    Text {
                        visible: fila.cabecera
                        anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 8 }
                        text: (fila.modelData.grupo ?? "").toUpperCase()
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 52; radius: 10
                        color: Qt.alpha(Paleta.naranja, fila.actual ? 0.13 : 0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Rectangle {
                            visible: fila.actual
                            width: 3; height: parent.height - 18
                            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                            radius: 2
                            color: Paleta.naranja
                        }
                    }

                    RowLayout {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 12 }
                        height: 52
                        spacing: 12
                        Item {
                            implicitWidth: 30; implicitHeight: 30
                            IconImage {
                                anchors.fill: parent
                                visible: !!fila.modelData.icono
                                source: fila.modelData.icono ? Quickshell.iconPath(fila.modelData.icono, "application-x-executable") : ""
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !fila.modelData.icono
                                text: fila.modelData.texto ?? (fila.modelData.glifo ? ventana.g(fila.modelData.glifo) : "")
                                color: Paleta.naranja
                                font { family: fila.modelData.texto ? "Noto Color Emoji" : Paleta.fuente; pixelSize: fila.modelData.texto ? 22 : 20 }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0; Layout.preferredWidth: 1   // que el texto largo se corte, no estire la fila
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: fila.modelData.nombre
                                color: lista.currentIndex === fila.index ? Paleta.naranja : Paleta.texto
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 14; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: fila.modelData.detalle ?? ""
                                color: Paleta.gris
                                elide: Text.ElideMiddle
                                font { family: Paleta.fuente; pixelSize: 11 }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: lista.currentIndex = fila.index
                        onClicked: ventana.elegir(fila.modelData)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6; Layout.bottomMargin: 6
                visible: ventana.resultados.length === 0
                text: ventana.modo === "archivos" ? (buscador.text.length > 2 ? "Buscando…" : "Escribe el nombre del archivo")
                    : ventana.modo === "emoji" ? "Escribe: :fuego, :corazon, :sigma, :≤…" : "Nada coincide con «" + buscador.text + "»"
                color: Paleta.gris
                font { family: Paleta.fuente; pixelSize: 12; italic: true }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                lineHeight: 1.3
                text: "=calc  g/yt/w web  :emoji  /archivos  recordar  ·  v ventanas  n notas  c copiado  t pestañas  p claves  d documentos  h historial  a atajos  l línea  s ajustes  ·  ia …  nota …"
                color: Qt.alpha(Paleta.gris, 0.8)
                font { family: Paleta.fuente; pixelSize: 10 }
            }
        }
    }
}
