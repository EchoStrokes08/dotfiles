// Quickshell — punto de entrada. Quickshell lee ~/.config/quickshell/shell.qml al lanzar `qs`.
//
// QML en 30 segundos:
//   Tipo { propiedad: valor }      crea un objeto (cada archivo Mayúscula.qml es un tipo nuevo)
//   propiedad: otra.cosa * 2       es un BINDING: se recalcula solo cuando "otra.cosa" cambia
//   onAlgoChanged: { ... }         código que corre cuando cambia "algo"
//   id: nombre                     para referirse al objeto desde otros sitios
//
// Abrir/cerrar desde fuera (lo usa SUPER+D):  qs ipc call dashboard toggle
// Ver errores y recargar: Quickshell recarga solo al guardar; el log sale en la terminal de `qs`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    AvisoRecarga {}
    Lanzador { id: lanzador }
    OSD {}
    CapaLanzamiento {}   // las apps se abren desde su icono del lanzador
    Autorizacion {}   // agente de polkit: la ventana de la contraseña de administrador
    Emergentes {}
    CentroControl { id: centro }
    Bloqueo {}
    Wallpapers { id: wallpapers }
    Portapapeles { id: portapapeles }
    Menu { id: menu }
    Chuleta { id: chuleta }
    AyudaSuper { id: ayudaSuper; esenciales: chuleta.esenciales[0]?.filas ?? [] }
    Vista { id: vista }
    IA { id: ia }
    NotaRapida { id: nota }
    Mesa { id: mesa }
    Flujo { id: flujo }
    Resumen { id: resumen }
    Brujula { id: brujula }
    Movil { id: movil }
    Agente { id: agente }
    Impresora { id: impresora }
    // Cargador.qml es un singleton: solo existe si algo lo usa. Esto lo arranca al iniciar.
    readonly property bool conBateria: Cargador.conBateria
    readonly property int recordatoriosPendientes: Recordatorios.lista.length   // arranca Recordatorios.qml
    readonly property bool hayAudifonos: Audifonos.hayAudifonos                 // arranca Audifonos.qml
    readonly property int porActualizar: Actualizaciones.total                   // arranca Actualizaciones.qml
    readonly property int minutosSeguidos: Pausas.seguidos                       // arranca Pausas.qml
    readonly property bool climaListo: Clima.listo && Eventos.lista.length >= 0  // arranca Clima.qml y Eventos.qml

    // qs ipc call origen marcar X Y → el próximo panel nace de ese punto de la pantalla (Origen.qml)
    IpcHandler {
        target: "origen"
        function marcar(x: real, y: real): void { Origen.marcarPunto(x, y, ""); }
    }

    // Una barra por pantalla; si conectas un monitor, aparece otra sola
    Variants {
        id: barras
        model: Quickshell.screens
        Barra {
            required property var modelData
            screen: modelData
            onRelojPulsado: { const a = brujula.abierto && brujula.pagina === 0; cerrarTodo(); if (!a) brujula.abrir("hoy"); }
        }
    }

    // El wallpaper «respira» al cambiar de espacio (FondoVivo.qml). Uno por pantalla.
    Variants {
        model: Quickshell.screens
        FondoVivo { required property var modelData; screen: modelData }
    }

    // Panorama (Panorama.qml): el wallpaper es un paisaje y cada espacio, un tramo; la cámara se desliza al cambiar
    //   qs ipc call panorama alternar
    Variants {
        model: Quickshell.screens
        Panorama { required property var modelData; screen: modelData }
    }
    IpcHandler {
        target: "panorama"
        function alternar(): void { PreferenciasUI.panorama = !PreferenciasUI.panorama; PreferenciasUI.guardar(); }
        function estado(): string { return PreferenciasUI.panorama ? "activo" : "inactivo"; }
    }

    // Al bajar 3 dedos, una cápsula sale de la isla siguiendo al dedo y se convierte en Brújula (Gestos.qml)
    Variants {
        model: Quickshell.screens
        CapaTirador { required property var modelData; screen: modelData; brujulaAbierta: brujula.abierto }
    }

    // Clima vivo sobre el wallpaper (ClimaVivo.qml): lluvia, tormenta, nieve, niebla o nubes, con el
    // espacio vacío. Antes que los widgets para quedar debajo de ellos. Uno por pantalla.
    //   qs ipc call clima simular lluvia   (llovizna · chubasco · tormenta · nieve · niebla · nubes · "" = real)
    Variants {
        model: Quickshell.screens
        ClimaVivo { required property var modelData; screen: modelData }
    }
    IpcHandler {
        target: "clima"
        function simular(tipo: string): void { Clima.simulado = tipo; }
        function estado(): string { return Clima.vivo || "despejado"; }
    }

    // Widgets de escritorio (reloj, frase, lo próximo): solo con el workspace vacío. Uno por pantalla.
    PersistentProperties { id: escritorioCfg; reloadableId: "escritorio"; property bool activado: true }
    Variants {
        model: Quickshell.screens
        Escritorio {
            required property var modelData
            screen: modelData
            activado: escritorioCfg.activado
        }
    }

    // Apagado cinematográfico (Despedida.qml): la pantalla se va a negro y la isla se despide
    //   qs ipc call despedida probar   → la animación entera sin apagar nada
    Variants {
        model: Quickshell.screens
        CapaDespedida { required property var modelData; screen: modelData }
    }
    IpcHandler {
        target: "despedida"
        function probar(): void { Despedida.hacer([], "apagar"); }
    }

    // «Tu día» (TuDia.qml): el resumen del día en tarjetas, en la pantalla con el foco
    //   qs ipc call tudia mostrar   · también al cerrar la jornada y desde el lanzador
    CapaTuDia {}
    IpcHandler {
        target: "tudia"
        function mostrar(): void { cerrarTodo(); TuDia.mostrar(); }
        function cerrar(): void { TuDia.cerrar(); }
        function estado(): string { return JSON.stringify({ activa: TuDia.activa, pagina: TuDia.actual, paginas: TuDia.paginas }); }
    }

    // Máquina del tiempo (Maquina.qml): tu pantalla se vuelve la primera tarjeta de una pila con los momentos del día
    //   qs ipc call maquina abrir
    CapaMaquina {}
    IpcHandler {
        target: "maquina"
        function abrir(): void { cerrarTodo(); Maquina.abrir(); }
        function toggle(): void { if (Maquina.activa) Maquina.cerrar(); else { cerrarTodo(); Maquina.abrir(); } }
        function cerrar(): void { Maquina.cerrar(); }
        function estado(): string { return JSON.stringify({ activa: Maquina.activa, indice: Maquina.indice, tarjetas: Maquina.tarjetas.length }); }
    }

    // Letras en modo cine (Letras.qml): lo que suena a pantalla completa con la letra sincronizada
    //   qs ipc call letras toggle   (SUPER+SHIFT+Y)
    CapaLetras {}
    IpcHandler {
        target: "letras"
        function toggle(): void { if (!Letras.activa) cerrarTodo(); Letras.alternar(); }
        function cerrar(): void { Letras.cerrar(); }
        function estado(): string { return JSON.stringify({ activa: Letras.activa, letra: Letras.estadoLetra, lineas: Letras.lineas.length, actual: Letras.actual }); }
    }

    // Inicio de sesión cinematográfico (Bienvenida.qml): una vez por sesión, una por pantalla
    Variants {
        model: Quickshell.screens
        Bienvenida { required property var modelData; screen: modelData }
    }
    IpcHandler {
        target: "escritorio"
        function toggle(): void { escritorioCfg.activado = !escritorioCfg.activado; }
        function estado(): string { return escritorioCfg.activado ? "visible" : "oculto"; }
    }

    // «dashboard» es el nombre antiguo de Brújula › Hoy: SUPER+D, el reloj de la barra y tres dedos abajo lo siguen usando
    IpcHandler {
        target: "dashboard"
        function toggle(): void { const a = brujula.abierto && brujula.pagina === 0; cerrarTodo(); if (!a) brujula.abrir("hoy"); }
        function abrir(): void  { cerrarTodo(); brujula.abrir("hoy"); }
        function cerrar(): void { brujula.abierto = false; }
        // Alias antiguo: cambia de ESPACIO, no de pestaña. Usa «espacios ir» (o «brujula abrir <pagina>»).
        function irA(n: int): void { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`); }
    }

    // Espacios de trabajo desde scripts y pruebas:  qs ipc call espacios ir 3
    IpcHandler {
        target: "espacios"
        function ir(n: int): void { Hyprland.dispatch(`hl.dsp.focus({ workspace = ${n} })`); }
        function actual(): string { return String(Hyprland.focusedWorkspace?.id ?? ""); }
    }

    // Lanzador de apps (SUPER+R):  qs ipc call lanzador toggle
    IpcHandler {
        target: "lanzador"
        function toggle(): void { const a = lanzador.abierto; cerrarTodo(); lanzador.abierto = !a; }
        function buscar(texto: string): void { cerrarTodo(); lanzador.abrirCon(texto); }
        function lanzar(texto: string): void { lanzador.lanzarPrimero(texto); }
    }

    // Notificaciones (SUPER+N panel, SUPER+SHIFT+N no molestar; el modo juego usa noMolestarSi/No)
    IpcHandler {
        target: "notificaciones"
        function toggle(): void { const a = centro.abierto && centro.seccion === "notificaciones"; cerrarTodo(); if (!a) centro.abrirEn("notificaciones"); }
        function avisos(): void { abrirCentro("avisos"); }
        function sonido(): void { abrirCentro("sonido"); }
        function noMolestar(): void { Notificaciones.alternarNoMolestar(); }
        function noMolestarSi(): void { Notificaciones.pausar("siempre"); }
        function noMolestarNo(): void { Notificaciones.pausar("off"); }
        // modo: minutos («30», «60»), «siempre», «off», «concentracion» o «reunion»
        function pausar(modo: string): void { Notificaciones.pausar(modo); }
        function motivo(nombre: string, activo: bool): void {
            Notificaciones.motivo(nombre, activo);
            if (nombre === "jornada" && activo) TuDia.alCerrarJornada();   // al cerrar el día, «Tu día»
        }
        function automatico(activo: bool): void { Notificaciones.automatico = activo; }
        function estado(): string { return Notificaciones.noMolestar ? "activo" : "inactivo"; }
        function borrar(): void { Notificaciones.borrarTodo(); }
    }

    // El centro del escritorio vive ahora en el centro de control (perfiles arriba, el resto en «Más»)
    IpcHandler {
        target: "centroEscritorio"
        function estado(): string { return JSON.stringify(EstadoEscritorio.datos); }
        function toggle(): void { const a = centro.abierto && centro.seccion === "mas"; cerrarTodo(); if (!a) centro.abrirEn("mas"); }
        function cerrar(): void { centro.abierto = false; }
    }

    IpcHandler {
        target: "mesa"
        // Ventanas y plantillas viven en el lanzador (ORION 4.1); el IPC antiguo sigue funcionando y redirige.
        function abrir(que: string): void {
            cerrarTodo();
            if (que === "ventanas" || que === "plantillas" || que === "") lanzador.abrirCon(que === "plantillas" ? "pl " : "v ");
            else mesa.abrir(que);
        }
        function cerrar(): void { mesa.abierto = false; }
        // Editar las apps de un modo: estudiar | programar | descansar
        function apps(que: string): void { cerrarTodo(); mesa.abrir("rutinas"); const r = mesa.rutinas.find(x => x.id === que); if (r) mesa.editar(r); }
        function estado(): string { return JSON.stringify({abierto:mesa.abierto, pagina:mesa.pagina, reunion:Reunion.activa, ventanas:mesa.ventanas.length, plantillas:mesa.plantillas.length}); }
    }

    // Brújula (SUPER+D): hoy · línea de tiempo (día, reglas automáticas, sesión anterior) · salud
    IpcHandler {
        target: "brujula"
        function abrir(pagina: string): void { cerrarTodo(); brujula.abrir(pagina); }
        function toggle(): void { const a = brujula.abierto; cerrarTodo(); if (!a) brujula.abrir("hoy"); }
        function dia(fecha: string): void { cerrarTodo(); brujula.abrirDia(fecha); }
        function cerrar(): void { brujula.abierto = false; }
        function estado(): string { return JSON.stringify({ abierto: brujula.abierto, pagina: brujula.pagina, aviso: brujula.aviso }); }
    }

    // Agente (SUPER+O): le hablas al escritorio; consulta, abre y propone acciones (scripts/agente.py)
    IpcHandler {
        target: "agente"
        function toggle(): void { const a = agente.abierto; cerrarTodo(); agente.abierto = !a; }
        function memoria(): void { cerrarTodo(); agente.verMemoria = true; agente.abierto = true; }
        function preguntar(texto: string): void { cerrarTodo(); agente.abrirYPreguntar(texto); }
        function estado(): string { return JSON.stringify({ abierto: agente.abierto, pensando: agente.pensando, listo: agente.listo, mensajes: agente.mensajes.length }); }
    }

    // toggle (el móvil de la barra, movil.sh menu) → centro de control › Móvil · avisos → el panel de avisos y respuestas
    IpcHandler {
        target: "movil"
        function toggle(): void { const a = centro.abierto && centro.seccion === "movil"; cerrarTodo(); if (!a) centro.abrirEn("movil"); }
        function abrir(): void { cerrarTodo(); centro.abrirEn("movil"); }
        function avisos(): void { cerrarTodo(); movil.abrir(); }
        function cerrar(): void { movil.abierto = false; }
        function estado(): string { return JSON.stringify({ abierto: movil.abierto, conectado: movil.d?.conectado ?? false, avisos: movil.d?.notificaciones?.length ?? 0 }); }
    }

    IpcHandler {
        target: "flujo"
        // Continuidad (proyectos) vive en el lanzador (ORION 4.1); organizar y selección siguen en Flujo.
        function abrir(pagina: string): void {
            cerrarTodo();
            if (pagina === "continuidad" || pagina === "proyectos") lanzador.abrirCon("proyecto");
            else flujo.abrir(pagina);
        }
        function cerrar(): void { flujo.abierto = false; }
        function estado(): string { return JSON.stringify({abierto:flujo.abierto,pagina:flujo.pagina,ocupado:flujo.ocupado,proyectos:flujo.proyectos.length,seleccion:!!flujo.seleccion.token}); }
    }

    // Selectores que sustituyen a fuzzel
    //   qs ipc call wallpapers toggle · qs ipc call portapapeles toggle · qs ipc call menu capturas
    function abrirCentro(seccion) {
        const cerrar = centro.abierto && centro.seccion === seccion;
        cerrarTodo();
        if (!cerrar) centro.abrirEn(seccion);
    }
    function cerrarTodo() { agente.abierto = false; movil.abierto = false; brujula.abierto = false; flujo.abierto = false; mesa.abierto = false; lanzador.abierto = false; centro.abierto = false;
                            wallpapers.abierto = false; portapapeles.abierto = false; menu.abierto = false;
                            chuleta.abierto = false; impresora.abierto = false;
                            vista.abierto = false; ia.abierto = false; nota.abierto = false; resumen.abierto = false; }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { const a = wallpapers.abierto; cerrarTodo(); wallpapers.abierto = !a; }
    }
    IpcHandler {
        target: "portapapeles"
        function toggle(): void { const a = portapapeles.abierto; cerrarTodo(); portapapeles.abierto = !a; }
        function copiarId(id: string): void { portapapeles.copiar({ id: id }); }   // lo mismo que un clic (pruebas)
    }
    // Impresora (SUPER+A y luego I): qs ipc call impresora toggle
    IpcHandler {
        target: "impresora"
        function toggle(): void { const a = impresora.abierto; cerrarTodo(); impresora.abierto = !a; }
        function estado(): string { return JSON.stringify({abierto:impresora.abierto,estado:impresora.textoEstado,trabajos:impresora.trabajos.length}); }
    }
    IpcHandler {
        target: "menu"
        function cerrar(): void { menu.abierto = false; }
        // Menú con las opciones que diga quien llama (scripts y módulos Lua), por scripts/menu.sh:
        //   menu.sh "Título" '[{"icono":983324,"texto":"…","cmd":"…"}]'
        // Llega en base64: «qs ipc call» parte los argumentos por las comas.
        function json(titulo: string, opcionesB64: string): void {
            cerrarTodo();
            try { menu.abrirCon(titulo, JSON.parse(Qt.atob(opcionesB64))); }   // Qt.atob ya devuelve el texto en UTF-8
            catch (e) { console.warn("menu json:", e); }
        }
        // Asistente local sobre lo seleccionado (SUPER+ALT+A → scripts/ia.sh)
        function ia(): void {
            cerrarTodo();
            const c = "~/.config/hypr/scripts/ia.sh ";
            menu.abrirCon("Asistente · sobre el texto seleccionado", [
                { icono: 0xF0284, texto: "Resumir",                    cmd: c + "resumir" },
                { icono: 0xF0E1E, texto: "Corregir ortografía",        cmd: c + "corregir" },
                { icono: 0xF03EB, texto: "Redactar mejor",             cmd: c + "mejorar" },
                { icono: 0xF02D7, texto: "Explicar (texto o error)",   cmd: c + "explicar" },
                { icono: 0xF05CA, texto: "Traducir",                   cmd: c + "traducir" },
                { icono: 0xF06A9, texto: "Preguntar sobre el texto…",  cmd: c + "preguntar" }
            ]);
        }
        // Modo concentración (SUPER+SHIFT+F): opciones según haya sesión o no
        function concentracion(): void {
            cerrarTodo();
            const q = "qs ipc call concentracion ";
            menu.abrirCon(Concentracion.activo ? "Concentración · quedan " + Concentracion.texto() : "Concentración",
                Concentracion.activo
                ? [ { icono: 0xF0415, texto: "Añadir 10 min", cmd: q + "sumar 10" },
                    { icono: 0xF04DB, texto: "Terminar ahora", cmd: q + "terminar" } ]
                : [ { icono: 0xF04FE, texto: "25 min (pomodoro)", cmd: q + "empezar 25" },
                    { icono: 0xF04FE, texto: "50 min",             cmd: q + "empezar 50" },
                    { icono: 0xF04FE, texto: "90 min",             cmd: q + "empezar 90" } ]);
        }
        // Pantalla externa conectada (modulos/presentacion.lua; SUPER+ALT+P)
        function pantalla(nombre: string): void {
            cerrarTodo();
            const h = f => `hyprctl dispatch 'pantalla.${f}("${nombre}") or hl.dsp.no_op()'`;
            menu.abrirCon("Pantalla conectada: " + nombre, [
                { icono: 0xF0379, texto: "Duplicar (proyector)",  cmd: h("duplicar") },
                { icono: 0xF0E51, texto: "Extender a la derecha", cmd: h("extender") },
                { icono: 0xF0379, texto: "Solo la externa",       cmd: h("solo_externa") },
                { icono: 0xF0322, texto: "Solo el portátil",      cmd: h("solo_portatil") }
            ]);
        }
        // Grabar pantalla (SUPER+ALT+R → grabar.sh)
        function grabar(): void {
            cerrarTodo();
            const c = "~/.config/hypr/scripts/grabar.sh ";
            menu.abrirCon("Grabar pantalla", [
                { icono: 0xF0A6D, texto: "Región",                cmd: c + "region" },
                { icono: 0xF0E51, texto: "Pantalla completa",     cmd: c + "pantalla" },
                { icono: 0xF075A, texto: "Región con audio",      cmd: c + "region-audio" },
                { icono: 0xF075A, texto: "Pantalla con audio",    cmd: c + "pantalla-audio" },
                { icono: 0xF0D78, texto: "Región como GIF",       cmd: c + "gif" }
            ]);
        }
        // Filtros de pantalla (SUPER+ALT+S → modulos/shaders.lua)
        function shaders(): void {
            cerrarTodo();
            const h = n => `hyprctl dispatch 'shader.poner("${n}") or hl.dsp.no_op()'`;
            menu.abrirCon("Filtro de pantalla", [
                { icono: 0xF0156, texto: "Ninguno",              cmd: h("") },
                { icono: 0xF0E4D, texto: "Escala de grises",     cmd: h("grises") },
                { icono: 0xF00BA, texto: "Papel (sepia)",        cmd: h("papel") },
                { icono: 0xF03D8, texto: "Colores vivos",        cmd: h("vivo") },
                { icono: 0xF0594, texto: "Invertido",            cmd: h("invertido") }
            ]);
        }
        // Mejora de sonido (SUPER+ALT+E → scripts/sonido.sh, EasyEffects)
        function sonido(actual: string): void {
            cerrarTodo();
            const c = "~/.config/hypr/scripts/sonido.sh ";
            const m = (n, t) => (actual === n ? "● " : "") + t;
            menu.abrirCon("Sonido de las bocinas", [
                { icono: 0xF075A, texto: m("Portatil", "Música (más cuerpo y brillo)"), cmd: c + "Portatil" },
                { icono: 0xF036C, texto: m("Voz", "Voz (clases, vídeos, llamadas)"),    cmd: c + "Voz" },
                { icono: 0xF0581, texto: m("off", "Sin efectos"),                       cmd: c + "off" }
            ]);
        }
        function capturas(): void {
            cerrarTodo();
            const c = "~/.config/hypr/scripts/capturas.sh ";
            menu.abrirCon("Capturas", [
                { icono: 0xF0A6D, texto: "Región",            cmd: c + "region" },
                { icono: 0xF0E51, texto: "Pantalla completa", cmd: c + "pantalla" },
                { icono: 0xF10AC, texto: "Ventana activa",    cmd: c + "ventana" },
                { icono: 0xF051B, texto: "Pantalla en 5 s",   cmd: c + "temporizador" },
                { icono: 0xF03EB, texto: "Región y anotar",   cmd: c + "anotar" },
                { icono: 0xF0EF1, texto: "Copiar texto (OCR)", cmd: "~/.config/hypr/scripts/ocr.sh" }
            ]);
        }
    }

    // Wi-Fi y Bluetooth (clic en la red de la barra, clic derecho en los botones del centro):
    // la pestaña Conexiones del centro de control.  qs ipc call conexiones toggle · wifi · bluetooth · estado
    IpcHandler {
        target: "conexiones"
        function toggle(): void { const a = centro.abierto && centro.seccion === "conexiones"; cerrarTodo(); if (!a) centro.abrirEn("conexiones"); }
        function wifi(): void { cerrarTodo(); centro.abrirEn("conexiones", "wifi"); }
        function bluetooth(): void { cerrarTodo(); centro.abrirEn("conexiones", "bluetooth"); }
        function estado(): string {
            const l = centro.listaConexiones;
            return `wifi=${l.wifi ? "si" : "no"} redes=${l.redes.length} bt=${l.adaptador?.enabled ?? false} dispositivos=${l.dispositivos.length}`;
        }
    }

    // Recordatorios (también: «recordar 20m …» en el lanzador)
    IpcHandler {
        target: "recordatorios"
        function agregar(texto: string): string {
            const r = Recordatorios.interpretar(texto);
            if (!r) return "no entendí la hora";
            Recordatorios.agregar(r.cuando, r.texto); return "ok: " + Recordatorios.cuandoTexto(r.cuando);
        }
        function lista(): string { return Recordatorios.lista.map(x => `${x.id}  ${Recordatorios.cuandoTexto(x.cuando)}  ${x.texto}`).join("\n"); }
        function borrar(id: string): void { Recordatorios.borrar(id); }
    }

    // Vista general (SUPER+ESPACIO, SUPER + 3 dedos arriba): qs ipc call vista toggle
    IpcHandler {
        target: "vista"
        function toggle(): void { const a = vista.abierto; cerrarTodo(); if (!a) vista.alternar(); }   // alternar(): captura para el zoom y abre
        function datos(): string {   // diagnóstico: monitor y ventanas
            const m = Hyprland.focusedMonitor;
            return `monitor ${m?.name} ${m?.width}x${m?.height} @${m?.x},${m?.y} escala ${m?.scale} · ` +
                   Hyprland.toplevels.values.slice(0, 3).map(t => `${t.address} ws${t.workspace?.id} at=${t.lastIpcObject?.at} size=${t.lastIpcObject?.size}`).join(" | ");
        }
    }

    // Asistente local, nota rápida, resumen del día, actualizaciones y pausas
    IpcHandler {
        target: "ia"
        function abrir(accion: string, pregunta: string): void { cerrarTodo(); ia.abrirCon(accion, pregunta); }
        function estado(): string { return `${ia.accion} pensando=${ia.pensando} caracteres=${ia.respuesta.length} error=${ia.error}`; }
    }
    IpcHandler {
        target: "nota"
        function abrir(): void { const a = nota.abierto; cerrarTodo(); nota.abierto = !a; }
    }
    IpcHandler {
        target: "resumen"
        function mostrar(): void { cerrarTodo(); resumen.mostrar(); }
    }
    IpcHandler {
        target: "actualizaciones"
        function refrescar(): void { Actualizaciones.refrescar(); }
        function estado(): string { return `repos=${Actualizaciones.repos} aur=${Actualizaciones.aur} noticias=${Actualizaciones.noticias} vulnerables=${Actualizaciones.vulnerables}`; }
        function simular(n: int): void { Actualizaciones.repos = n; Actualizaciones.listo = true; }   // para ver el módulo de la barra
    }
    IpcHandler {
        target: "pausas"
        function estado(): string { return `${Pausas.seguidos} min seguidos de ${Pausas.minutos}`; }
    }

    // Chuleta de atajos (SUPER+H): qs ipc call chuleta toggle
    IpcHandler {
        target: "chuleta"
        function toggle(): void { const a = chuleta.abierto; cerrarTodo(); chuleta.abierto = !a; }
        function buscar(texto: string): void { cerrarTodo(); chuleta.abierto = true; chuleta.buscar(texto); }
    }

    // Ayuda al mantener SUPER sola (atajos.lua avisa al pulsar y al soltar)
    IpcHandler {
        target: "ayudaSuper"
        function mantener(): void { if (!chuleta.abierto) ayudaSuper.mantener(); }
        function soltar(): void { ayudaSuper.soltar(); }
        function estado(): string { return JSON.stringify({ visible: ayudaSuper.visible, pulsada: ayudaSuper.pulsada, interrumpida: ayudaSuper.interrumpida, motivo: ayudaSuper.motivo, cursor: ayudaSuper.cursorAntes, esenciales: ayudaSuper.esenciales.length }); }
    }

    // Cargador.qml (enchufar/desenchufar)
    IpcHandler {
        target: "cargador"
        function estado(): string { return Cargador.conBateria ? `batería · antes ${Cargador.perfilAntes}` : "cargador"; }
        function simular(que: string): void { que === "bat" ? Cargador.alDesenchufar() : Cargador.alEnchufar(); }
    }

    IpcHandler {
        target: "concentracion"
        function empezar(minutos: int): void { Concentracion.empezar(minutos); }
        function sumar(minutos: int): void { Concentracion.sumar(minutos); }
        function terminar(): void { Concentracion.terminar(false); }
        function estado(): string { return Concentracion.activo ? "quedan " + Concentracion.texto() : "inactivo"; }
    }

    // Avisar a las barras de que algo cambió:  qs ipc call barra refrescar buds
    // (buds, modo-juego, red, brillo o todo). Lo usan modo_juego.lua, tema.sh y Buds Manager.
    IpcHandler {
        target: "barra"
        function refrescar(que: string): void {
            for (const b of barras.instances) b.refrescar(que);
        }
    }
}
