// Lanzador (SUPER+R): apps y mucho más, todo con la misma lista.
//   firefox            apps (sin tildes, letras salteadas: «ffx») + acciones del sistema (apagar, atajos, OCR…)
//   2*(3+4) · 5 km a mi · 100 USD a COP · 30 °C a °F      calculadora y conversor (qalc) → Enter copia
//   dolar hoy  (o «dólar», «trm», «usd»)                   TRM oficial de hoy + dólar y euro de mercado → Enter copia
//   g método simplex · yt … · w … · gh …                   buscar en Google / YouTube / Wikipedia / GitHub
//   :fuego · :sigma · :≤                                   emojis y símbolos → Enter los escribe
//   !texto                                                 avisos pasados (historial local, máx. 500) → Enter copia el texto
//   /apuntes   (solo «/» = recientes)                      archivos de tu carpeta personal → Enter los abre
//   recordar 20m entregar el taller · recordar 18:30 …     recordatorio (ver Recordatorios.qml)
//   evento mañana 15:00 dentista · tarea 20/11 informe     a tu Google Calendar / Tasks (ver Eventos.qml)
//   v texto   ventanas abiertas → ir a ella          n texto   buscar en tus notas → abrir en esa línea
//   c texto   historial del portapapeles → copiar    t texto   pestañas abiertas de Firefox
//   p nombre  contraseñas (Bitwarden/pass) → escribirla donde esté el cursor
//   ia pregunta   asistente local (ollama)           nota texto   apuntar una línea en notas.md
//   d texto   DENTRO de PDF, Word y apuntes          h texto   historial de Firefox
//   a texto   atajos de teclado                      l texto   línea de tiempo (dónde viste algo y cuándo)
//   s texto   ajustes: «s claro», «s lectura», «s regla programar»… → Enter lo aplica
//   b texto   todo a la vez. Sin prefijo, con 3+ letras, también salen debajo de las apps (búsqueda universal)
//   pl texto  plantillas de texto → Enter la copia con fecha y hora (también salen sin prefijo con 3+ letras)
//   el nombre de un proyecto (o «proyecto», «retomar») → Enter lo retoma: apps, espacios y siguiente paso
// Mesa y Flujo son modos del lanzador: proyectos, plantillas y rutinas salen aquí; sus paneles se abren
// con las acciones «Mesa de trabajo», «Guardar proyecto»…
//   (v, n, c, t, p, d, h, a, l y b los resuelve ~/.config/hypr/scripts/buscar.py)
// Teclas: ↑↓ / Tab moverse · Enter elegir · Esc o clic fuera cierra.
// Las apps que más abres suben (contador en ~/.local/state/quickshell/lanzador.json).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: ventana

    Connections { target: EstadoEscritorio; function onCapturaPrivadaChanged() { if(EstadoEscritorio.capturaPrivada) ventana.abierto=false; } }
    property bool abierto: false
    property bool mostrar: false
    property var accionPendiente: null
    property string avisoBusqueda: ""
    property var usos: ({})              // { "firefox.desktop": 12, … }
    property bool todosPrefijos: false   // chips: los 6 más usados o todos

    onAbiertoChanged: {
        if (abierto) {
            cierre.stop(); mostrar = true;
            buscador.text = "";
            contexto.referencia = null;
            todosPrefijos = false;
            lista.currentIndex = 0;
            buscador.forceActiveFocus();
            recientes.reload();
            historialAvisos.reload();
            if (!leerProyectos.running) leerProyectos.running = true;
            if (!leerPlantillas.running) leerPlantillas.running = true;
        } else if (EstiloPanel.movimiento) cierre.restart();
        else mostrar = false;
    }
    Timer { id: cierre; interval: EstiloPanel.normal; onTriggered: ventana.mostrar = false }

    function abrirCon(t) { abierto = true; buscador.text = t; }        // qs ipc call lanzador buscar …
    function lanzarPrimero(t) { buscador.text = t; elegir(resultados[0], true); }

    visible: mostrar
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-lanzador"
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }
    function g(cp) { return String.fromCodePoint(cp); }

    Connections {
        target: EstadoEscritorio
        function onPrivacidadChanged() {
            if (EstadoEscritorio.privacidad) {
                ventana.consultaId++;
                if (ventana.peticionActual) ventana.peticionActual.running=false;
                ventana.todos=[];ventana.externos=[];ventana.archivosTipados=[];
                contexto.referencia=null;
            }
        }
    }
    Connections { target: AccionesServicio; function onCompletada(r) { leerProyectos.running=true;leerPlantillas.running=true;Eventos.actualizar(); } }
    // ── Contador de usos (persistente) ──────────────────────────────────
    readonly property string rutaUsos: Quickshell.env("HOME") + "/.local/state/quickshell/lanzador.json"
    FileView {
        id: archivoUsos
        path: ventana.rutaUsos
        onLoaded: { try { ventana.usos = JSON.parse(text()); } catch (e) { ventana.usos = {}; } }
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"])

    // ── Proyectos (Flujo) y plantillas (Mesa): fuentes de resultados ─────
    readonly property string scriptsAbs: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    property var proyectos: []
    property var plantillas: []
    Process {
        id: leerProyectos
        command: [ventana.scriptsAbs + "flujo.py", "proyecto", "lista"]
        stdout: StdioCollector { onStreamFinished: { try { ventana.proyectos = JSON.parse(this.text).proyectos ?? []; } catch (e) {} } }
    }
    Process {
        id: leerPlantillas
        command: [ventana.scriptsAbs + "mesa.py", "plantilla", "lista"]
        stdout: StdioCollector { onStreamFinished: { try { ventana.plantillas = JSON.parse(this.text).plantillas ?? []; } catch (e) {} } }
    }
    function itemProyecto(pr) {
        return { referencia: {tipo:"proyecto",id:pr.id}, nombre: "Retomar «" + pr.nombre + "»", detalle: pr.siguiente ? "Siguiente: " + pr.siguiente : "Abre sus apps en sus espacios",
                 glifo: 0xF0E1B, accion: () => AccionesServicio.ejecutar({tipo:"proyecto",id:pr.id},"retomar") };
    }
    function itemPlantilla(pl) {
        return { referencia: {tipo:"plantilla",id:pl.id}, nombre: pl.titulo, detalle: "Plantilla · " + pl.texto.replace(/\s+/g, " ").slice(0, 90), glifo: 0xF0219,
                 accion: () => AccionesServicio.ejecutar({tipo:"plantilla",id:pl.id},"copiar") };
    }
    // Entradas que no son apps de verdad (ayudas, «acerca de»): no salen en la lista
    readonly property var excluidas: /(^|\s)(help|ayuda|about|acerca de)(\s|$)/i
    function visibleApp(app) { return !excluidas.test(app.name) && !(app.noDisplay ?? false); }

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
        { n: "Wi-Fi y Bluetooth",       d: "Centro de control › Conexiones",               i: 0xF0928, k: "red wifi bluetooth",   c: "qs ipc call conexiones toggle" },
        { n: "Centro de control",       d: "Ajustes rápidos, sonido, avisos, conexiones y móvil · SUPER+N", i: 0xF0493, k: "notificaciones", c: "qs ipc call notificaciones toggle" },
        { n: "Vista general",           d: "Todas las ventanas en miniatura · SUPER+ESPACIO", i: 0xF0570, k: "overview ventanas", c: "qs ipc call vista toggle" },
        { n: "Copiar texto de la pantalla", d: "OCR de una zona · SUPER+SHIFT+X",          i: 0xF0EF1, k: "ocr leer texto",       c: scripts + "ocr.sh" },
        { n: "Dictar",                  d: "Escribir con la voz · SUPER+ALT+D",            i: 0xF036C, k: "voz dictado whisper",  c: scripts + "dictado.sh" },
        { n: "Traducir selección",      d: "Traducir el texto seleccionado · SUPER+ALT+T", i: 0xF05CA, k: "traductor translate",  c: scripts + "traducir.sh" },
        { n: "Grabar pantalla",         d: "Región, pantalla o GIF · SUPER+ALT+R",         i: 0xF044A, k: "video grabacion rec",  c: scripts + "grabar.sh" },
        { n: "Captura con privacidad de ORION", d: "Oculta avisos, títulos y paneles personales de ORION durante la captura de una región", i: 0xF0E51, k: "captura privada screenshot", c: "python3 " + scripts + "captura_privada.py region" },
        { n: "Capturas",                d: "Menú de capturas · SHIFT+PRINT",               i: 0xF0E51, k: "screenshot",           c: scripts + "capturas.sh" },
        { n: "Selector de color",       d: "Copiar el color de un píxel · SUPER+SHIFT+C",  i: 0xF0266, k: "color picker hex",     c: scripts + "selector-color.sh" },
        { n: "Luz nocturna",            d: "Pantalla cálida sí/no · SUPER+ALT+N",          i: 0xF0594, k: "noche sunset",         c: scripts + "luz-nocturna.sh" },
        { n: "Continuar proyecto", d: "Próximo paso, recursos y aplicaciones guardadas · SUPER+CTRL+Enter", i: 0xF0E1B, k: "continuidad memoria proyecto retomar", consulta: "proyecto" },
        { n: "Organizar por tarea", d: "Previsualizar y aplicar un layout · SUPER+CTRL+O", i: 0xF03D8, k: "comparar programar investigar columnas ordenar", c: "qs ipc call flujo abrir organizar" },
        { n: "Acciones de selección", d: "Capturar texto y elegir qué hacer · SUPER+ALT+C", i: 0xF0219, k: "seleccion texto transformar resumir traducir", c: "~/.config/hypr/scripts/flujo.py abrir seleccion" },
        { n: "Ventanas", d: "Ir, mover a otro espacio, aparcar o cerrar · Alt+Enter en una ventana", i: 0xF03D8, k: "mesa trabajo ventanas aparcar mover", consulta: "v " },
        { n: "Plantillas de texto", d: "Textos reutilizables con fecha y hora · SUPER+CTRL+V", i: 0xF0219, k: "fragmentos snippets biblioteca copiar", consulta: "pl " },
        { n: "Reunión temporizada", d: "Privacidad, No molestar y suspensión pausada", i: 0xF0306, k: "presentacion reunion videollamada temporizador", c: "qs ipc call mesa abrir reunion" },
        { n: "Rutinas", d: "Editar qué apps abre cada rutina", i: 0xF0E1B, k: "estudiar programar descansar preparar editar", c: "qs ipc call mesa abrir rutinas" },
        { n: "Empezar a estudiar", d: "Rutina: apps de la universidad, perfil lectura y 25 min de concentración", i: 0xF0474, k: "rutina estudiar universidad clase", c: scripts + "mesa.py rutina estudiar" },
        { n: "Empezar a programar", d: "Rutina: apps de programar y 50 min de concentración", i: 0xF0169, k: "rutina programar codigo", c: scripts + "mesa.py rutina programar" },
        { n: "Empezar a descansar", d: "Rutina: apps de descanso", i: 0xF04B2, k: "rutina descansar descanso pausa", c: scripts + "mesa.py rutina descansar" },
        { n: "Guardar proyecto", d: "Guardar las apps abiertas y el siguiente paso para retomarlo luego", i: 0xF0193, k: "proyecto guardar continuidad memoria", ref: {tipo:"proyecto",id:""} },
        { n: "Perfiles y privacidad", d: "Centro de control › Más: checkpoints, privacidad, diagnóstico y replay", i: 0xF03D8, k: "perfil sistema avanzado checkpoint diagnostico", c: "qs ipc call centroEscritorio toggle" },
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
        { n: "Móvil",                   d: "Centro de control › Móvil: batería, archivos, avisos", i: 0xF011C, k: "telefono celular enviar whatsapp responder notificaciones", c: scripts + "movil.sh menu" },
        { n: "Resumen del día",         d: "Brújula › Hoy: clima, agenda, recordatorios y sistema", i: 0xF05A8, k: "manana hoy agenda",    c: "qs ipc call resumen mostrar" },
        { n: "Tu día",                  d: "Tu día contado en tarjetas: apps, ritmo, racha, música y más", i: 0xF0954, k: "resumen dia wrapped historias", c: "qs ipc call tudia mostrar" },
        { n: "Máquina del tiempo",      d: "Viaja por los momentos de tu día y vuelve a abrir lo que usabas", i: 0xF02DA, k: "historial atras pasado volver timeline viajar", c: "qs ipc call maquina abrir" },
        { n: "Letras en modo cine",     d: "Lo que suena a pantalla completa con la letra sincronizada · SUPER+SHIFT+Y", i: 0xF075A, k: "musica cancion karaoke letra lyrics spotify", c: "qs ipc call letras toggle" },
        { n: "Temporizador 5 min",      d: "Cuenta atrás en la isla; al acabar avisa con sonido", i: 0xF051B, k: "timer alarma cuenta atras te", c: "qs ipc call actividades temporizador 300 Temporizador" },
        { n: "Temporizador 25 min",     d: "Cuenta atrás en la isla; al acabar avisa con sonido", i: 0xF051B, k: "timer alarma cuenta atras pomodoro", c: "qs ipc call actividades temporizador 1500 Temporizador" },
        { n: "Cronómetro",              d: "Empieza o para un cronómetro en la isla", i: 0xF13AB, k: "stopwatch tiempo medir", c: "qs ipc call actividades cronometro" },
        { n: "Actualizar el sistema",   d: "Con snapshot, noticias de Arch y revisión final", i: 0xF03D6, k: "update paquetes pacman yay seguro", c: scripts + "actualizaciones.sh instalar" },
        { n: "Deshacer la última actualización", d: "Devolver / a su snapshot anterior (snapper)", i: 0xF099B, k: "rollback volver snapshot actualizacion rota", c: scripts + "actualizaciones.sh deshacer" },
        { n: "Almacenamiento", d: "Qué ocupa el SSD y cómo recuperar espacio sin romper nada", i: 0xF02CA, k: "disco ssd espacio limpiar cache papelera archivos grandes almacenamiento", c: "qs ipc call brujula abrir salud" },
        { n: "Memoria del agente", d: "Ver qué recuerda, olvidar fuentes, excluir dominios o carpetas, pausar", i: 0xF0DD9, k: "memoria agente olvidar excluir privacidad recuerdos indexado", c: "qs ipc call agente memoria" },
        { n: "Agente (asistente que actúa)", d: "Pregunta o pide lo que sea: agenda, memoria, ajustes, móvil… · SUPER+O", i: 0xF06A9, k: "oye asistente ia agente hablar preguntar memoria", c: "qs ipc call agente toggle" },
        { n: "Salud del sistema",       d: "Disco, batería, respaldo, snapshots, servicios…", i: 0xF05E0, k: "estado diagnostico smart temperatura disco bateria", c: "qs ipc call brujula abrir salud" },
        { n: "Reabrir ventana cerrada", d: "La última que cerraste, en su sitio · SUPER+SHIFT+Z", i: 0xF099B, k: "deshacer cerrar recuperar ventana", c: scripts + "brujula.py reabrir" },
        { n: "Cerrar el día",           d: "Guarda la sesión, silencia y baja la luz",       i: 0xF0594, k: "jornada fin dormir noche terminar", c: scripts + "brujula.py jornada cerrar" },
        { n: "Filtro de pantalla",      d: "Grises, papel, vivo, invertido · SUPER+ALT+S", i: 0xF03D8, k: "shader grises sepia",   c: "qs ipc call menu shaders" },
        { n: "Sonido de las bocinas",   d: "Perfil música / voz / sin efectos · SUPER+ALT+E", i: 0xF057E, k: "audio ecualizador easyeffects", c: scripts + "sonido.sh menu" },
        { n: "Brújula", d: "Tu día, línea de tiempo y salud del equipo · SUPER+D", i: 0xF018B, k: "hoy sugerencias asistente dia", c: "qs ipc call brujula abrir hoy" },
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
    FileView { id: historialAvisos; path: Notificaciones.archivoHistorial; printErrors: false }
    function buscarAvisos(q) {
        if (EstadoEscritorio.privacidad) return [{ nombre: "Historial oculto por privacidad", detalle: "Desactiva privacidad para consultar avisos pasados.", accion: null }];
        const filas = [];
        for (const l of (historialAvisos.text() || "").split("\n").reverse()) {
            if (!l.trim()) continue;
            try { filas.push(JSON.parse(l)); } catch (e) {}
            if (filas.length >= 500) break;
        }
        const hallados = filas.filter(a => !q || normalizar(a.app + " " + a.titulo + " " + a.cuerpo).includes(q)).slice(0, 40);
        if (!hallados.length) return [{ nombre: filas.length ? "Ningún aviso coincide" : "Aún no hay avisos guardados", detalle: "Se guardan los que llegan a partir de ahora (máx. 500)", glifo: 0xF009A, accion: null }];
        return hallados.map(a => ({ nombre: a.titulo || a.app, glifo: 0xF009A,
            detalle: a.app + " · " + new Date(a.t).toLocaleString(Qt.locale("es_ES"), "d MMM HH:mm") + (a.cuerpo ? " · " + a.cuerpo : ""),
            accion: () => Quickshell.execDetached(["wl-copy", (a.titulo ? a.titulo + "\n" : "") + a.cuerpo]) }));
    }
    FileView { id: recientes; path: Quickshell.env("HOME") + "/.local/share/recently-used.xbel" }
    function listaRecientes() {
        const res = [], re = /<bookmark href="file:\/\/([^"]+)"[^>]*modified="([^"]+)"/g;
        let m; const t = recientes.text();
        while ((m = re.exec(t)) !== null) res.push({ ruta: decodeURIComponent(m[1]), fecha: m[2] });
        return res.sort((a, b) => b.fecha.localeCompare(a.fecha)).slice(0, 25).map(x => x.ruta);
    }
    property int consultaId: 0
    property string resultadosBusquedaDe: ""
    property bool cargandoBusqueda: false
    property var peticionActual: null
    function buscarFuente(tipo, consulta, destino) {
        if (peticionActual) peticionActual.running=false;
        consultaId++;
        cargandoBusqueda=true; avisoBusqueda="";
        peticionActual=peticionBusqueda.createObject(ventana,{consulta:consulta,original:buscador.text,destino:destino,generacion:consultaId,command:["python3",scriptsAbs+"busqueda.py",tipo,consulta]});
        peticionActual.running=true;
    }
    Component {
        id: peticionBusqueda
        Process {
            id: peticion
            property string consulta: ""
            property string original: ""
            property string destino: ""
            property int generacion: 0
            property bool respondio: false
            stdout: SplitParser {
                onRead: (linea) => {
                    if (peticion.generacion !== ventana.consultaId || peticion.original !== buscador.text) return;
                    try {
                        const r=JSON.parse(linea);peticion.respondio=true;
                        ventana.resultadosBusquedaDe=peticion.original;
                        if (peticion.destino === "calc") { ventana.calcEntrada=peticion.original;ventana.calcResultado=r.resultados[0]?.nombre || ""; }
                        else if (peticion.destino === "todo") { ventana.todos=r.resultados;ventana.todosDe=peticion.original; }
                        else if (peticion.destino === "archivos") ventana.archivosTipados=r.resultados;
                        else { ventana.externos=r.resultados;ventana.externosDe=peticion.original; }
                        ventana.cargandoBusqueda=!!r.cargando;
                        ventana.avisoBusqueda=r.errores.join(" · ");
                    } catch(e) { ventana.avisoBusqueda="No se pudo leer una fuente de búsqueda."; }
                }
            }
            onExited: (codigo, estado) => {
                if (generacion === ventana.consultaId && original === buscador.text) {
                    ventana.cargandoBusqueda=false;
                    if (!respondio) ventana.avisoBusqueda="La búsqueda no respondió. Vuelve a escribir para reintentar.";
                    ventana.peticionActual=null;
                }
                Qt.callLater(() => peticion.destroy());
            }
        }
    }
    property var archivosTipados: []
    Timer {
        id: espera; interval: 180
        onTriggered: {
            const t=buscador.text;
            if (ventana.modo === "dolar") ventana.buscarFuente("dolar","","externo");
            else if (ventana.modo === "calc") {
                const expr=t.replace(/^=\s*/,"").replace(/\s+a\s+(\S+)\s*$/i," to -$1").replace(/\s+en\s+(\S+)\s*$/i," to -$1");
                ventana.buscarFuente("calc",expr,"calc");
            } else if (ventana.modo === "externo" && !EstadoEscritorio.privacidad) {
                const m=t.match(/^(\w+)\s+(.*)$/);if(m) ventana.buscarFuente(ventana.externosTipos[m[1].toLowerCase()][0],m[2],"externo");
            } else if (ventana.modo === "apps" && t.trim().length>=3 && !EstadoEscritorio.privacidad) ventana.buscarFuente("todo",t.trim(),"todo");
            else if (ventana.modo === "archivos" && t.length>2 && !EstadoEscritorio.privacidad) ventana.buscarFuente("archivos",t.slice(1).trim(),"archivos");
            else { if (ventana.peticionActual) ventana.peticionActual.running=false; ventana.consultaId++; ventana.cargandoBusqueda=false; }
        }
    }

    // ── Modo según lo escrito ───────────────────────────────────────────
    readonly property var webs: ({ g: ["Google", "https://www.google.com/search?q="], yt: ["YouTube", "https://www.youtube.com/results?search_query="],
                                   w: ["Wikipedia", "https://es.wikipedia.org/w/index.php?search="], gh: ["GitHub", "https://github.com/search?q="] })
    readonly property string modo: {
        const t = buscador.text;
        if (/^\s*(d[oó]lar(es)?|trm|usd)(\s+(de\s+)?hoy)?\s*$/i.test(t)) return "dolar";
        if (/^(recordar|rec)\s/i.test(t)) return "recordar";
        if (/^(evento|tarea)\s/i.test(t)) return "agenda";
        if (/^ia\s+\S/i.test(t)) return "ia";
        if (/^nota\s+\S/i.test(t)) return "nota";
        if (/^pl(\s|$)/i.test(t)) return "plantillas";
        const pe = t.match(/^(\w+)\s/);
        if (pe && externosTipos[pe[1].toLowerCase()]) return "externo";
        if (t.startsWith("!")) return "avisos";
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
        if (modo === "agenda") {
            const esTarea = /^tarea/i.test(t), r = Eventos.interpretar(t.replace(/^(evento|tarea)\s+/i, ""));
            if (!Eventos.conectado || Eventos.necesitaConectar)
                return [{ nombre: Eventos.conectado ? "Reconectar Google (la sesión caducó)" : "Conectar Google Calendar",
                          detalle: Eventos.conectado ? "Abre el navegador para volver a dar permiso" : "Necesario una vez para crear eventos y tareas", glifo: 0xF00F0,
                          accion: () => Eventos.conectar() }];
            if (!r)
                return [{ nombre: esTarea ? "¿Qué tarea?" : "¿Qué evento?", glifo: 0xF00F0, accion: null,
                          detalle: "Ej.: evento mañana 15:00 dentista · evento viernes clase · tarea 20/11 entregar informe" }];
            const cuando = Eventos.diaTexto(r.fecha) + (esTarea ? "" : r.hora ? " " + r.hora : " · todo el día");
            return [{ nombre: r.titulo, detalle: (esTarea ? "Tarea en Google · " : "Evento en Google Calendar · ") + cuando, glifo: 0xF00F0,
                      accion: () => esTarea ? Eventos.crearTarea(r.titulo, r.fecha) : Eventos.crearEvento(r.titulo, r.fecha, r.hora, 60) }];
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
        if (modo === "dolar") {
            if (externosDe !== t || externos.length === 0)
                return [{ nombre: externosDe === t && !cargandoBusqueda ? "Sin datos del dólar" : "Consultando el dólar…",
                          detalle: avisoBusqueda || "TRM oficial y tasas de mercado", glifo: 0xF01C1, accion: null }];
            return externos.map(x => ({ nombre: x.nombre, detalle: x.detalle, glifo: x.glifo,
                                        accion: x.cmd && x.cmd.length ? () => Quickshell.execDetached(x.cmd) : null }));
        }
        if (modo === "avisos") return buscarAvisos(normalizar(t.slice(1).trim()));
        if (EstadoEscritorio.privacidad && ["externo","archivos","plantillas"].includes(modo)) return [{nombre:"Detalles ocultos por privacidad",detalle:"Desactiva privacidad para consultar archivos, historial o textos personales.",accion:null}];
        if (modo === "externo") {
            // modo y texto pueden actualizarse en distinto orden al borrar: sin prefijo válido, aún no hay nada que mostrar
            const prefijo = t.match(/^(\w+)/);
            const tipo = prefijo && externosTipos[prefijo[1].toLowerCase()];
            if (!tipo) return [];
            if (externosDe !== t && externos.length === 0)
                return [{ nombre: tipo[1], detalle: "Buscando…", glifo: tipo[2], accion: null }];
            if (externos.length === 0)
                return [{ nombre: avisoBusqueda ? "Fuente no disponible" : cargandoBusqueda ? "Buscando…" : "Sin resultados", detalle: tipo[1], glifo: tipo[2], accion: null }];
            return externos.map(x => ({ nombre: x.nombre, detalle: x.detalle, glifo: x.glifo, grupo: x.grupo, referencia:x.referencia,
                                        accion: x.cmd && x.cmd.length ? () => ventana.ejecutarResultado(x) : null }));
        }
        if (modo === "plantillas") {
            const f = normalizar(t.replace(/^pl\s*/i, ""));
            const l = plantillas.filter(x => normalizar(x.titulo + " " + x.texto).includes(f)).map(itemPlantilla);
            l.unshift({nombre:"Crear plantilla",detalle:"Nombre y texto reutilizable",glifo:0xF0219,mantener:true,accion:() => contexto.abrir({tipo:"plantilla",id:""})});
            return l.length ? l : [{ nombre: plantillas.length ? "Ninguna plantilla coincide" : "Aún no tienes plantillas",
                                     detalle: "Crea una plantilla aquí", glifo: 0xF0219, mantener:true, accion: () => contexto.abrir({tipo:"plantilla",id:""}) }];
        }
        if (modo === "emoji")
            return buscarEmojis(t.slice(1)).map(x => ({ nombre: x.n, detalle: "Enter: escribirlo (y queda copiado)", texto: x.e,
                accion: () => Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy; sleep 0.25; wtype "$1"', "_", x.e]) }));
        if (modo === "archivos") {
            if (t.trim() !== "/") return archivosTipados.map(x => Object.assign({},x,{accion:() => ventana.ejecutarResultado(x)}));
            const rutas = listaRecientes();
            const casa = Quickshell.env("HOME");
            return rutas.map(r => ({ referencia:{tipo:"archivo",id:r}, nombre: r.split("/").pop(), detalle: (t.trim() === "/" ? "Reciente · " : "") + r.replace(casa, "~"),
                                     glifo: /\.[a-z0-9]{1,5}$/i.test(r) ? 0xF0214 : 0xF024B, accion: () => Quickshell.execDetached(["xdg-open", r]) }));
        }
        if (modo === "web") {
            const p = t.match(/^(\w+)\s+(.+)$/), w = webs[p[1].toLowerCase()];
            return [{ nombre: p[2], detalle: "Buscar en " + w[0], glifo: 0xF059F, accion: () => Quickshell.execDetached(["xdg-open", w[1] + encodeURIComponent(p[2])]) }];
        }
        const res = [];
        if (modo === "apps" && q.length>=3 && !EstadoEscritorio.privacidad) {
            const eventos=Eventos.lista.filter(e => normalizar(e.titulo).includes(q)).slice(0,3);
            const tareas=Eventos.tareas.filter(e => normalizar(e.titulo).includes(q)).slice(0,3);
            for (const e of eventos) {
                const ref={tipo:"evento",id:e.uid || "",inicio:e.inicio.getTime(),calendario:e.calendario || ""};
                res.push({nombre:e.titulo,detalle:Eventos.cuando(e),glifo:0xF00F0,referencia:ref,mantener:true,accion:() => contexto.abrir(ref)});
            }
            for (const t of tareas) { const ref={tipo:"tarea",id:t.id};res.push({nombre:t.titulo,detalle:"Tarea pendiente en Google",glifo:0xF012C,referencia:ref,mantener:true,accion:() => contexto.abrir(ref)}); }
        }
        if (modo === "calc") {
            const ok = calcResultado && calcEntrada === t && !/^error|warning/i.test(calcResultado);
            res.push({ nombre: ok ? calcResultado : avisoBusqueda ? "No se pudo calcular" : "…", detalle: ok ? "= " + t.replace(/^=\s*/, "") + "   ·   Enter: copiar el resultado" : avisoBusqueda || "Calculando…",
                       glifo: 0xF00EC, accion: ok ? (r => () => Quickshell.execDetached(["wl-copy", r]))(calcResultado) : null });
            if (t.startsWith("=")) return res;
        }
        const apps = DesktopEntries.applications.values.filter(visibleApp)
            .map(app => ({ app: app, p: puntajeApp(app, q) })).filter(r => r.p > 0)
            .map(r => ({ app: r.app, p: r.p + Math.min(30, (usos[r.app.id] ?? 0) * 3) }));
        // En reposo: lo que toca ahora, lo que más abres y después el resto en orden alfabético (ORION 5.5)
        if (modo === "apps" && q === "") {
            const conUso = apps.filter(r => (usos[r.app.id] ?? 0) > 0)
                .sort((a, b) => (usos[b.app.id] ?? 0) - (usos[a.app.id] ?? 0)).slice(0, 5);
            const ids = conUso.map(r => r.app.id);
            const itemApp = (r, g) => ({ nombre: r.app.name, detalle: r.app.genericName || r.app.comment || "", icono: r.app.icon,
                                         grupo: g, inmediata: true, accion: () => lanzarApp(r.app) });
            return [...sugerenciasAhora().map(x => Object.assign(x, { grupo: "Sugerido ahora" })),
                    ...conUso.map(r => itemApp(r, "Recientes")),
                    ...apps.filter(r => !ids.includes(r.app.id)).sort((a, b) => a.app.name.localeCompare(b.app.name))
                           .map(r => itemApp(r, "Todas las apps"))];
        }
        if (modo === "apps") res.push(...ajustesDirectos(q.trim()));
        const accs = acciones.map(a => ({ a: a, p: puntajeAccion(a, q) })).filter(r => r.p > 0);
        // proyectos: por su nombre, o todos con «proyecto» / «retomar»
        const todosProy = q.length >= 3 && ("proyectos".startsWith(q) || "retomar".startsWith(q));
        const proys = EstadoEscritorio.privacidad || q.length < 2 ? [] : proyectos.map(pr => {
            const n = normalizar(pr.nombre);
            return { pr: pr, p: n.startsWith(q) ? 95 : n.includes(q) ? 75 : todosProy ? 60 : 0 };
        }).filter(r => r.p > 0);
        const plants = EstadoEscritorio.privacidad || q.length < 3 ? [] : plantillas.filter(x => normalizar(x.titulo).includes(q)).slice(0, 3);
        const mezcla = [...apps.map(r => ({ p: r.p, item: { nombre: r.app.name, detalle: r.app.genericName || r.app.comment || "",
                                                            icono: r.app.icon, inmediata: true, accion: () => lanzarApp(r.app) } })),
                        ...accs.map(r => ({ p:r.p, item:{nombre:r.a.n,detalle:r.a.d,glifo:r.a.i,mantener:!!r.a.ref || !!r.a.consulta,accion:() => r.a.ref ? contexto.abrir(r.a.ref) : r.a.consulta ? abrirCon(r.a.consulta) : sh(r.a.c)} })),
                        ...proys.map(r => ({ p: r.p, item: itemProyecto(r.pr) })),
                        ...plants.map(x => ({ p: 40, item: itemPlantilla(x) }))]
            .sort((a, b) => b.p - a.p || a.item.nombre.localeCompare(b.item.nombre)).slice(0, 40).map(x => x.item);
        // lo universal solo vale si es de lo que hay escrito ahora (no de una búsqueda anterior)
        const universal = !EstadoEscritorio.privacidad && (todosDe === t || cargandoBusqueda) && q.length >= 3 ? todos : [];
        if ((universal.length || res.some(x => x.grupo === "Ajustes")) && mezcla.length) mezcla.forEach(x => x.grupo = "Apps y acciones");
        res.push(...mezcla);
        res.push(...universal.map(x => ({ nombre: x.nombre, detalle: x.detalle, glifo: x.glifo, grupo: x.grupo, referencia:x.referencia,
                                          accion: x.cmd && x.cmd.length ? () => ventana.ejecutarResultado(x) : null })));
        if (q && res.length === 0)   // nada: ofrecer buscarlo en internet
            res.push({ nombre: t.trim(), detalle: "Buscar en Google", glifo: 0xF059F,
                       accion: () => Quickshell.execDetached(["xdg-open", webs.g[1] + encodeURIComponent(t.trim())]) });
        return res;
    }

    // ── Ajustes directos sin prefijo (ORION 5.8) ─────────────────────────
    // «brillo 40», «volumen 30», «wifi», «bluetooth off», «no molestar 1 h», «oscuro», «reunión»…
    // Los interruptores usan conmutadores.sh: solo se anuncia el cambio cuando el servicio lo confirma.
    readonly property var controlesDirectos: ({
        "wifi": ["wifi", "Wi-Fi", 0xF0928], "wi-fi": ["wifi", "Wi-Fi", 0xF0928], "bluetooth": ["bluetooth", "Bluetooth", 0xF00AF],
        "bt": ["bluetooth", "Bluetooth", 0xF00AF], "luz nocturna": ["luz", "Luz nocturna", 0xF0594], "replay": ["replay", "Replay", 0xF044A],
        "energia alta": ["rendimiento", "Energía alta", 0xF0425], "conservar bateria": ["conservacion", "Conservar batería", 0xF12A6]
    })
    function confirmarControl(cosa, nombre, encender) {
        const sc = Quickshell.env("HOME") + "/.config/hypr/scripts/conmutadores.sh";
        const ok = nombre + (encender ? " activado" : " desactivado");
        sh(`if "${sc}" ${cosa} ${encender ? "on" : "off"} >/dev/null 2>&1; then qs ipc call osd mensaje "${ok}" ""; `
           + `else notify-send -a ORION -u normal "${nombre}: no se confirmó el cambio" "Revisa el servicio en el centro de control."; fi`);
    }
    function ajustesDirectos(q) {
        if (q.length < 2) return [];
        let m;
        const r = [], num = (x) => Math.max(0, Math.min(100, parseInt(x)));
        if ((m = q.match(/^(brillo|volumen)\s+(\d{1,3})\s*%?$/))) {
            const v = num(m[2]), brillo = m[1] === "brillo";
            r.push({ nombre: (brillo ? "Brillo al " : "Volumen al ") + v + " %", detalle: "Ajuste · Enter para aplicarlo", glifo: brillo ? 0xF00E0 : 0xF057E,
                     accion: () => sh(brillo ? `brightnessctl set ${Math.max(5, v)}% >/dev/null && qs ipc call osd brillo`
                                             : `wpctl set-volume @DEFAULT_AUDIO_SINK@ ${v}% && qs ipc call osd media`) });
        }
        if ((m = q.match(/^([a-z -]+?)(?:\s+(on|off|encender|apagar|activar|desactivar))?$/)) && controlesDirectos[m[1].trim()]) {
            const [cosa, nombre, glifo] = controlesDirectos[m[1].trim()];
            const quiere = m[2] ? /on|encender|activar/.test(m[2]) && !/desactivar/.test(m[2]) : null;
            for (const encender of quiere === null ? [true, false] : [quiere])
                r.push({ nombre: (encender ? "Activar " : "Desactivar ") + nombre, detalle: "Ajuste · se confirma con el servicio", glifo: glifo,
                         accion: () => confirmarControl(cosa, nombre, encender) });
        }
        if ((m = q.match(/^(no molestar|silencio|dnd)(?:\s+(\d+)\s*(m|min|minutos|h|hora|horas))?$/))) {
            const opciones = m[2] ? [[String(parseInt(m[2]) * (/^h/.test(m[3]) ? 60 : 1)), m[2] + (/^h/.test(m[3]) ? " h" : " min")]]
                                  : [["30", "30 min"], ["60", "1 hora"], ["siempre", "hasta desactivar"], ["off", "quitar la pausa"]];
            for (const [modo, texto] of opciones)
                r.push({ nombre: "No molestar · " + texto, detalle: modo === "off" ? "Vuelven las emergentes; las automáticas (juego, reunión) siguen" : "Las notificaciones se guardan para después", glifo: 0xF009B,
                         accion: () => sh(`qs ipc call notificaciones pausar ${modo}`) });
        }
        if ((m = q.match(/^(?:modo |tema )?(oscuro|claro)$/)))
            r.push({ nombre: "Tema " + m[1], detalle: "Ajuste · cambia los colores ahora", glifo: m[1] === "oscuro" ? 0xF0594 : 0xF05A8,
                     accion: () => sh(Quickshell.env("HOME") + "/.config/hypr/scripts/tema.sh " + m[1]) });
        if ((m = q.match(/^(reunion|concentracion)$/))) {
            const reu = m[1] === "reunion", activa = reu ? Reunion.activa : Concentracion.activo;
            r.push({ nombre: activa ? (reu ? "Terminar reunión" : "Terminar concentración") : (reu ? "Empezar reunión · 30 min" : "Empezar concentración · 25 min"),
                     detalle: reu ? "Privacidad, No molestar y replay en pausa mientras dure" : "Oculta distracciones mientras dure", glifo: reu ? 0xF0570 : 0xF0E1B,
                     accion: () => AccionesServicio.ejecutar({ tipo: "actividad", id: m[1] }, activa ? "terminar" : "iniciar", { minutos: reu ? 30 : 25 }) });
        }
        return r.map(x => Object.assign(x, { grupo: "Ajustes" }));
    }

    // Hasta tres atajos según el momento: compromiso cercano, proyecto en curso y tareas pendientes
    function sugerenciasAhora() {
        if (EstadoEscritorio.privacidad) return [];
        const s = [], ahora = new Date();
        const e = Eventos.proximos(1)[0];
        if (e && !e.todoDia) {
            const min = Math.round((e.inicio - ahora) / 60000);
            const texto = e.inicio <= ahora && e.fin > ahora ? "Ahora · termina " + Qt.formatTime(e.fin, "HH:mm")
                        : min <= 60 ? "En " + Math.max(1, min) + " min · " + Qt.formatTime(e.inicio, "HH:mm") : "";
            if (texto) s.push({ nombre: e.titulo, detalle: texto + " · ver en Hoy", glifo: 0xF00F0,
                                accion: () => sh("qs ipc call brujula abrir hoy") });
        }
        const n = Eventos.tareas.length;
        if (n > 0) s.push({ nombre: n === 1 ? "1 tarea pendiente" : n + " tareas pendientes", detalle: "Revisarlas en Hoy",
                            glifo: 0xF012C, accion: () => sh("qs ipc call brujula abrir hoy") });
        return s.slice(0, 3);
    }
    function lanzarApp(app) {
        // la app se abre desde su icono (CapaLanzamiento.qml): solo si se eligió en el lanzador abierto
        const b = lista.currentItem?.baldosa;
        if (b && b.visible && ventana.visible) Lanzamiento.desde(b, Quickshell.iconPath(app.icon, "application-x-executable"), ventana.screen?.name ?? "");
        if (app.id === "com.rtosta.zapzap" || app.id === "com.rtosta.zapzap.desktop")
            Quickshell.execDetached(["gtk-launch", "com.rtosta.zapzap"]);
        else if (app.runInTerminal) Quickshell.execDetached(["kitty", "-e", ...app.command]);
        else app.execute();
        const u = Object.assign({}, usos);
        u[app.id] = (u[app.id] ?? 0) + 1;
        usos = u;
        archivoUsos.setText(JSON.stringify(u, null, 1));
    }
    function elegir(r, desdeIpc = false) {
        if ((!abierto && !desdeIpc) || contexto.referencia || !r || !r.accion) return;
        if (r.mantener) { r.accion(); return; }
        abierto = false;
        if (r.inmediata) r.accion();
        else { accionPendiente = r.accion; soltarYActuar.restart(); }
    }

    Timer { id: soltarYActuar; interval: 90; onTriggered: { const f=ventana.accionPendiente; ventana.accionPendiente=null; if (f) f(); } }
    function ejecutarResultado(x) {
        const principal=({ventana:"enfocar",archivo:"abrir",web:"abrir"})[x.referencia?.tipo];
        if (principal) AccionesServicio.ejecutar(x.referencia,principal);
        else if (x.cmd?.length) Quickshell.execDetached(x.cmd);
    }
    function accionesPara(r) { if (r?.referencia) contexto.abrir(r.referencia); }
    // ── Velo + clic fuera ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: ventana.abierto ? 0.25 : 0
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
        MouseArea { anchors.fill: parent; onClicked: ventana.abierto = false }
    }

    // ── La tarjeta ──────────────────────────────────────────────────────
    Rectangle {
        id: tarjeta
        width: 640
        height: Math.min(columna.implicitHeight + 32, parent.height - 48)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(16,Math.min(parent.height*.12,parent.height-height-24)) + (ventana.abierto ? 0 : -12)
        opacity: ventana.abierto ? 1 : 0
        scale: ventana.abierto ? 1 : 0.98
        Behavior on y       { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.normal } }
        Behavior on scale   { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutCubic } }
        color: "transparent"
        FondoPanel { anchors.fill: parent; radio: 24 }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: columna
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8

            // Campo de búsqueda
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(Paleta.fondo, .55) }
                    GradientStop { position: 1; color: EstiloPanel.relleno }
                }
                border { width: 1; color: buscador.activeFocus ? Qt.alpha(Paleta.acento, 0.45) : EstiloPanel.borde }

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 12 }
                    spacing: 12
                    Rectangle {   // pastilla del modo
                        implicitWidth: 36; implicitHeight: 36; radius: 12
                        color: EstiloPanel.elevada
                        border { width: 1; color: EstiloPanel.bordeSeleccion }
                    Text {   // el icono cambia según el modo
                        anchors.centerIn: parent
                        text: ventana.g(({ apps: 0xF0349, calc: 0xF00EC, dolar: 0xF01C1, web: 0xF059F, emoji: 0xF0785, archivos: 0xF024B, recordar: 0xF0020, agenda: 0xF00F0, externo: 0xF0349, ia: 0xF06A9, nota: 0xF039A, plantillas: 0xF0219, avisos: 0xF009A })[ventana.modo] ?? 0xF0349)
                        color: Paleta.acento
                        font { family: Paleta.mono; pixelSize: 16 }
                    }
                    }
                    TextInput {
                        id: buscador
                        Layout.fillWidth: true
                        color: Paleta.texto
                        selectionColor: Qt.alpha(Paleta.acento, 0.4)
                        font { family: Paleta.fuente; pixelSize: 16 }
                        clip: true
                        onTextChanged: lista.currentIndex = 0

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: buscador.text === ""
                            text: "Busca apps, acciones, proyectos… o usa un prefijo"
                            color: Paleta.gris
                            font: buscador.font
                        }

                        Keys.onEscapePressed: { if (contexto.referencia) { if (!contexto.ocupado) { contexto.referencia=null; buscador.forceActiveFocus(); } } else ventana.abierto=false; }
                        Keys.onReturnPressed: (event) => { if (event.modifiers & Qt.AltModifier) ventana.accionesPara(ventana.resultados[lista.currentIndex]); else ventana.elegir(ventana.resultados[lista.currentIndex]); }
                        Keys.onEnterPressed: ventana.elegir(ventana.resultados[lista.currentIndex])
                        Keys.onDownPressed: lista.incrementCurrentIndex()
                        Keys.onUpPressed: lista.decrementCurrentIndex()
                        Keys.onTabPressed: lista.incrementCurrentIndex()
                        Keys.onBacktabPressed: lista.decrementCurrentIndex()
                    }
                    Rectangle {
                        visible: ventana.resultados.length > 0
                        implicitWidth: numResultados.implicitWidth + 16; implicitHeight: 22; radius: height / 2
                        color: EstiloPanel.rellenoActivo
                        border { width: 1; color: EstiloPanel.borde }
                        Text { id: numResultados; anchors.centerIn: parent; text: ventana.resultados.length; color: Paleta.gris; font { family: Paleta.fuente; pixelSize: 11; bold: true } }
                    }
                }
            }

            // Prefijos: con el campo vacío, los más usados; «Más» los enseña todos. Clic = escribirlo.
            Flow {
                Layout.fillWidth: true
                visible: buscador.text === ""
                spacing: 4
                Repeater {
                    model: {
                        const todos = [["=", "calcular"], ["g", "web"], ["/", "archivos"], ["v", "ventanas"], ["c", "copiado"], ["pl", "plantillas"],
                                       ["recordar", "recordatorio"], ["evento", "calendario"], [":", "emoji"], ["n", "notas"], ["d", "documentos"],
                                       ["t", "pestañas"], ["h", "historial"], ["p", "contraseñas"], ["a", "atajos"], ["l", "línea de tiempo"],
                                       ["s", "ajustes"], ["!", "avisos"], ["ia", "preguntar"], ["nota", "apuntar"], ["b", "todo"]];
                        return ventana.todosPrefijos ? todos : todos.slice(0, 6).concat([["+", "más"]]);
                    }
                    Rectangle {
                        id: chip
                        required property var modelData
                        implicitWidth: filaChip.implicitWidth + 16; implicitHeight: 26; radius: height / 2
                        color: zonaChip.containsMouse ? EstiloPanel.rellenoActivo : EstiloPanel.relleno
                        border { width: 1; color: EstiloPanel.borde }
                        Row {
                            id: filaChip
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: chip.modelData[0] === "+" ? "" : chip.modelData[0]; visible: text !== ""; color: Paleta.acento; font { family: Paleta.mono; pixelSize: 11; bold: true } }
                            Text { text: chip.modelData[1]; color: EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 11 } }
                        }
                        MouseArea {
                            id: zonaChip
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (chip.modelData[0] === "+") { ventana.todosPrefijos = true; return; }
                                const pre = chip.modelData[0];
                                buscador.text = (pre === "=" || pre === "/" || pre === ":") ? pre : pre + " ";
                                buscador.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Text { Layout.fillWidth: true; visible: ventana.cargandoBusqueda || ventana.avisoBusqueda !== ""; text: (ventana.cargandoBusqueda ? (ventana.resultadosBusquedaDe && ventana.resultadosBusquedaDe !== buscador.text ? "Resultados de «"+ventana.resultadosBusquedaDe+"» mientras buscamos «"+buscador.text+"»…" : "Buscando…") : "") + (ventana.avisoBusqueda ? " · "+ventana.avisoBusqueda : ""); wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; color: ventana.avisoBusqueda ? Paleta.aviso : EstiloPanel.tenue; font { family: Paleta.fuente; pixelSize: 12 } }
            BotonPanel {
                visible: PreferenciasUI.mostrarContinuidad && !EstadoEscritorio.privacidad &&
                         !contexto.referencia && buscador.text.trim() === "" && Continuidad.ultimo !== null
                text: visible && Continuidad.ultimo ? "Continuar · " + Continuidad.ultimo.nombre + (Continuidad.ultimo.siguiente ? "  —  " + Continuidad.ultimo.siguiente : "") : ""
                simbolo: ventana.g(0xF0E1B)
                onClicked: if (visible && Continuidad.ultimo) ventana.elegir(ventana.itemProyecto(Continuidad.ultimo))
            }
            // Resultados
            AccionesResultado {
                id: contexto
                Layout.fillWidth: true
                onCerrar: { referencia=null; buscador.forceActiveFocus(); }
                onSoltarFoco: ventana.abierto=false
                onActualizado: { leerPlantillas.running=true; leerProyectos.running=true; Eventos.actualizar(); espera.restart(); }
            }

            ListView {
                id: lista
                visible: !contexto.referencia
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 7 * 56 + 26)
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
                    readonly property Item baldosa: baldosaFila   // de aquí sale la app al abrirse (Lanzamiento.qml)
                    width: lista.width
                    height: 56 + (cabecera ? 26 : 0)

                    Text {
                        visible: fila.cabecera
                        anchors { left: parent.left; leftMargin: 16; top: parent.top; topMargin: 8 }
                        text: (fila.modelData.grupo ?? "").toUpperCase()
                        color: Paleta.gris
                        font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 1.4 }
                    }
                    Item {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
                        height: 52
                        opacity: fila.actual ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: EstiloPanel.rapido } }
                        RectangularShadow {
                            anchors.fill: parent
                            visible: EstiloPanel.profundidad
                            radius: 16; offset.y: 4; blur: 18; spread: -8
                            color: Qt.alpha("black", .28)
                        }
                        FondoSeleccion { anchors.fill: parent; radius: 16; marca: true }
                    }

                    RowLayout {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2; leftMargin: 12; rightMargin: fila.actual && fila.modelData.referencia ? 100 : 12 }
                        height: 52
                        spacing: 12
                        Rectangle {   // baldosa del icono
                            id: baldosaFila
                            implicitWidth: 38; implicitHeight: 38; radius: 12
                            color: fila.actual ? EstiloPanel.elevada : EstiloPanel.relleno
                            border { width: 1; color: fila.actual ? EstiloPanel.bordeFuerte : EstiloPanel.borde }
                            Behavior on color { ColorAnimation { duration: EstiloPanel.rapido } }
                            // Resplandor con los colores del propio icono (copia desenfocada detrás de la baldosa)
                            MultiEffect {
                                z: -1
                                visible: EstiloPanel.profundidad && fila.actual && iconoFila.visible && iconoFila.status === Image.Ready
                                anchors.centerIn: parent
                                width: 58; height: 58
                                source: iconoFila
                                blurEnabled: true
                                blur: 1
                                blurMax: 40
                                saturation: .5
                                brightness: .25
                                opacity: 1
                            }
                            IconImage {
                                id: iconoFila
                                anchors.centerIn: parent
                                width: 28; height: 28
                                scale: fila.actual ? 1.08 : 1
                                Behavior on scale { NumberAnimation { duration: EstiloPanel.normal; easing.type: Easing.OutBack } }
                                visible: !!fila.modelData.icono
                                source: fila.modelData.icono ? Quickshell.iconPath(fila.modelData.icono, "application-x-executable") : ""
                                asynchronous: true
                            }
                            Text {   // respaldo: la inicial cuando el tema no tiene el icono de la app
                                anchors.centerIn: parent
                                visible: !!fila.modelData.icono && iconoFila.status === Image.Error
                                text: (fila.modelData.nombre || "?").charAt(0).toUpperCase()
                                color: Paleta.acento2
                                font { family: Paleta.fuente; pixelSize: 16; bold: true }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !fila.modelData.icono
                                text: fila.modelData.texto ?? (fila.modelData.glifo ? ventana.g(fila.modelData.glifo) : "")
                                color: fila.actual ? Qt.lighter(Paleta.acento, 1.2) : Paleta.acento
                                font { family: fila.modelData.texto ? "Noto Color Emoji" : Paleta.mono; pixelSize: fila.modelData.texto ? 22 : 19 }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0; Layout.preferredWidth: 1   // que el texto largo se corte, no estire la fila
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                text: EstadoEscritorio.privacidad && fila.modelData.referencia ? "Resultado privado" : fila.modelData.nombre
                                color: Paleta.texto
                                elide: Text.ElideRight
                                font { family: Paleta.fuente; pixelSize: 14; bold: true }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: EstadoEscritorio.privacidad && fila.modelData.referencia ? "Detalles ocultos" : fila.modelData.detalle ?? ""
                                // gris puro se perdía sobre el resaltado; tenue (texto al 68 %) se lee en ambos casos
                                color: fila.actual ? EstiloPanel.secundario : EstiloPanel.tenue
                                elide: Text.ElideMiddle
                                font { family: Paleta.fuente; pixelSize: 11 }
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.rightMargin: fila.actual && fila.modelData.referencia ? 88 : 0
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: lista.currentIndex = fila.index
                        onClicked: (e) => e.button === Qt.RightButton ? ventana.accionesPara(fila.modelData) : ventana.elegir(fila.modelData)
                    }
                    BotonCompacto {
                        visible: fila.actual && !!fila.modelData.referencia
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "Acciones"
                        onClicked: ventana.accionesPara(fila.modelData)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                visible: ventana.resultados.length > 0 && !contexto.referencia
                text: "↑↓ moverse  ·  Enter abrir  ·  Alt+Enter acciones  ·  Esc cerrar"
                color: EstiloPanel.tenue
                font { family: Paleta.fuente; pixelSize: 11 }
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

        }
    }
}
