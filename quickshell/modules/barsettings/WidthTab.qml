pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The panel's Width tab: how wide each container is, and what text that
// no longer fits does.
//
// Every container is Auto (as wide as its text; the media pill 200 px) or
// a width of its own: − and + nudge it 4 px, the slider sets it, and
// switching Auto off keeps the width it had. "All widgets" does the same
// to all of them but the media pill: drag it for one width for all,
// nudge them all, or put them all back to Auto. Their widths "as wide as
// their text" come from the bar's own widgets in the preview (`map`).
//
// Keys (forwarded by the panel): ↑↓ pick a row, ←→ narrower and wider
// (Shift: 16 px), Space or Enter Auto.
Item {
    id: tab

    required property var map
    // 0: All widgets; then each of BarSettings.sizedIds.
    property int sel: 0
    // The picked row shows (picked by key or in the preview); a fresh visit
    // to the tab starts without.
    property bool keyNav: false

    onVisibleChanged: if (!visible) keyNav = false

    readonly property var bs: Services.BarSettings
    readonly property var ids: tab.bs.sizedIds
    readonly property var allIds: tab.ids.filter(i => i !== "media")
    readonly property bool allAuto: tab.allIds.every(i => tab.bs.widthOf(i) === 0)
    readonly property bool allSame: !tab.allAuto && tab.allIds.every(i => tab.bs.widthOf(i) === tab.bs.widthOf(tab.allIds[0]))
    readonly property real allAverage: tab.allIds.reduce((sum, i) => sum + tab.currentOf(i), 0) / Math.max(1, tab.allIds.length)

    function autoWidthOf(id) {
        return tab.bs.autoWidths[id] ?? tab.map.naturals[id] ?? 60;
    }

    function currentOf(id) {
        return tab.bs.widthOf(id) || tab.autoWidthOf(id);
    }

    function nudge(id, d) {
        tab.bs.setWidth(id, tab.currentOf(id) + d);
    }

    // Auto off keeps the width it had; on lets it follow its text again.
    function toggleAuto(id) {
        tab.bs.setWidth(id, tab.bs.widthOf(id) ? 0 : Math.round(tab.autoWidthOf(id)));
    }

    function nudgeAll(d) {
        const changes = {};
        for (const i of tab.allIds)
            changes[i] = tab.currentOf(i) + d;
        tab.bs.setWidths(changes);
    }

    function setAll(w) {
        const changes = {};
        for (const i of tab.allIds)
            changes[i] = w;
        tab.bs.setWidths(changes);
    }

    function toggleAllAuto() {
        const changes = {};
        for (const i of tab.allIds)
            changes[i] = tab.allAuto ? Math.round(tab.autoWidthOf(i)) : 0;
        tab.bs.setWidths(changes);
    }

    // A container picked in the preview.
    function pick(id) {
        const i = tab.ids.indexOf(id);
        if (i >= 0) {
            tab.sel = i + 1;
            tab.keyNav = true;
        }
    }

    function handleKey(event) {
        const n = tab.ids.length + 1;
        const step = event.modifiers & Qt.ShiftModifier ? 16 : 4;
        const id = tab.sel > 0 ? tab.ids[tab.sel - 1] : "";
        const keys = [Qt.Key_Down, Qt.Key_Up, Qt.Key_Left, Qt.Key_Right, Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter];
        if (!keys.includes(event.key))
            return false;
        // Nothing changes until the row it would change is showing as
        // picked: the first key only shows it (it's "All widgets" at first,
        // and a stray arrow shouldn't resize the lot).
        if (!tab.keyNav) {
            tab.keyNav = true;
            return true;
        }
        if (event.key === Qt.Key_Down)
            tab.sel = Math.min(n - 1, tab.sel + 1);
        else if (event.key === Qt.Key_Up)
            tab.sel = Math.max(0, tab.sel - 1);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            const d = event.key === Qt.Key_Left ? -step : step;
            if (id)
                tab.nudge(id, d);
            else
                tab.nudgeAll(d);
        } else {
            if (id)
                tab.toggleAuto(id);
            else
                tab.toggleAllAuto();
        }
        return true;
    }

    // ── The widths ───────────────────────────────────────────────────────────
    SectionCard {
        id: widths
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.round((parent.width - 18) * 0.64)
        title: "Container width"
        icon: "width"

        trailing: [
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.BarLayout.vertical ? "Used when the bar lies along the top or bottom" : "−/+ change it 4 px · drag for any width"
                font.pixelSize: 12
                color: Services.BarLayout.vertical ? Colors.tertiary : Colors.on_surface_variant
            }
        ]

        Column {
            id: rows
            width: parent.width
            spacing: 2

            // All of them in the card: the rows, the rule and the gaps.
            readonly property real rowHeight: Math.min(38, (rows.parent.height - 1 - (tab.ids.length + 1) * rows.spacing) / (tab.ids.length + 1))

            WidthRow {
                width: rows.width
                height: rows.rowHeight
                icon: "select_all"
                name: "All widgets"
                setWidth: tab.allAuto ? 0 : tab.allAverage
                autoWidth: tab.allAverage
                valueText: tab.allAuto ? "All auto" : tab.allSame ? Math.round(tab.bs.widthOf(tab.allIds[0])) + " px each" : "Mixed"
                selected: tab.keyNav && tab.sel === 0
                onClicked: {
                    tab.sel = 0;
                    tab.keyNav = false;
                }
                onAutoClicked: tab.toggleAllAuto()
                onNudged: d => tab.nudgeAll(d)
                onSlid: v => tab.setAll(v)
            }

            // Every widget but the media pill above, it below.
            Rectangle {
                width: rows.width
                height: 1
                color: Colors.withAlpha(Colors.outline_variant, 0.6)
            }

            Repeater {
                model: tab.ids

                WidthRow {
                    required property string modelData
                    required property int index

                    readonly property var entry: tab.bs.info(modelData)

                    width: rows.width
                    height: rows.rowHeight
                    icon: entry ? entry.icon : ""
                    name: entry ? entry.name : modelData
                    setWidth: tab.bs.widthOf(modelData)
                    autoWidth: tab.autoWidthOf(modelData)
                    // Picked by key or in the preview, or pointed at there.
                    selected: (tab.keyNav && tab.sel === index + 1) || tab.map.hoveredId === modelData
                    opacity: tab.bs.shown(modelData) ? 1 : 0.55
                    onClicked: {
                        tab.sel = index + 1;
                        tab.keyNav = false;
                    }
                    onAutoClicked: tab.toggleAuto(modelData)
                    onNudged: d => tab.nudge(modelData, d)
                    onSlid: v => tab.bs.setWidth(modelData, v)
                }
            }
        }
    }

    // ── Text that doesn't fit ────────────────────────────────────────────────
    SectionCard {
        id: overflow
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: widths.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        title: "When text doesn't fit"
        icon: "animation"

        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: [
                    { id: "hover", icon: "mouse", label: "Scroll on hover", hint: "As the media pill does: point at it to read it all" },
                    { id: "always", icon: "autoplay", label: "Keep scrolling", hint: "Runs through, rests a moment, runs again" },
                    { id: "cut", icon: "content_cut", label: "Cut it off", hint: "Ends in …, and never moves" }
                ]

                ClickableRect {
                    id: option

                    required property var modelData
                    readonly property bool chosen: tab.bs.overflow === modelData.id

                    width: parent.width
                    height: 54
                    radius: Services.DesktopTheme.rad(14)
                    color: option.chosen ? Colors.secondary_container : option.hovered ? Colors.surface_container_high : Colors.surface_container
                    border.width: option.chosen ? 1 : 0
                    border.color: Colors.withAlpha(Colors.primary, 0.5)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.bs.setOverflow(option.modelData.id)

                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Glyph {
                        id: optionGlyph
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: option.modelData.icon
                        filled: option.chosen
                        font.pixelSize: 20
                        color: option.chosen ? Colors.on_secondary_container : Colors.on_surface_variant
                    }

                    Column {
                        anchors.left: optionGlyph.right
                        anchors.leftMargin: 12
                        anchors.right: radio.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        StyledText {
                            width: parent.width
                            text: option.modelData.label
                            elide: Text.ElideRight
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: option.chosen ? Colors.on_secondary_container : Colors.on_surface
                        }

                        StyledText {
                            width: parent.width
                            text: option.modelData.hint
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: option.chosen ? Colors.withAlpha(Colors.on_secondary_container, 0.8) : Colors.on_surface_variant
                        }
                    }

                    Rectangle {
                        id: radio
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: option.chosen ? Colors.primary : Colors.outline

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            visible: option.chosen
                            color: Colors.primary
                        }
                    }
                }
            }

            // How fast it scrolls.
            Item {
                width: parent.width
                height: 46
                opacity: tab.bs.overflow === "cut" ? 0.45 : 1

                Glyph {
                    id: speedGlyph
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "speed"
                    font.pixelSize: 20
                    color: Colors.on_surface_variant
                }

                StyledText {
                    anchors.left: speedGlyph.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Speed"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Segmented {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: tab.bs.overflow !== "cut"
                    options: [
                        { id: "slow", label: "Slow" },
                        { id: "normal", label: "Normal" },
                        { id: "fast", label: "Fast" }
                    ]
                    current: tab.bs.scrollSpeed
                    onChosen: choice => tab.bs.setScrollSpeed(choice)
                }
            }

            Item {
                width: 1
                height: 2
            }

            // A pill too narrow for its text, to try the choice on.
            Rectangle {
                width: parent.width
                height: 64
                radius: Services.DesktopTheme.rad(14)
                color: Colors.surface_container_lowest
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.7)

                StyledText {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.BarSettings.overflow === "hover" ? "Point at it →" : "Sample"
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                }

                BarPill {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    text: "󰂯 Galaxy Buds2 Pro · connected"
                    horizontalPadding: 20
                }
            }

            Item {
                width: 1
                height: 4
            }

            // The bar is getting too full for its middle.
            Row {
                width: parent.width
                spacing: 8
                visible: tab.map.crowded && !Services.BarLayout.vertical

                Glyph {
                    text: "warning"
                    filled: true
                    font.pixelSize: 16
                    color: Colors.error
                }

                StyledText {
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    text: "The widgets are reaching the media pill in the middle of the bar: narrow some, or hide a few."
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                }
            }

            Row {
                width: parent.width
                spacing: 8

                Glyph {
                    text: "info"
                    font.pixelSize: 16
                    color: Colors.primary
                }

                StyledText {
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    text: Services.BarLayout.vertical
                        ? "The bar stands on the " + Services.BarLayout.edge + " now, where widgets show a compact upright face; these widths come back when it lies along the top or bottom."
                        : "Widths apply while the bar lies along the top or bottom; on the left or right widgets keep their compact upright face."
                    font.pixelSize: 12
                    lineHeight: 1.1
                    color: Colors.on_surface_variant
                }
            }
        }
    }
}
