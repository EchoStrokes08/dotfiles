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
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: v
    property bool activado: true            // lo cambia shell.qml (IPC escritorio toggle)

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property bool vacio: (monitor?.activeWorkspace?.toplevels.values.length ?? 0) === 0
    readonly property bool mostrar: activado && vacio
    readonly property color claro: "#f3efe0"

    visible: todo.opacity > 0
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

    Item {
        id: todo
        anchors.fill: parent
        opacity: v.mostrar ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: v.mostrar ? 600 : 180; easing.type: Easing.OutCubic } }

        // Sombra suave bajo todo el texto: legible sobre fondos claros u oscuros
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.75
            shadowBlur: 0.7
            shadowVerticalOffset: 2
        }

        // ── Reloj, fecha, clima y frase ──
        ColumnLayout {
            id: izquierda
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 56; bottomMargin: 52 + (v.mostrar ? 0 : -14) }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
            spacing: 0

            Row {
                spacing: 0
                Text { text: Qt.formatTime(reloj.date, "HH"); color: Paleta.naranja
                       font { family: Paleta.fuente; pixelSize: 104; bold: true } }
                Text { text: ":"; color: Qt.alpha(v.claro, 0.55)
                       font { family: Paleta.fuente; pixelSize: 104; bold: true } }
                Text { text: Qt.formatTime(reloj.date, "mm"); color: Paleta.azul
                       font { family: Paleta.fuente; pixelSize: 104; bold: true } }
            }
            Text {
                Layout.topMargin: -8
                text: reloj.date.toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM")
                color: v.claro
                font { family: Paleta.fuente; pixelSize: 20; capitalization: Font.Capitalize }
            }
            Text {   // clima (solo cuando ya llegó el dato)
                Layout.topMargin: 8
                visible: Clima.listo
                text: `${Clima.icono(Clima.codigo, Clima.deDia)}  ${Math.round(Clima.temp)}°  ${Clima.texto(Clima.codigo)} en ${Clima.lugar}`
                      + (Clima.lluviaHoy >= 30 ? `  ·  lluvia ${Clima.lluviaHoy} %` : "")
                color: Qt.alpha(v.claro, 0.8)
                font { family: Paleta.fuente; pixelSize: 13 }
            }
            Rectangle {   // rayita naranja
                Layout.topMargin: 20; Layout.bottomMargin: 14
                width: 44; height: 3; radius: 2; color: Paleta.naranja
            }
            Text {
                Layout.maximumWidth: 460
                text: "«" + v.frase[0] + "»"
                wrapMode: Text.WordWrap
                color: Qt.alpha(v.claro, 0.92)
                font { family: Paleta.fuente; pixelSize: 14; italic: true }
                lineHeight: 1.25
            }
            Text {
                Layout.topMargin: 6
                text: "— " + v.frase[1]
                color: Qt.alpha(v.claro, 0.6)
                font { family: Paleta.fuente; pixelSize: 11 }
            }
        }

        // ── Lo próximo ──
        ColumnLayout {
            visible: v.proximo.length > 0
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 56; bottomMargin: 56 }
            spacing: 10
            Text {
                Layout.alignment: Qt.AlignRight
                text: "LO PRÓXIMO"
                color: Paleta.naranja
                font { family: Paleta.fuente; pixelSize: 11; bold: true; letterSpacing: 2 }
            }
            Repeater {
                model: v.proximo
                RowLayout {
                    required property var modelData
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    ColumnLayout {
                        spacing: 1
                        Text {
                            Layout.alignment: Qt.AlignRight
                            Layout.maximumWidth: 320
                            text: modelData.texto
                            elide: Text.ElideRight
                            color: v.claro
                            font { family: Paleta.fuente; pixelSize: 14; bold: true }
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: modelData.cuando
                            color: Qt.alpha(v.claro, 0.65)
                            font { family: Paleta.fuente; pixelSize: 11 }
                        }
                    }
                    Text { text: String.fromCodePoint(modelData.icono); color: Paleta.azul
                           font { family: Paleta.fuente; pixelSize: 20 } }
                }
            }
        }
    }
}
