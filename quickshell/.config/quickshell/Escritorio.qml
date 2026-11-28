// Escritorio: widgets sobre el fondo de pantalla, visibles SOLO cuando el workspace está vacío
// (en cuanto abres una ventana se desvanecen; al cerrar la última, vuelven).
//   · abajo a la izquierda: reloj grande, fecha, clima y la frase del día
//   · abajo a la derecha: lo próximo (eventos del calendario y recordatorios), si hay algo
// Es una capa "bottom": queda por encima del wallpaper y por debajo de las ventanas, y no recibe
// clics (mask vacía), así que el escritorio se comporta igual que antes.
// El texto va siempre en claro con sombra: se lee sobre cualquier wallpaper, con tema claro u oscuro.
//   qs ipc call escritorio toggle   → esconder/mostrar los widgets (hasta cerrar sesión)
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: v
    property bool activado: true            // lo cambia shell.qml (IPC escritorio toggle)

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool vacio: (monitor?.activeWorkspace?.toplevels.values.length ?? 0) === 0
    readonly property bool mostrar: activado && vacio

    // Siempre mapeada: `visible` destruiría y recrearía la ventana en cada cambio de espacio, justo
    // cuando cambian sus textos, y eso tumba Quickshell (ver Barra.qml). Se apaga solo el contenido.
    contentItem.visible: todo.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}                          // sin zona de clic: todo pasa al fondo
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-escritorio"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    // Una frase por día (la misma todo el día): el día del año elige cuál
    readonly property var frases: [
        ["Lo que no se empieza hoy nunca se termina mañana.", "Goethe"],
        ["La simplicidad es la máxima sofisticación.", "Leonardo da Vinci"],
        ["No es que tengamos poco tiempo, es que perdemos mucho.", "Séneca"],
        ["Primero resuelve el problema. Después, escribe el código.", "John Johnson"],
        ["Hecho es mejor que perfecto.", "Sheryl Sandberg"],
        ["La disciplina es elegir entre lo que quieres ahora y lo que más quieres.", "Abraham Lincoln"],
        ["Somos lo que hacemos repetidamente.", "Will Durant"],
        ["El que tiene un porqué puede soportar casi cualquier cómo.", "Nietzsche"],
        ["Hablar es barato. Enséñame el código.", "Linus Torvalds"],
        ["La mejor forma de predecir el futuro es inventarlo.", "Alan Kay"],
        ["Cualquier tonto escribe código que entiende una máquina. Los buenos escriben código que entienden las personas.", "Martin Fowler"],
        ["No cuentes los días, haz que los días cuenten.", "Muhammad Ali"],
        ["Caminante, no hay camino: se hace camino al andar.", "Antonio Machado"],
        ["La suerte es lo que pasa cuando la preparación se encuentra con la oportunidad.", "Séneca"],
        ["Si no puedes explicarlo de forma sencilla, no lo entiendes lo suficiente.", "Albert Einstein"],
        ["Haz que funcione, haz que esté bien, haz que sea rápido. En ese orden.", "Kent Beck"],
        ["La motivación te pone en marcha. El hábito te mantiene.", "Jim Ryun"],
        ["El mejor momento para plantar un árbol fue hace veinte años. El segundo mejor es ahora.", "Proverbio chino"],
        ["La perfección se alcanza no cuando no queda nada por añadir, sino cuando no queda nada por quitar.", "Saint-Exupéry"],
        ["Lo único imposible es aquello que no intentas.", "Anónimo"],
        ["Un viaje de mil millas comienza con un solo paso.", "Lao Tse"],
        ["Mide dos veces, corta una.", "Refrán de carpinteros"],
        ["La curiosidad tiene su propia razón de existir.", "Albert Einstein"],
        ["No dejes que lo perfecto sea enemigo de lo bueno.", "Voltaire"],
        ["Aprender sin pensar es inútil. Pensar sin aprender, peligroso.", "Confucio"],
        ["La paciencia es amarga, pero su fruto es dulce.", "Rousseau"],
        ["Cuanto más trabajo, más suerte tengo.", "Gary Player"],
        ["Eliminar código es la forma más barata de arreglarlo.", "Refrán de programadores"],
        ["El descanso también es parte del trabajo.", "Anónimo"],
        ["Empieza donde estás. Usa lo que tienes. Haz lo que puedas.", "Arthur Ashe"],
        ["Las cosas no se dicen, se hacen; porque al hacerlas se dicen solas.", "Woody Allen"],
        // ── Estoicos y filosofía ──
        ["Solo sé que no sé nada.", "Sócrates"],
        ["Conócete a ti mismo.", "Oráculo de Delfos"],
        ["La felicidad de tu vida depende de la calidad de tus pensamientos.", "Marco Aurelio"],
        ["Tienes poder sobre tu mente, no sobre los acontecimientos.", "Marco Aurelio"],
        ["Lo que estorba a la acción hace avanzar la acción. El obstáculo es el camino.", "Marco Aurelio"],
        ["No nos afectan las cosas, sino lo que pensamos sobre ellas.", "Epicteto"],
        ["Mientras esperamos a vivir, la vida pasa.", "Séneca"],
        ["No hay viento favorable para el que no sabe a qué puerto va.", "Séneca"],
        ["Sufrimos más en la imaginación que en la realidad.", "Séneca"],
        ["Pienso, luego existo.", "Descartes"],
        ["Los límites de mi lenguaje son los límites de mi mundo.", "Wittgenstein"],
        ["Lo que no me mata me hace más fuerte.", "Nietzsche"],
        ["El hombre está condenado a ser libre.", "Sartre"],
        ["Hay que imaginar a Sísifo feliz.", "Albert Camus"],
        ["En lo más crudo del invierno aprendí que había en mí un verano invencible.", "Albert Camus"],
        ["Cuando ya no podemos cambiar una situación, tenemos el reto de cambiarnos a nosotros mismos.", "Viktor Frankl"],
        ["La atención es la forma más rara y más pura de generosidad.", "Simone Weil"],
        ["Cómo pasamos los días es, por supuesto, cómo pasamos la vida.", "Annie Dillard"],
        ["Dime a qué prestas atención y te diré quién eres.", "Ortega y Gasset"],
        ["Yo soy yo y mi circunstancia.", "Ortega y Gasset"],
        ["El mapa no es el territorio.", "Alfred Korzybski"],
        // ── Clásicos, refranes y proverbios ──
        ["La gota horada la piedra no por su fuerza, sino por su constancia.", "Ovidio"],
        ["La fortuna favorece a los audaces.", "Virgilio"],
        ["Atrévete a saber.", "Horacio"],
        ["Aprovecha el día.", "Horacio"],
        ["Apresúrate despacio.", "Augusto"],
        ["Vísteme despacio, que tengo prisa.", "Refrán"],
        ["No por mucho madrugar amanece más temprano.", "Refrán"],
        ["Quien mucho abarca, poco aprieta.", "Refrán"],
        ["Más vale maña que fuerza.", "Refrán"],
        ["El saber no ocupa lugar.", "Refrán"],
        ["Cae siete veces, levántate ocho.", "Proverbio japonés"],
        ["El bambú que se dobla es más fuerte que el roble que resiste.", "Proverbio japonés"],
        ["Si quieres ir rápido, ve solo. Si quieres llegar lejos, ve acompañado.", "Proverbio africano"],
        ["Saber que se sabe lo que se sabe y que no se sabe lo que no se sabe: eso es saber.", "Confucio"],
        ["No importa lo despacio que vayas mientras no te detengas.", "Confucio"],
        ["Quien conoce a los demás es sabio; quien se conoce a sí mismo es iluminado.", "Lao Tse"],
        ["La naturaleza no se apresura y, sin embargo, todo se cumple.", "Lao Tse"],
        ["Un barco en el puerto está seguro, pero no es para eso para lo que se construyen los barcos.", "John A. Shedd"],
        // ── Letras ──
        ["La libertad, Sancho, es uno de los más preciosos dones que a los hombres dieron los cielos.", "Cervantes"],
        ["El que lee mucho y anda mucho, ve mucho y sabe mucho.", "Cervantes"],
        ["Hoy es siempre todavía.", "Antonio Machado"],
        ["El que resiste, gana.", "Camilo José Cela"],
        ["Podrán cortar todas las flores, pero no podrán detener la primavera.", "Pablo Neruda"],
        ["Uno no es lo que es por lo que escribe, sino por lo que ha leído.", "Jorge Luis Borges"],
        ["Siempre imaginé que el paraíso sería algún tipo de biblioteca.", "Jorge Luis Borges"],
        ["La vida no es la que uno vivió, sino la que uno recuerda y cómo la recuerda para contarla.", "Gabriel García Márquez"],
        ["Andábamos sin buscarnos, pero sabiendo que andábamos para encontrarnos.", "Julio Cortázar"],
        ["Lo esencial es invisible a los ojos.", "Saint-Exupéry"],
        ["Inténtalo otra vez. Fracasa otra vez. Fracasa mejor.", "Samuel Beckett"],
        ["El primer borrador de cualquier cosa es una basura.", "Ernest Hemingway"],
        ["La lectura es a la mente lo que el ejercicio al cuerpo.", "Joseph Addison"],
        ["No todos los que vagan están perdidos.", "J. R. R. Tolkien"],
        ["Solo tienes que decidir qué hacer con el tiempo que se te ha dado.", "J. R. R. Tolkien"],
        ["El miedo es el asesino de la mente.", "Frank Herbert"],
        ["Que no cunda el pánico.", "Douglas Adams"],
        ["Me encantan las fechas de entrega. Me gusta el silbido que hacen al pasar.", "Douglas Adams"],
        ["Hazlo o no lo hagas, pero no lo intentes.", "Yoda"],
        ["La vida es lo que pasa mientras estás ocupado haciendo otros planes.", "John Lennon"],
        // ── Ciencia ──
        ["La imaginación es más importante que el conocimiento.", "Albert Einstein"],
        ["Todo debería hacerse tan simple como sea posible, pero no más.", "Albert Einstein"],
        ["Si he visto más lejos es porque estoy a hombros de gigantes.", "Isaac Newton"],
        ["Lo que sabemos es una gota; lo que ignoramos, un océano.", "Isaac Newton"],
        ["Nada en la vida debe ser temido, solo comprendido.", "Marie Curie"],
        ["La ciencia es una forma de pensar mucho más que un cuerpo de conocimientos.", "Carl Sagan"],
        ["Afirmaciones extraordinarias requieren pruebas extraordinarias.", "Carl Sagan"],
        ["Lo que no puedo crear, no lo entiendo.", "Richard Feynman"],
        ["El primer principio es no engañarte a ti mismo, y tú eres la persona más fácil de engañar.", "Richard Feynman"],
        ["El azar favorece a la mente preparada.", "Louis Pasteur"],
        ["La mejor manera de tener una buena idea es tener muchas ideas.", "Linus Pauling"],
        ["Todos los modelos son erróneos, pero algunos son útiles.", "George Box"],
        ["Sin datos, solo eres otra persona con una opinión.", "W. Edwards Deming"],
        ["La explicación más sencilla suele ser la correcta.", "Navaja de Ockham"],
        ["Nunca atribuyas a la maldad lo que se explica por la estupidez.", "Navaja de Hanlon"],
        // ── Informática y tecnología ──
        ["La optimización prematura es la raíz de todos los males.", "Donald Knuth"],
        ["Los programas deben escribirse para que los lean las personas, y solo de paso para que los ejecuten las máquinas.", "Harold Abelson"],
        ["La simplicidad es requisito de la fiabilidad.", "Edsger Dijkstra"],
        ["Depurar es el doble de difícil que escribir el código. Si lo escribes tan ingenioso como puedes, no sabrás depurarlo.", "Brian Kernighan"],
        ["Los malos programadores se preocupan por el código. Los buenos, por las estructuras de datos.", "Linus Torvalds"],
        ["Añadir gente a un proyecto retrasado lo retrasa más.", "Fred Brooks"],
        ["Haz una sola cosa y hazla bien.", "Filosofía Unix"],
        ["Solo hay dos cosas difíciles en informática: invalidar cachés y poner nombres.", "Phil Karlton"],
        ["El primer noventa por ciento del código ocupa el noventa por ciento del tiempo. El diez restante, el otro noventa.", "Tom Cargill"],
        ["La frase más peligrosa es: siempre se ha hecho así.", "Grace Hopper"],
        ["Es más fácil pedir perdón que pedir permiso.", "Grace Hopper"],
        ["Las máquinas me sorprenden muy a menudo.", "Alan Turing"],
        ["Solo podemos ver un poco del futuro, pero lo suficiente para darnos cuenta de que hay mucho por hacer.", "Alan Turing"],
        ["La máquina analítica teje patrones algebraicos igual que el telar de Jacquard teje flores y hojas.", "Ada Lovelace"],
        ["Cualquier tecnología suficientemente avanzada es indistinguible de la magia.", "Arthur C. Clarke"],
        ["El futuro ya está aquí, solo que no está repartido por igual.", "William Gibson"],
        ["El diseño no es solo cómo se ve y cómo se siente. El diseño es cómo funciona.", "Steve Jobs"],
        ["Si no te avergüenza la primera versión de tu producto, la lanzaste demasiado tarde.", "Reid Hoffman"],
        ["Si algo puede salir mal, saldrá mal.", "Ley de Murphy"],
        ["El noventa por ciento de todo es basura.", "Ley de Sturgeon"],
        ["Siempre lleva más tiempo del previsto, incluso teniendo en cuenta la ley de Hofstadter.", "Ley de Hofstadter"],
        ["El trabajo se expande hasta llenar el tiempo disponible.", "Ley de Parkinson"],
        // ── Trabajo, oficio y constancia ──
        ["Menos es más.", "Mies van der Rohe"],
        ["La forma sigue a la función.", "Louis Sullivan"],
        ["El buen diseño es el menor diseño posible.", "Dieter Rams"],
        ["Los planes no son nada; la planificación lo es todo.", "Dwight Eisenhower"],
        ["Lo importante rara vez es urgente, y lo urgente rara vez es importante.", "Dwight Eisenhower"],
        ["No hay nada tan inútil como hacer con gran eficiencia algo que no debería hacerse.", "Peter Drucker"],
        ["Lo que se mide, se mejora.", "Peter Drucker"],
        ["Que la inspiración te encuentre trabajando.", "Pablo Picasso"],
        ["Todo niño es un artista. El problema es seguir siéndolo al crecer.", "Pablo Picasso"],
        ["No he fracasado. He encontrado diez mil formas que no funcionan.", "Thomas Edison"],
        ["El genio es un uno por ciento de inspiración y un noventa y nueve por ciento de transpiración.", "Thomas Edison"],
        ["He fallado una y otra vez en mi vida. Por eso he tenido éxito.", "Michael Jordan"],
        ["Fallas el cien por cien de los tiros que no haces.", "Wayne Gretzky"],
        ["Siempre parece imposible hasta que se hace.", "Nelson Mandela"],
        ["La educación es el arma más poderosa para cambiar el mundo.", "Nelson Mandela"],
        ["Sé agua, amigo mío.", "Bruce Lee"],
        ["No temo al que ha practicado diez mil patadas una vez, sino al que ha practicado una patada diez mil veces.", "Bruce Lee"],
        ["El tiempo que disfrutas perdiendo no es tiempo perdido.", "Marthe Troly-Curtin"],
        ["Hazlo con miedo, pero hazlo.", "Anónimo"]
    ]
    readonly property var frase: {
        const d = reloj.date, inicio = new Date(d.getFullYear(), 0, 0);
        return frases[Math.floor((d - inicio) / 86400000) % frases.length];
    }

    // Lo próximo: eventos y recordatorios mezclados por hora (máx. 4)
    readonly property var proximo: {
        reloj.date;   // se recalcula cada minuto
        const ev = Eventos.proximos(4).map(e => ({ t: e.inicio.getTime(), icono: 0xF00ED, cuando: Eventos.cuando(e), texto: e.titulo }));
        const re = Recordatorios.lista.slice(0, 4).map(r => ({ t: r.cuando, icono: 0xF009A, cuando: Recordatorios.cuandoTexto(r.cuando), texto: r.texto }));
        return ev.concat(re).sort((a, b) => a.t - b.t).slice(0, 4);
    }

    // ── Cielo de noche (de 20:00 a 5:00) ──
    // Fuera de la capa del texto: lo que se mueve aquí no obliga a repintar el reloj ni su sombra.
    // Las estrellas son fijas (las mismas toda la noche: salen de la fecha); con efectos y movimiento
    // (enchufado, perfil cristal) alguna titila despacio y, de vez en cuando, cruza una estrella fugaz.
    readonly property int horaDia: reloj.date.getHours()
    readonly property bool noche: horaDia >= 20 || horaDia < 5
    readonly property bool cieloVivo: noche && mostrar && EstiloPanel.efectos && EstiloPanel.movimiento
    Item {
        id: cielo
        anchors.fill: parent
        opacity: v.noche && v.mostrar ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: EstiloPanel.movimiento ? 2000 : 0; easing.type: Easing.InOutSine } }

        readonly property var estrellas: {
            const d = reloj.date, semilla0 = d.getFullYear() * 400 + d.getMonth() * 31 + d.getDate() - (d.getHours() < 5 ? 1 : 0);
            let semilla = semilla0 >>> 0;
            const azar = () => { semilla = (semilla * 1664525 + 1013904223) >>> 0; return semilla / 4294967296; };
            const r = [];
            for (let i = 0; i < 90; i++) {
                const t = azar();
                r.push({ x: azar(), y: Math.pow(azar(), 1.4) * .62, lado: t > .94 ? 3 : t > .7 ? 2 : 1.5, brillo: .35 + azar() * .6,
                         tinte: azar() > .85 ? (azar() > .5 ? Paleta.acento : Paleta.acento2) : Paleta.sobreImagen });
            }
            return r;
        }
        Repeater {
            id: estrellas
            model: cielo.estrellas
            Item {
                required property var modelData
                property real brillo: modelData.brillo
                x: modelData.x * cielo.width; y: modelData.y * cielo.height
                width: modelData.lado; height: modelData.lado
                opacity: brillo
                Behavior on brillo { NumberAnimation { duration: EstiloPanel.movimiento ? 1600 : 0; easing.type: Easing.InOutSine } }
                RectangularShadow {   // solo las grandes tienen halo
                    anchors.fill: parent
                    visible: parent.modelData.lado >= 3 && EstiloPanel.profundidad
                    radius: width / 2; blur: 8; spread: 1
                    color: Qt.alpha(parent.modelData.tinte, .7)
                }
                Rectangle { anchors.fill: parent; radius: width / 2; color: parent.modelData.tinte }
            }
        }
        // Titileo: cada pocos segundos una estrella baja su brillo y vuelve (solo con cielo vivo)
        Timer {
            interval: 2600; repeat: true; running: v.cieloVivo
            onTriggered: {
                const e = estrellas.itemAt(Math.floor(Math.random() * estrellas.count));
                if (!e) return;
                const base = e.modelData.brillo;
                e.brillo = base * .25;
                vuelta.objetivo = e; vuelta.base = base; vuelta.restart();
            }
        }
        Timer { id: vuelta; property var objetivo: null; property real base: 1; interval: 1700; onTriggered: if (objetivo) objetivo.brillo = base }

        // Estrella fugaz: un trazo con cabeza luminosa que cae en diagonal hacia la derecha (hacia donde apunta) y se apaga
        Item {
            id: fugaz
            visible: false
            width: 170; height: 2
            rotation: 28
            transformOrigin: Item.Right
            Rectangle {
                anchors.fill: parent; radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: .85; color: Qt.alpha(Paleta.sobreImagen, .55) }
                    GradientStop { position: 1; color: Paleta.sobreImagen }
                }
            }
            RectangularShadow {   // cabeza
                x: parent.width - 6; y: -2; width: 6; height: 6
                radius: EstiloPanel.rPunto; blur: 12; spread: 2
                color: Qt.alpha(Qt.lighter(Paleta.acento2, 1.4), .9)
            }
        }
        ParallelAnimation {
            id: vuelo
            property real x0: 0
            property real y0: 0
            NumberAnimation { target: fugaz; property: "x"; from: vuelo.x0; to: vuelo.x0 + 380; duration: 1100; easing.type: Easing.InQuad }
            NumberAnimation { target: fugaz; property: "y"; from: vuelo.y0; to: vuelo.y0 + 200; duration: 1100; easing.type: Easing.InQuad }
            SequentialAnimation {
                NumberAnimation { target: fugaz; property: "opacity"; from: 0; to: 1; duration: EstiloPanel.rapido }
                PauseAnimation { duration: 600 }
                NumberAnimation { target: fugaz; property: "opacity"; to: 0; duration: EstiloPanel.lento }
            }
            onStarted: fugaz.visible = true
            onStopped: fugaz.visible = false
        }
        function lanzarFugaz() {
            vuelo.x0 = cielo.width * (.05 + Math.random() * .55);
            vuelo.y0 = cielo.height * (.04 + Math.random() * .25);
            vuelo.restart();
        }
        Timer {
            id: proximaFugaz
            running: v.cieloVivo
            repeat: true
            interval: 30000
            onTriggered: { cielo.lanzarFugaz(); interval = 25000 + Math.random() * 45000; }
        }
    }

    ComposicionEscritorio {
        id: todo
        anchors.fill: parent
        opacity: v.mostrar ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: v.mostrar && EstiloPanel.movimiento ? 600 : EstiloPanel.normal; easing.type: Easing.OutCubic }
        }
        ahora: reloj.date
        frase: v.frase
        agenda: EstadoEscritorio.privacidad || EstadoEscritorio.capturaPrivada ? [] : v.proximo
        clima: Clima.listo ? ({
            icono: Clima.icono(Clima.codigo, Clima.deDia),
            grados: Math.round(Clima.temp) + "°",
            detalle: Clima.texto(Clima.codigo) + " en " + Clima.lugar
                + (Clima.lluviaHoy >= 30 ? " · lluvia " + Clima.lluviaHoy + " %" : "")
        }) : null
    }
}
