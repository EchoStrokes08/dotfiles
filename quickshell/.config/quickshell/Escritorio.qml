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
        ["Las cosas no se dicen, se hacen; porque al hacerlas se dicen solas.", "Woody Allen"]
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
