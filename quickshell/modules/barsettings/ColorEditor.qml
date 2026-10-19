pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The colour section: what's being coloured (the containers, or their
// text), where the colour comes from (the wallpaper, or picked by hand),
// and the tones or the picker for it.
Item {
    id: root

    // "fill" (the containers) or "ink" (their text).
    property string target: "fill"
    readonly property var bs: Services.BarSettings
    readonly property bool custom: root.target === "fill" ? root.bs.colorMode === "custom" : root.bs.textMode === "custom"
    readonly property bool typing: hsv.typing

    Segmented {
        id: source
        options: [
            { id: "wallpaper", label: "From wallpaper", icon: "wallpaper" },
            { id: "custom", label: "Pick a colour", icon: "colorize" }
        ]
        current: root.custom ? "custom" : "wallpaper"
        onChosen: choice => {
            if (root.target === "fill")
                root.bs.setColorMode(choice);
            else
                root.bs.setTextMode(choice);
        }
    }

    StyledText {
        anchors.left: source.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.verticalCenter: source.verticalCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.pixelSize: 12
        color: Colors.on_surface_variant
        text: root.custom ? "Stays as you set it, whatever the wallpaper."
            : root.target === "fill" ? "Matugen's scheme: changes with every wallpaper."
            : "Matugen's colours: change with every wallpaper."
    }

    // ── The wallpaper's tones ────────────────────────────────────────────────
    Item {
        id: tonesView
        anchors.top: source.bottom
        anchors.topMargin: 18
        width: parent.width
        height: parent.height - y
        visible: !root.custom

        Grid {
            id: toneGrid
            columns: 4
            columnSpacing: 10
            rowSpacing: 10

            readonly property var list: root.target === "fill" ? root.bs.tones : root.bs.textTones
            readonly property real cell: (tonesView.width - (toneGrid.columns - 1) * toneGrid.columnSpacing) / toneGrid.columns

            Repeater {
                model: toneGrid.list

                ToneSwatch {
                    required property var modelData

                    width: toneGrid.cell
                    label: modelData.name
                    // Containers: each tone's fill with its own text. Text:
                    // each text colour on the containers as they are.
                    fill: root.target === "fill" ? modelData.fill : root.bs.fill
                    ink: root.target === "fill" ? modelData.ink : (modelData.color ?? root.bs.autoInk)
                    chosen: root.target === "fill" ? root.bs.colorMode === "wallpaper" && root.bs.toneId === modelData.id
                        : root.bs.textMode === "wallpaper" && root.bs.textToneId === modelData.id
                    onClicked: {
                        if (root.target === "fill")
                            root.bs.setTone(modelData.id);
                        else
                            root.bs.setTextTone(modelData.id);
                    }
                }
            }
        }

        // What the chosen tone is made of.
        Row {
            id: explanation
            anchors.top: toneGrid.bottom
            anchors.topMargin: 14
            spacing: 8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "palette"
                font.pixelSize: 16
                color: Colors.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: tonesView.width - 24
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: 12
                color: Colors.on_surface_variant
                text: root.target === "fill"
                    ? (root.bs.toneId === "default" ? "Default is the bar as it always looked, on the wallpaper's container surface."
                        : "The " + root.bs.tone.name.toLowerCase() + " tone of the wallpaper's scheme, with the text that goes on it.")
                    : root.bs.textToneId !== "auto" ? "Text in the wallpaper's " + root.bs.textTone.name.toLowerCase() + " colour."
                    : root.bs.customFill ? "Readable is the scheme's light or dark text, whichever stands out on your colour."
                    : "Readable is the text matugen pairs with the containers' tone."
            }
        }
    }

    // How the text reads on the containers: under the tones' explanation,
    // or under the picker's square.
    ContrastBadge {
        id: contrast
        y: root.custom ? parent.height - height : tonesView.y + explanation.y + explanation.height + 12
    }

    // ── Picked by hand ───────────────────────────────────────────────────────
    HsvPicker {
        id: hsv
        anchors.top: source.bottom
        anchors.topMargin: 18
        width: parent.width
        height: parent.height - y
        visible: root.custom
        footer: contrast.height + 12
        value: root.target === "fill" ? root.bs.fill : root.bs.ink
        onPicked: c => {
            if (root.target === "fill")
                root.bs.setCustomColor(c);
            else
                root.bs.setCustomText(c);
        }
    }
}
