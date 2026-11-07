pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter IX, § 1: the edge line (modules/edgeline): whether it's there,
// minimal mode, which border it lives on, how long it is, its glance on
// hover and how it folds up again.
Spread {
    id: spread

    readonly property var line: Services.EdgeLine

    leftContent: Plate {
        chapter: 9
        title: "The Edge Line"
        epigraph: "The whole shell, folded into a line on a border of the screen."
        figure: "Fig. 14."
        caption: spread.line.minimal ? "Minimal mode: nothing else on the screen; the line opens into everything. Click along a border to move it." : "Where it lives, and the popout it opens into. Click along a border of the picture to move it there."

        EdgeLineFigure {
            anchors.fill: parent
            anchors.topMargin: 6
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Living on a border"
        intro: "A thin line on a border of the screen, the workspace you're on lit in it. Point at it for the time; click it and it opens into one popout with tabs, its panels all open at once. Drag it anywhere along any border."
        spacing: 18

        Entry {
            width: parent.width
            key: "enabled"
            label: "The edge line"
            note: "Hidden, it takes minimal mode with it."

            InkSwitch {
                checked: spread.line.enabled
                onToggled: spread.line.setEnabled(!spread.line.enabled)
            }
        }

        Entry {
            width: parent.width
            key: "minimal"
            label: "Minimal mode"
            note: "The bar, the workspace disc, the desktop widgets and the visualizer go; windows take the bar's room and the line does it all."

            InkSwitch {
                checked: spread.line.minimal
                onToggled: spread.line.toggleMinimal()
            }
        }

        Entry {
            width: parent.width
            key: "edge"
            label: "Its border"
            stacked: true

            InkChoice {
                options: [{ id: "top", label: "Top" }, { id: "bottom", label: "Bottom" }, { id: "left", label: "Left" }, { id: "right", label: "Right" }]
                current: spread.line.edge
                spacing: 16
                onChosen: id => spread.line.setEdge(id)
            }
        }

        Entry {
            width: parent.width
            key: "length"
            label: "Its length"
            controlWidth: 290

            InkSlider {
                from: 60
                to: 300
                stepSize: 10
                unit: "px"
                value: spread.line.length
                onMoved: v => spread.line.setLength(v)
            }
        }

        Entry {
            width: parent.width
            key: "peek"
            label: "A glance on hover"
            note: "Pointed at, it swells into a pill: the time, the day or what's playing."

            InkSwitch {
                checked: spread.line.peek
                onToggled: spread.line.setPeek(!spread.line.peek)
            }
        }

        Entry {
            width: parent.width
            key: "closeOnLeave"
            label: "Folds up by itself"
            note: "Once the pointer has left it, unless you're typing in it. Esc, or a click on the strip's bare stretch, folds it too."

            InkSwitch {
                checked: spread.line.closeOnLeave
                onToggled: spread.line.setCloseOnLeave(!spread.line.closeOnLeave)
            }
        }

        Entry {
            width: parent.width
            key: "closeDelay"
            label: "After"
            controlWidth: 290
            dim: !spread.line.closeOnLeave

            InkSlider {
                from: 0.3
                to: 3
                stepSize: 0.1
                decimals: 1
                unit: "s"
                value: spread.line.closeDelay / 1000
                onMoved: v => spread.line.setCloseDelay(v * 1000)
            }
        }

        InkButton {
            icon: "restart_alt"
            text: "Back to the middle of the bottom border"
            quiet: true
            onClicked: spread.line.reset()
        }
    }
}
