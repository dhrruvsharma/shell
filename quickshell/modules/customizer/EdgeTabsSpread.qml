pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// Chapter IX, § 2: the edge line's tabs: which of its panels go together
// in a tab (laid out side by side, all open at once), the tabs' names,
// glyphs and order, and the panels left out.
Spread {
    id: spread

    readonly property var line: Services.EdgeLine
    readonly property var tab: spread.line.tabs[spread.line.activeTab] ?? { name: "", panels: [] }

    leftContent: Plate {
        chapter: 9
        opening: false
        title: "The Edge Line"
        section: "Its tabs"
        figure: "Fig. 15."
        caption: "“" + spread.tab.name + "”, as the popout lays it out: " + spread.tab.panels.map(p => spread.line.panel(p)?.name ?? p).join(", ") + ". Click a tab on its strip for another."

        EdgeTabsFigure {
            anchors.fill: parent
            anchors.topMargin: 6
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 2"
        title: "Its tabs"
        intro: "Opened out, the line is one popout with a tab for each group of panels, and a tab lays all of its panels out together, open. Carry a panel to another tab, onto the dotted line for a tab of its own, or onto the shelf to leave it out; five to a tab. Click a tab's glyph to change it, its name to rename it."
        spacing: 16

        EdgeTabEditor {
            width: parent.width
        }

        InkButton {
            icon: "restart_alt"
            text: "Back to the tabs it came with"
            quiet: true
            onClicked: spread.line.resetTabs()
        }
    }
}
