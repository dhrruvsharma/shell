pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services

// The bar, § 3: how wide each container is (as wide as its text, or as
// set), and what text that doesn't fit does: scroll on hover, always, or
// stay cut short.
Spread {
    id: spread

    readonly property var bs: Services.BarSettings
    // Each widget as wide as its text, from the plate's strips.
    readonly property var naturals: figure.naturals
    readonly property var pointed: spread.bs.info(spread.focusKey)

    function natural(id) {
        return Math.round(spread.naturals[id] ?? spread.bs.autoWidths[id] ?? 100);
    }

    leftContent: Plate {
        chapter: 2
        title: "The Bar"
        opening: false
        section: "Widths"
        figure: "Fig. 4."
        caption: spread.pointed ? spread.pointed.name + ": " + (spread.bs.widthOf(spread.pointed.id) ? spread.bs.widthOf(spread.pointed.id) + " px wide." : "as wide as its text.")
            : "Point at a container to see its text scroll, or at a row opposite to find it here."

        Item {
            anchors.fill: parent

            BarFigure {
                id: figure
                width: parent.width
                height: figure.stripsHeight
                lit: spread.focusKey
                edges: false
                onPicked: which => spread.focusKey = which
                onHoveredIdChanged: if (hoveredId) spread.focusKey = hoveredId
            }

            // The one being sized, large, with its width over it.
            WidgetDetail {
                anchors.top: figure.bottom
                anchors.topMargin: 20
                anchors.bottom: parent.bottom
                width: parent.width
                widgetId: spread.bs.sizedIds.includes(spread.focusKey) ? spread.focusKey : spread.lastPointed
            }
        }
    }

    // The last widget pointed at (the detail keeps it when the pointer
    // moves on).
    property string lastPointed: "clock"
    onFocusKeyChanged: if (spread.bs.sizedIds.includes(spread.focusKey)) spread.lastPointed = spread.focusKey

    Leaf {
        kicker: "§ 3"
        title: "Widths"
        intro: Services.BarLayout.vertical
            ? "The bar stands on the " + Services.BarLayout.edge + " edge, where every widget shows its upright face: the widths set here apply when it lies along the top or bottom."
            : "How wide each container is. Auto fits it to its text; a width of its own keeps it steady as the text changes."
        spacing: 13

        Entry {
            width: parent.width
            key: "overflow"
            label: "Text that doesn't fit"

            InkChoice {
                options: [{ id: "hover", label: "Scrolls on hover" }, { id: "always", label: "Always" }, { id: "cut", label: "Cut short" }]
                current: spread.bs.overflow
                spacing: 14
                onChosen: id => spread.bs.setOverflow(id)
            }
        }

        Entry {
            width: parent.width
            key: "speed"
            label: "Its pace"
            dim: spread.bs.overflow === "cut"

            InkChoice {
                options: [{ id: "slow", label: "Slow" }, { id: "normal", label: "Steady" }, { id: "fast", label: "Brisk" }]
                current: spread.bs.scrollSpeed
                spacing: 14
                onChosen: id => spread.bs.setScrollSpeed(id)
            }
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        // One for them all, then each.
        Column {
            width: parent.width
            spacing: 2

            WidthRow {
                rowId: "*"
                label: "All of them"
                ids: spread.bs.sizedIds.filter(id => id !== "media")
            }

            Repeater {
                model: spread.bs.sizedIds

                WidthRow {
                    required property string modelData
                    rowId: modelData
                    label: spread.bs.info(modelData)?.name ?? modelData
                    ids: [modelData]
                }
            }
        }

        InkButton {
            visible: !spread.bs.widthsAreDefault
            icon: "fit_width"
            text: "Every one back to auto"
            quiet: true
            onClicked: spread.bs.resetWidths()
        }
    }

    // A widget's width (or all of theirs): its name, a slider, and Auto.
    component WidthRow: Item {
        id: row

        property string rowId: ""
        property string label: ""
        property var ids: []
        readonly property bool auto: row.ids.every(id => spread.bs.widthOf(id) === 0)
        readonly property real width0: row.rowId === "*"
            ? Math.round(row.ids.reduce((a, id) => a + (spread.bs.widthOf(id) || spread.natural(id)), 0) / Math.max(1, row.ids.length))
            : (spread.bs.widthOf(row.rowId) || spread.natural(row.rowId))
        readonly property bool lit: spread.focusKey === row.rowId

        width: parent ? parent.width : 0
        height: 31
        opacity: Services.BarLayout.vertical ? 0.45 : 1

        HoverHandler {
            onHoveredChanged: {
                if (hovered && row.rowId !== "*")
                    spread.focusKey = row.rowId;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -8
            anchors.rightMargin: -8
            radius: BookStyle.b.radius ?? 4
            color: BookStyle.well
            visible: row.lit
        }

        BookText {
            id: name
            anchors.verticalCenter: parent.verticalCenter
            width: 128
            text: row.label
            elide: Text.ElideRight
            font.family: BookStyle.ui
            font.pixelSize: 14
            font.weight: row.rowId === "*" ? Font.DemiBold : Font.Normal
            font.italic: row.rowId === "*"
            font.capitalization: BookStyle.labelCaps
            color: row.lit ? BookStyle.accent : BookStyle.ink
        }

        InkSlider {
            anchors.left: name.right
            anchors.leftMargin: 6
            anchors.right: autoBox.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            from: spread.bs.widthMin
            to: spread.bs.widthMax
            stepSize: 2
            unit: "px"
            readoutWidth: 62
            opacity: row.auto ? 0.5 : 1
            value: row.width0
            mark: row.rowId === "*" ? NaN : spread.natural(row.rowId)
            onMoved: v => {
                const changes = {};
                for (const id of row.ids)
                    changes[id] = v;
                spread.bs.setWidths(changes);
            }
        }

        Row {
            id: autoBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            InkSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: row.auto
                onToggled: {
                    const changes = {};
                    for (const id of row.ids)
                        changes[id] = row.auto ? spread.natural(id) : 0;
                    spread.bs.setWidths(changes);
                }
            }

            BookText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Auto"
                font.pixelSize: 13
                font.italic: true
                color: BookStyle.inkSoft
            }
        }
    }
}
