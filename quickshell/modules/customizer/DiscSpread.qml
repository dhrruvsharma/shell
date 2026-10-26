pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter III, § 1: whether the workspace disc is always there or tucks
// itself away when you've stayed on one workspace a while, and what brings
// it back out.
Spread {
    id: spread

    readonly property var wd: Services.WorkspaceDiscService
    readonly property bool auto: spread.wd.visibility === "auto"

    leftContent: Plate {
        chapter: 3
        title: "The Workspace Disc"
        epigraph: "It turns to the workspace you're on, and keeps to its corner."
        figure: "Fig. 5."
        caption: spread.auto ? "Its day: tucked away while you work, back as you switch or reach for it." : "At rest it peeks from its corner; pointed at, it opens out."

        Row {
            id: panels
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            spacing: 18

            readonly property int n: spread.auto ? 3 : 2
            readonly property real w: Math.min(250, (parent.width - (n - 1) * 18) / n)

            DiscCorner {
                width: panels.w
                height: 200
                phase: spread.auto ? "tucked" : "peek"
                showZone: spread.auto && spread.wd.revealOnHover
                label: spread.auto ? "a. A while on one workspace: tucked away" + (spread.wd.revealOnHover ? " (the marked corner wakes it)" : "") : "a. At rest: it peeks out"
            }

            DiscCorner {
                width: panels.w
                height: 200
                phase: spread.auto ? (spread.wd.revealOnSwitch ? (spread.wd.openOnSwitch ? "open" : "peek") : "tucked") : "open"
                label: spread.auto ? (spread.wd.revealOnSwitch ? "b. As you switch: back" + (spread.wd.openOnSwitch ? ", opened out" : "") : "b. As you switch: it stays away") : "b. Pointed at: it opens out"
            }

            DiscCorner {
                visible: spread.auto
                width: panels.w
                height: 200
                phase: spread.wd.revealOnHover ? "open" : "tucked"
                label: spread.wd.revealOnHover ? "c. The pointer in its corner: out again" : "c. Only a switch brings it back"
            }
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Showing and hiding"
        intro: "The disc peeks out of its corner and turns to the workspace you're on. It can stay there always, or tuck itself away once you've settled on a workspace and come back when you need it."
        spacing: 22

        Entry {
            width: parent.width
            key: "visibility"
            label: "The disc"
            stacked: true

            InkChoice {
                options: [{ id: "always", label: "Always there" }, { id: "auto", label: "Hides when idle" }]
                current: spread.wd.visibility
                onChosen: id => spread.wd.set("visibility", id)
            }
        }

        Entry {
            width: parent.width
            key: "hideAfter"
            label: "Hides after"
            note: "Time on the same workspace before it tucks itself away."
            controlWidth: 290
            dim: !spread.auto

            InkSlider {
                from: 1
                to: 60
                stepSize: 1
                unit: "s"
                value: spread.wd.hideAfter
                onMoved: v => spread.wd.set("hideAfter", v)
            }
        }

        Entry {
            width: parent.width
            key: "revealOnSwitch"
            label: "Back as you switch"
            note: "It comes out to turn to the new workspace, then waits again."
            dim: !spread.auto

            InkSwitch {
                checked: spread.wd.revealOnSwitch
                onToggled: spread.wd.set("revealOnSwitch", !spread.wd.revealOnSwitch)
            }
        }

        Entry {
            width: parent.width
            key: "revealOnHover"
            label: "Back to the pointer"
            note: "Push the pointer into its corner and it peeks out. While it's away, that small corner of the screen is its."
            dim: !spread.auto

            InkSwitch {
                checked: spread.wd.revealOnHover
                onToggled: spread.wd.set("revealOnHover", !spread.wd.revealOnHover)
            }
        }

        Entry {
            width: parent.width
            key: "openOnSwitch"
            label: "Opens out as you switch"
            note: "Shows every workspace's number for a moment while it turns."

            InkSwitch {
                checked: spread.wd.openOnSwitch
                onToggled: spread.wd.set("openOnSwitch", !spread.wd.openOnSwitch)
            }
        }
    }
}
