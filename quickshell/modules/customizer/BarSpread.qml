pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// The bar, § 1: what it shows (every widget, ticked on or off; hidden ones
// keep their place on it), and the screen edge it lies on.
Spread {
    id: spread

    readonly property var bs: Services.BarSettings
    readonly property var pointed: spread.bs.info(spread.focusKey)

    leftContent: Plate {
        chapter: 2
        title: "The Bar"
        epigraph: "Everything along it, and the edge it keeps to."
        figure: "Fig. 2."
        caption: spread.pointed ? spread.pointed.name + (spread.bs.shown(spread.pointed.id) ? ": on the bar. Click it to take it off." : ": off the bar. Click it to bring it back.")
            : "The bar as it stands, in its three stretches; below, the edge it lies on."

        BarFigure {
            anchors.fill: parent
            lit: spread.focusKey
            onPicked: which => spread.bs.toggle(which)
            onHoveredIdChanged: spread.focusKey = hoveredId
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "What it shows"
        intro: "Every widget the bar can carry. Untick one and it leaves the bar but keeps its place there, ready to come back. Drag widgets on the bar itself to change their order."
        spacing: 22

        Entry {
            width: parent.width
            label: "Widgets"
            note: spread.bs.shownCount + " of " + spread.bs.widgets.length + " on the bar"
            stacked: true

            Grid {
                id: grid
                columns: 2
                columnSpacing: 26
                rowSpacing: 4

                Repeater {
                    model: spread.bs.widgets

                    Tick {
                        required property var modelData
                        width: (grid.width - grid.columnSpacing) / 2
                        key: modelData.id
                        icon: modelData.icon
                        label: modelData.name
                        note: modelData.description
                        checked: spread.bs.shown(modelData.id)
                        onToggled: spread.bs.toggle(modelData.id)
                    }
                }
            }
        }

        Row {
            spacing: 22

            InkButton {
                visible: spread.bs.shownCount < spread.bs.widgets.length
                icon: "visibility"
                text: "Show them all"
                onClicked: spread.bs.showAll()
            }

            InkButton {
                icon: "restart_alt"
                text: "Back in their first order"
                quiet: true
                onClicked: Services.BarLayout.reset()
            }
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Entry {
            width: parent.width
            key: "edge"
            label: "The edge it lies on"
            note: "Or press an empty stretch of the bar and drag it to another edge."

            InkChoice {
                options: [{ id: "top", label: "Top" }, { id: "bottom", label: "Bottom" }, { id: "left", label: "Left" }, { id: "right", label: "Right" }]
                current: Services.BarLayout.edge
                spacing: 14
                onChosen: id => Services.BarLayout.setEdge(id)
            }
        }
    }
}
