pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.wasteland

// A section's title, set the way the theme's desktop widgets title
// themselves: on masking tape (Wasteland), as a kicker under a heavy rule
// (Broadsheet), centred between gilt rules, stars, double dandas or crossed
// swords (Art Deco, Cathedral, Observatory, Devaloka, Siege), beside a lit
// lamp (Abyss), with a ghost in the second neon (Neon Noir), brushed over a
// swash of crimson ink (Sekiro), or plain.
// Anything placed inside goes to the right end of the line.
Item {
    id: root

    property string text
    default property alias trailing: tail.data

    readonly property string frame: ControlStyle.frame
    readonly property bool centred: ["gilt", "lancet", "brass", "patta", "banner"].includes(frame)
    readonly property bool taped: frame === "scrap"
    readonly property real ruleRoom: frame === "clipping" ? 9 : 0
    readonly property real tapeRoom: taped ? 3 : 0
    // A centred title keeps its flanks clear of what sits at the right end:
    // it moves left, into the middle of the room left over, when it must.
    readonly property real flankRoom: !centred ? 0 : frame === "gilt" || frame === "lancet" ? 35 : 26
    readonly property real freeWidth: tail.width > 0 ? width - tail.width - 12 : width

    implicitWidth: label.implicitWidth
    implicitHeight: ruleRoom + Math.max(label.implicitHeight + 2 * tapeRoom, tail.implicitHeight)

    // Broadsheet: the heavy rule over a kicker.
    Rectangle {
        visible: root.frame === "clipping"
        width: parent.width
        height: 3
        color: ControlStyle.ink
    }

    // Wasteland: a strip of masking tape.
    Rectangle {
        visible: root.taped
        x: label.x - 9
        y: label.y - 3
        width: label.implicitWidth + 18
        height: label.implicitHeight + 5
        rotation: -1.5
        color: Waste.tape
        opacity: 0.95
    }

    // Abyss: a lit lamp before the title.
    Rectangle {
        visible: root.frame === "instrument"
        x: 4
        anchors.verticalCenter: label.verticalCenter
        width: 7
        height: 7
        radius: 3.5
        color: ControlStyle.accent2

        Rectangle {
            anchors.centerIn: parent
            width: 15
            height: 15
            radius: 7.5
            color: Colors.withAlpha(ControlStyle.accent2, 0.22)
        }
    }

    // Sekiro: a swash of crimson ink behind it.
    BrushStroke {
        visible: root.frame === "sumi"
        x: 0
        y: label.y + (label.height - height) / 2 + 1
        width: Math.min(root.freeWidth, label.implicitWidth + 64)
        height: label.implicitHeight + 10
        ink: Colors.withAlpha(ControlStyle.accent, 0.55)
        seed: root.text.length * 0.41 + 2
        dry: 0.75
        weight: 0.8
    }

    // Neon Noir: the title doubled like a bad signal.
    Text {
        visible: root.frame === "neon"
        x: label.x + 1.5
        y: label.y
        text: label.text
        font: label.font
        color: Colors.withAlpha(ControlStyle.accent, 0.55)
    }

    // The flanks of a centred title.
    Repeater {
        model: root.centred ? 2 : 0

        Item {
            required property int index
            readonly property bool rule: root.frame === "gilt" || root.frame === "lancet"
            x: index === 0 ? label.x - width - 9 : label.x + label.width + 9
            y: label.y + (label.height - height) / 2
            width: rule ? 26 : root.frame === "banner" ? swords.implicitWidth : mark.implicitWidth
            height: rule ? 1 : root.frame === "banner" ? swords.implicitHeight : mark.implicitHeight

            Rectangle {
                visible: parent.rule
                anchors.fill: parent
                color: ControlStyle.accent
            }

            Text {
                id: mark
                visible: root.frame === "brass" || root.frame === "patta"
                anchors.centerIn: parent
                text: root.frame === "brass" ? "✶" : "॥"
                font.family: root.frame === "patta" ? ControlStyle.display : ControlStyle.body
                font.pixelSize: root.frame === "patta" ? 17 : 11
                color: ControlStyle.accent
            }

            Glyph {
                id: swords
                visible: root.frame === "banner"
                anchors.centerIn: parent
                text: "swords"
                font.pixelSize: 16
                color: Colors.withAlpha(ControlStyle.accent2, 0.8)
            }
        }
    }

    Text {
        id: label
        x: root.centred ? Math.round(Math.max(root.flankRoom, Math.min((root.width - implicitWidth) / 2, root.freeWidth - root.flankRoom - implicitWidth)))
            : root.frame === "instrument" ? 18 : root.taped ? 9 : root.frame === "sumi" ? 12 : 0
        y: root.ruleRoom + root.tapeRoom
        rotation: root.taped ? -1.5 : 0
        text: (root.frame === "chamfer" ? "▸ " : "") + ControlStyle.label(root.text)
        font.family: root.taped ? Waste.type : ControlStyle.ui
        font.pixelSize: ({ card: 14, chamfer: 12, console: 13, glass: 12, bare: 13, scroll: 14, neon: 15, washi: 13, gilt: 12, lancet: 17, clipping: 14, scrap: 13, brass: 16, instrument: 12, patta: 16, banner: 17, sumi: 15 })[root.frame] ?? 13
        font.weight: ["chamfer", "clipping", "instrument", "sumi"].includes(root.frame) ? Font.Bold
            : ["neon", "scrap", "brass", "patta", "banner", "lancet"].includes(root.frame) ? Font.Normal
            : root.frame === "card" ? Font.DemiBold : Font.Medium
        font.letterSpacing: ControlStyle.labelSpacing
        font.capitalization: ControlStyle.caps
        color: root.taped ? Waste.tapeInk : root.frame === "sumi" ? "#f3ecdf" : ControlStyle.labelColor
    }

    Row {
        id: tail
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        spacing: 10
    }
}
