pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The machine: CPU, memory, temperature and disk on the theme's meters,
// named the way the theme's system widget names them, with the uptime.
Column {
    id: root

    spacing: 12

    SectionTitle {
        width: parent.width
        text: ControlStyle.word("sysmon") || "System"

        Text {
            text: ControlStyle.label(ControlStyle.word("uptime")) + "  " + Services.System.uptime
            font.family: ControlStyle.mono
            font.pixelSize: 11
            font.capitalization: ControlStyle.caps
            font.letterSpacing: ControlStyle.upper ? 1.2 : 0
            color: Colors.withAlpha(ControlStyle.ink, 0.55)
        }
    }

    Grid {
        id: grid
        width: parent.width
        columns: 2
        columnSpacing: 22
        rowSpacing: 12

        // A fixed list; each cell reads its own figure, so a poll doesn't
        // rebuild the cells.
        Repeater {
            model: ["cpu", "ram", "temp", "disk"]

            Column {
                id: cell
                required property string modelData
                readonly property real stat: Services.System[modelData]
                width: (grid.width - grid.columnSpacing) / 2
                spacing: 6

                Item {
                    width: parent.width
                    height: name.implicitHeight

                    Text {
                        id: name
                        width: parent.width - figure.implicitWidth - 8
                        elide: Text.ElideRight
                        text: ControlStyle.label(ControlStyle.word(cell.modelData))
                        font.family: ControlStyle.ui
                        font.pixelSize: 12
                        font.capitalization: ControlStyle.caps
                        font.letterSpacing: ControlStyle.upper ? 1.5 : 0.2
                        color: Colors.withAlpha(ControlStyle.ink, 0.75)
                    }

                    Text {
                        id: figure
                        anchors.right: parent.right
                        text: Math.round(cell.stat) + (cell.modelData === "temp" ? "°C" : "%")
                        font.family: ControlStyle.mono
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: ControlStyle.ink
                    }
                }

                Meter {
                    width: parent.width
                    value: cell.stat / 100
                }
            }
        }
    }
}
