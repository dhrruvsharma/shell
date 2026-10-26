pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter I: how things open, on hover or on a click: the launcher, the
// notes drawer and the GitHub/timer popout from the screen's edges, and the
// panels of the bar's widgets; how long a widget waits under the pointer,
// and whether what opened on hover closes again once the pointer leaves.
Spread {
    id: spread

    readonly property var op: Services.Opening
    readonly property var modes: [{ id: "hover", label: "Hover" }, { id: "click", label: "Click" }]

    // Where the bar lies on an edge, that edge's strip opens on a click.
    function onBarNote(edge) {
        return Services.BarLayout.edge === edge ? " The bar is on this edge, so the strip there opens on a click either way." : "";
    }

    leftContent: Plate {
        chapter: 1
        title: "How Things Open"
        epigraph: "Some things come when you reach for them; others wait to be asked."
        figure: "Fig. 1."
        caption: ({
            launcher: "The launcher, from the left edge of the screen.",
            notes: "The notes drawer, from the bottom edge.",
            github: "GitHub and the timer, from the right edge.",
            bar: "A panel from a widget on the bar.",
            barDelay: "A panel from a widget on the bar.",
            closeOnLeave: "A peek closes behind the pointer.",
            closeDelay: "A peek closes behind the pointer."
        })[spread.focusKey] ?? "Where things open from, and how. Point at one opposite to see it."

        OpeningFigure {
            anchors.fill: parent
            pointing: ["barDelay", "closeOnLeave", "closeDelay"].includes(spread.focusKey) ? "bar" : spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Hover or click"
        intro: "What opens as soon as the pointer reaches it, and what waits for a click. Anything that opened on hover is only a peek: it goes again once the pointer leaves it, unless you click into it."
        spacing: 20

        Entry {
            width: parent.width
            key: "launcher"
            label: "The launcher"
            note: "From the left edge of the screen. SUPER+R opens it too." + spread.onBarNote("left")

            InkChoice {
                options: spread.modes
                current: spread.op.launcher
                onChosen: id => spread.op.setMode("launcher", id)
            }
        }

        Entry {
            width: parent.width
            key: "notes"
            label: "The notes drawer"
            note: "From the bottom edge." + spread.onBarNote("bottom")

            InkChoice {
                options: spread.modes
                current: spread.op.notes
                onChosen: id => spread.op.setMode("notes", id)
            }
        }

        Entry {
            width: parent.width
            key: "github"
            label: "GitHub and the timer"
            note: "From the lower part of the right edge." + spread.onBarNote("right")

            InkChoice {
                options: spread.modes
                current: spread.op.github
                onChosen: id => spread.op.setMode("github", id)
            }
        }

        Entry {
            width: parent.width
            key: "bar"
            label: "The bar's panels"
            note: "The calendar, the system, network, media and updates panels, from their widgets. The gear and the memory widget open theirs on a click."

            InkChoice {
                options: spread.modes
                current: spread.op.bar
                onChosen: id => spread.op.setMode("bar", id)
            }
        }

        Entry {
            width: parent.width
            key: "barDelay"
            label: "A widget waits"
            note: "How long the pointer rests on a widget before its panel opens, so sweeping across the bar opens nothing."
            controlWidth: 290
            dim: spread.op.bar !== "hover"

            InkSlider {
                from: 0
                to: 1000
                stepSize: 50
                unit: "ms"
                value: spread.op.barDelay
                onMoved: v => spread.op.setBarDelay(v)
            }
        }

        Entry {
            width: parent.width
            key: "closeOnLeave"
            label: "Peeks close behind you"
            note: "What opened on hover closes again once the pointer has left it and what opened it. A click inside keeps it."

            InkSwitch {
                checked: spread.op.closeOnLeave
                onToggled: spread.op.setCloseOnLeave(!spread.op.closeOnLeave)
            }
        }

        Entry {
            width: parent.width
            key: "closeDelay"
            label: "After"
            note: "Time to reach it from what opened it."
            controlWidth: 290
            dim: !spread.op.closeOnLeave

            InkSlider {
                from: 150
                to: 2000
                stepSize: 50
                unit: "ms"
                value: spread.op.closeDelay
                onMoved: v => spread.op.setCloseDelay(v)
            }
        }

        InkButton {
            icon: "restart_alt"
            text: "As they were"
            quiet: true
            onClicked: spread.op.reset()
        }
    }
}
