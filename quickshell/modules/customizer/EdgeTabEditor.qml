pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.modules.lock
import qs.services as Services

// The edge line's tabs, to rearrange: a slip for each tab (its glyph, its
// name, its panels), a dotted line to drop a panel on for a tab of its own,
// and the shelf of panels left out. Carry a panel (EdgePanelChip) to move
// it; a click on a tab (or on a panel in it) picks it, and the facing
// plate draws it (the line opens on it too). A click on a tab's glyph
// changes it, on its name renames it. Five panels to a tab.
Item {
    id: ed

    readonly property var line: Services.EdgeLine
    // The spread, told which panel the pointer is on.
    property var owner: null

    // Carrying a panel: which, where the pointer is (here), what it would
    // land on ({ kind: "tab", tab, at } | { kind: "new" } | { kind:
    // "shelf" }), and where the caret marks it.
    property string carried: ""
    property point carry: Qt.point(0, 0)
    property var target: null
    property rect caret: Qt.rect(0, 0, 0, 0)

    implicitHeight: col.implicitHeight

    // The page's scroller, when the tabs run past its foot.
    property var flick: null

    Component.onCompleted: {
        let p = ed.parent;
        while (p && !("focusKey" in p)) {
            if (!ed.flick && ("contentY" in p) && ("interactive" in p))
                ed.flick = p;
            p = p.parent;
        }
        ed.owner = p;
    }

    // Carried near the page's head or foot, it scrolls the page.
    Timer {
        interval: 16
        repeat: true
        running: ed.carried !== "" && ed.flick !== null && ed.flick.interactive
        onTriggered: {
            const f = ed.flick;
            const p = f.mapFromItem(ed, ed.carry.x, ed.carry.y);
            const zone = 44;
            const d = p.y < zone ? -(zone - p.y) / 4 : p.y > f.height - zone ? (p.y - f.height + zone) / 4 : 0;
            const y = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY + d));
            if (y === f.contentY)
                return;
            ed.carry = Qt.point(ed.carry.x, ed.carry.y + (y - f.contentY));
            f.contentY = y;
            ed.carryTo(ed.carry);
        }
    }

    function pointAt(key) {
        if (!ed.owner)
            return;
        if (key)
            ed.owner.focusKey = key;
        else if (ed.owner.focusKey !== "" && ed.line.panelIds.includes(ed.owner.focusKey))
            ed.owner.focusKey = "";
    }

    function choose(id) {
        const i = ed.line.tabOf(id);
        if (i >= 0)
            ed.line.setActiveTab(i);
    }

    function pickUp(id) {
        ed.carried = id;
        ed.target = null;
    }

    function cancel() {
        ed.carried = "";
        ed.target = null;
    }

    function descendants(item, prop, out) {
        for (const c of item.children) {
            if (prop in c)
                out.push(c);
            ed.descendants(c, prop, out);
        }
        return out;
    }

    function inside(item, p) {
        const q = item.mapFromItem(ed, p.x, p.y);
        return q.x >= 0 && q.y >= 0 && q.x < item.width && q.y < item.height;
    }

    // What the carried panel is over, and where in a tab it would go: before
    // the first panel in it that the pointer is ahead of (row by row).
    function carryTo(p) {
        ed.carry = p;
        const zone = ed.descendants(col, "zoneKind", []).find(z => z.visible && ed.inside(z, p)) ?? null;
        if (!zone) {
            ed.target = null;
            return;
        }
        if (zone.zoneKind !== "tab") {
            ed.target = { kind: zone.zoneKind };
            return;
        }
        const chips = ed.descendants(zone, "chipFor", []);
        let at = chips.length;
        for (let i = 0; i < chips.length; i++) {
            const q = chips[i].mapFromItem(ed, p.x, p.y);
            if (q.y < 0 || (q.y < chips[i].height && q.x < chips[i].width / 2)) {
                at = i;
                break;
            }
        }
        ed.target = { kind: "tab", tab: zone.zoneTab, at: at };
        // The caret: before chip `at`, or after the last one.
        if (chips.length === 0) {
            ed.caret = Qt.rect(0, 0, 0, 0);
        } else {
            const c = chips[Math.min(at, chips.length - 1)];
            const tl = c.mapToItem(ed, 0, 0);
            ed.caret = Qt.rect(at < chips.length ? tl.x - 5 : tl.x + c.width + 3, tl.y, 2, c.height);
        }
    }

    function drop() {
        const t = ed.target, id = ed.carried;
        ed.carried = "";
        ed.target = null;
        if (!t || !id)
            return;
        if (t.kind === "tab")
            ed.line.movePanel(id, t.tab, t.at);
        else if (t.kind === "new")
            ed.line.newTab(id);
        else if (t.kind === "shelf")
            ed.line.leaveOut(id);
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Repeater {
            model: ed.line.tabs

            Rectangle {
                id: slip

                required property var modelData
                required property int index
                readonly property bool here: slip.index === ed.line.activeTab
                readonly property bool full: slip.modelData.panels.length >= ed.line.maxPerTab
                readonly property bool aimed: ed.target !== null && ed.target.kind === "tab" && ed.target.tab === slip.index
                readonly property bool refused: slip.aimed && slip.full && !slip.modelData.panels.includes(ed.carried)
                // (a place to drop on)
                readonly property string zoneKind: "tab"
                readonly property int zoneTab: slip.index

                width: col.width
                height: line1.implicitHeight + 16
                radius: Math.min(BookStyle.b.radius ?? 4, 10)
                color: slip.refused ? Colors.withAlpha(Colors.error, 0.1) : slip.aimed ? Colors.withAlpha(BookStyle.accent, 0.12) : slip.here ? BookStyle.well : "transparent"
                border.width: slip.here || slip.aimed ? 1.5 : 1
                border.color: slip.refused ? Colors.error : slip.here || slip.aimed ? BookStyle.accent : BookStyle.line

                // A click on its bare paper picks it.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ed.line.setActiveTab(slip.index)
                }

                // How full it is; up, down, away.
                Row {
                    id: tools
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 8 + (30 - height) / 2
                    spacing: 2

                    BookText {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 6
                        text: slip.modelData.panels.length + " of " + ed.line.maxPerTab
                        font.family: BookStyle.ui
                        font.pixelSize: 11
                        font.italic: true
                        color: slip.full ? BookStyle.accent : BookStyle.inkFaint
                    }

                    Repeater {
                        model: [
                            { icon: "arrow_upward", tip: "up", on: slip.index > 0 },
                            { icon: "arrow_downward", tip: "down", on: slip.index < ed.line.tabs.length - 1 },
                            { icon: "close", tip: "remove", on: true }
                        ]

                        MouseArea {
                            id: tool
                            required property var modelData
                            width: 26
                            height: 26
                            enabled: tool.modelData.on
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            opacity: tool.enabled ? 1 : 0.25
                            onClicked: {
                                if (tool.modelData.tip === "up")
                                    ed.line.moveTab(slip.index, slip.index - 1);
                                else if (tool.modelData.tip === "down")
                                    ed.line.moveTab(slip.index, slip.index + 1);
                                else
                                    ed.line.removeTab(slip.index);
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.min(BookStyle.b.radius ?? 4, 13)
                                color: tool.containsMouse ? BookStyle.wellHover : "transparent"
                            }

                            Glyph {
                                anchors.centerIn: parent
                                text: tool.modelData.icon
                                font.pixelSize: 16
                                color: tool.containsMouse ? (tool.modelData.tip === "remove" ? Colors.error : BookStyle.accent) : BookStyle.inkSoft
                            }
                        }
                    }
                }

                // Its glyph, number and name, then its panels, wrapping
                // under when they don't fit beside.
                Flow {
                    id: line1
                    x: 10
                    y: 8
                    width: parent.width - 20 - tools.width - 8
                    spacing: 8

                    Item {
                        width: nameRow.implicitWidth + 4
                        height: 30

                        Row {
                            id: nameRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // Its glyph: a click puts another on it.
                            MouseArea {
                                id: glyphArea
                                width: 28
                                height: 28
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ed.line.cycleTabIcon(slip.index)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Math.min(BookStyle.b.radius ?? 4, 8)
                                    color: glyphArea.containsMouse ? BookStyle.wellHover : "transparent"
                                }

                                Glyph {
                                    anchors.centerIn: parent
                                    text: slip.modelData.icon
                                    filled: slip.here
                                    font.pixelSize: 19
                                    color: slip.here ? BookStyle.accent : BookStyle.ink
                                }
                            }

                            BookText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (slip.index + 1) + "."
                                font.family: BookStyle.numeral
                                font.pixelSize: 15
                                color: BookStyle.inkSoft
                            }

                            // Its name, written over.
                            TextInput {
                                id: nameField
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(150, Math.max(56, nameField.contentWidth + 6))
                                text: slip.modelData.name
                                maximumLength: 24
                                color: BookStyle.ink
                                selectionColor: BookStyle.accent
                                selectedTextColor: BookStyle.onAccent
                                font.family: BookStyle.display
                                font.pixelSize: 17
                                clip: true
                                onEditingFinished: {
                                    if (nameField.text !== slip.modelData.name)
                                        ed.line.renameTab(slip.index, nameField.text);
                                }

                                Rectangle {
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 1
                                    width: parent.width
                                    height: 1
                                    color: nameField.activeFocus ? BookStyle.accent : BookStyle.line
                                    opacity: nameField.activeFocus ? 1 : 0.5
                                }
                            }
                        }
                    }

                    Repeater {
                        model: slip.modelData.panels

                        EdgePanelChip {
                            required property string modelData
                            panelId: modelData
                            editor: ed
                        }
                    }
                }
            }
        }

        // The dotted line: drop a panel here for a tab of its own.
        Item {
            id: newZone

            readonly property string zoneKind: "new"
            readonly property bool aimed: ed.target !== null && ed.target.kind === "new"

            visible: ed.line.tabs.length < ed.line.maxTabs
            width: col.width
            height: 46

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: newZone.aimed ? Colors.withAlpha(BookStyle.accent, 0.12) : "transparent"
                    strokeColor: newZone.aimed ? BookStyle.accent : BookStyle.inkFaint
                    strokeWidth: 1.2
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 3]

                    PathRectangle {
                        x: 0.6
                        y: 0.6
                        width: newZone.width - 1.2
                        height: newZone.height - 1.2
                        radius: Math.min(BookStyle.b.radius ?? 4, 10)
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "add"
                    font.pixelSize: 17
                    color: newZone.aimed ? BookStyle.accent : BookStyle.inkSoft
                }

                BookText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Drop a panel here for a tab of its own"
                    font.italic: true
                    font.pixelSize: BookStyle.bodySize - 1
                    color: newZone.aimed ? BookStyle.accent : BookStyle.inkSoft
                }
            }
        }

        // The shelf: the panels left out.
        Rectangle {
            id: shelf

            readonly property string zoneKind: "shelf"
            readonly property bool aimed: ed.target !== null && ed.target.kind === "shelf"

            width: col.width
            height: shelfHead.height + (ed.line.leftOut.length > 0 ? shelfChips.height + 10 : 0) + 20
            radius: Math.min(BookStyle.b.radius ?? 4, 10)
            color: shelf.aimed ? Colors.withAlpha(BookStyle.accent, 0.1) : "transparent"
            border.width: shelf.aimed ? 1.5 : 0

            border.color: BookStyle.accent

            BookText {
                id: shelfHead
                x: 12
                y: 10
                text: ed.line.leftOut.length > 0 ? "Left out of every tab" : "Every panel has a tab. Drop one here to leave it out."
                font.family: BookStyle.ui
                font.pixelSize: 12
                font.italic: ed.line.leftOut.length === 0
                font.capitalization: ed.line.leftOut.length > 0 ? BookStyle.labelCaps : Font.MixedCase
                font.letterSpacing: ed.line.leftOut.length > 0 ? 1 : 0
                color: BookStyle.inkSoft
            }

            Flow {
                id: shelfChips
                visible: ed.line.leftOut.length > 0
                x: 12
                y: shelfHead.y + shelfHead.height + 8
                width: parent.width - 24
                spacing: 8

                Repeater {
                    model: ed.line.leftOut

                    EdgePanelChip {
                        required property string modelData
                        panelId: modelData
                        editor: ed
                    }
                }
            }

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                visible: !shelf.aimed
                color: BookStyle.line
            }
        }
    }

    // Where it would go in a tab.
    Rectangle {
        visible: ed.target !== null && ed.target.kind === "tab" && ed.caret.height > 0
        x: ed.caret.x
        y: ed.caret.y
        width: ed.caret.width
        height: ed.caret.height
        radius: 1
        color: BookStyle.accent
    }

    // The panel being carried, under the pointer.
    Rectangle {
        id: ghost

        readonly property var info: ed.line.panel(ed.carried)

        visible: ed.carried !== ""
        x: ed.carry.x - width / 2
        y: ed.carry.y - height / 2
        z: 10
        width: ghostRow.implicitWidth + 22
        height: 30
        radius: Math.min(BookStyle.b.radius ?? 4, 8)
        color: BookStyle.paper
        border.width: 1.5
        border.color: BookStyle.accent

        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: ghost.info?.icon ?? ""
                font.pixelSize: 16
                color: BookStyle.accent
            }

            BookText {
                anchors.verticalCenter: parent.verticalCenter
                text: ghost.info?.name ?? ""
                font.family: BookStyle.ui
                font.pixelSize: 13
                color: BookStyle.ink
            }
        }
    }
}
