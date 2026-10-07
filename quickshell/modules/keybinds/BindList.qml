pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// Every bind, under the headings the config gives them (the comment above
// each group), in two columns. A loop's binds share one row. Hovering a row
// shows its key on the keyboard; a click selects it, a double click edits.
Item {
    id: list

    property var binds: []
    // a Set of matching bind ids while searching, else null
    property var matches: null
    property string selectedId: ""
    property var appIcon: null
    property var appName: null

    signal rowClicked(var bind)
    signal rowDoubleClicked(var bind)
    signal rowHovered(var bind)
    signal edit(var bind)
    signal remove(var bind)

    // Rows by section, in the order Hyprland runs them; a loop's binds are
    // one row.
    readonly property var sections: {
        const out = [];
        const index = {};
        const sites = {};
        for (const b of binds) {
            if (b.generated) {
                const site = b.file + ":" + b.line;
                if (sites[site]) {
                    sites[site].group.push(b);
                    continue;
                }
            }
            const key = b.file + "|" + b.section;
            if (index[key] === undefined) {
                index[key] = out.length;
                out.push({ key: key, title: b.section, file: b.file, rows: [] });
            }
            const row = { bind: b, group: [b] };
            out[index[key]].rows.push(row);
            if (b.generated)
                sites[b.file + ":" + b.line] = row;
        }
        return out;
    }

    function rowMatches(row) {
        return matches === null || row.group.some(b => matches.has(b.id));
    }

    // "Workspace 1" … "Workspace 10" → "Workspace 1–10"
    function groupTitle(row) {
        const first = titleOf(row.group[0]);
        if (row.group.length < 2)
            return first;
        const last = titleOf(row.group[row.group.length - 1]);
        let a = 0;
        while (a < first.length && first[a] === last[a])
            a++;
        // don't split a number ("Workspace 1" and "Workspace 10")
        while (a > 0 && /\d/.test(first[a - 1]))
            a--;
        let z = 0;
        while (z < first.length - a && z < last.length - a && first[first.length - 1 - z] === last[last.length - 1 - z])
            z++;
        while (z > 0 && /\d/.test(first[first.length - z]))
            z--;
        const x = first.slice(a, first.length - z);
        const y = last.slice(a, last.length - z);
        if (/^\d+$/.test(x) && /^\d+$/.test(y))
            return first.slice(0, a) + x + "–" + y + first.slice(first.length - z);
        return first + " …";
    }

    function titleOf(b) {
        if (b.category === "app" && !b.description && appName)
            return appName(b.app) || b.title;
        return b.title;
    }

    // what a row adds under its title: the command when it says more than
    // the app's name, or the Lua for anything custom
    function detailOf(b) {
        if (b.liveOnly)
            return "not in your files";
        if (b.category === "app" && typeof b.param === "string" && b.param.trim() !== b.app)
            return b.param;
        if (b.preset === "lua")
            return b.rawArgs?.dsp ?? "";
        return "";
    }

    // Deleting from a row asks twice.
    property string armed: ""

    Timer {
        id: disarm
        interval: 3200
        onTriggered: list.armed = ""
    }

    readonly property int columns: width > 760 ? 2 : 1

    readonly property var columnSections: {
        const cols = [];
        const heights = [];
        for (let c = 0; c < columns; c++) {
            cols.push([]);
            heights.push(0);
        }
        for (const s of sections) {
            const rows = s.rows.filter(r => rowMatches(r)).length;
            if (rows === 0)
                continue;
            let best = 0;
            for (let c = 1; c < columns; c++)
                if (heights[c] < heights[best])
                    best = c;
            cols[best].push(s);
            heights[best] += 44 + rows * 36;
        }
        return cols;
    }

    property var rowItems: ({})

    // Scroll a bind's row into view.
    function reveal(id) {
        const item = rowItems[id];
        if (!item)
            return;
        const y = item.mapToItem(flick.contentItem, 0, 0).y;
        if (y < flick.contentY + 8 || y + item.height > flick.contentY + flick.height - 8) {
            revealAnim.to = Math.max(0, Math.min(flick.contentHeight - flick.height, y - flick.height / 3));
            revealAnim.restart();
        }
    }

    NumberAnimation {
        id: revealAnim
        target: flick
        property: "contentY"
        duration: 240
        easing.type: Easing.OutCubic
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: columnsRow.implicitHeight + 4
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: StyledScrollBar {
            thickness: 5
            handleColor: Colors.outline_variant
            handleOpacity: 0.7
        }

        Row {
            id: columnsRow
            width: flick.width - 10
            spacing: 14

            Repeater {
                model: list.columns

                delegate: Column {
                    id: column
                    required property int index
                    width: (columnsRow.width - columnsRow.spacing * (list.columns - 1)) / list.columns
                    spacing: 14

                    Repeater {
                        model: list.columnSections[column.index] ?? []

                        delegate: Card {
                            id: section
                            required property var modelData
                            width: column.width
                            height: sectionColumn.implicitHeight + 16
                            radius: Services.DesktopTheme.rad(16)
                            color: Colors.surface_container_low

                            Column {
                                id: sectionColumn
                                x: 8
                                y: 8
                                width: parent.width - 16

                                Item {
                                    width: parent.width
                                    height: 30

                                    StyledText {
                                        id: sectionTitle
                                        x: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, parent.width - fileText.implicitWidth - 40)
                                        text: section.modelData.title.toUpperCase()
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.8
                                        color: Colors.on_surface_variant
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        id: fileText
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: section.modelData.file
                                        font.pixelSize: 10
                                        color: Colors.on_surface_variant
                                        opacity: 0.6
                                    }
                                }

                                Repeater {
                                    model: section.modelData.rows

                                    delegate: Rectangle {
                                        id: row
                                        required property var modelData
                                        readonly property var bind: modelData.bind
                                        readonly property bool shown: list.rowMatches(modelData)
                                        readonly property bool current: modelData.group.some(b => b.id === list.selectedId)
                                        readonly property bool armed: list.armed === bind.id

                                        width: sectionColumn.width
                                        height: shown ? 36 : 0
                                        visible: shown
                                        radius: Services.DesktopTheme.rad(10)
                                        color: current ? Colors.withAlpha(Services.DesktopTheme.accent, 0.14)
                                            : hover.hovered ? Colors.surface_container_high : "transparent"

                                        Component.onCompleted: list.rowItems[bind.id] = row
                                        Component.onDestruction: if (list.rowItems[bind.id] === row) delete list.rowItems[bind.id]

                                        HoverHandler {
                                            id: hover
                                            onHoveredChanged: list.rowHovered(hovered ? row.bind : null)
                                        }

                                        TapHandler {
                                            onTapped: list.rowClicked(row.bind)
                                            onDoubleTapped: if (row.bind.editable) list.rowDoubleClicked(row.bind)
                                        }

                                        Rectangle {
                                            visible: row.current
                                            x: 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3
                                            height: 18
                                            radius: 1.5
                                            color: Services.DesktopTheme.accent
                                        }

                                        BindIcon {
                                            id: rowIcon
                                            x: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            bind: row.bind
                                            source: row.bind.category === "app" && list.appIcon ? list.appIcon(row.bind.app) : ""
                                            size: 18
                                        }

                                        Row {
                                            anchors.left: rowIcon.right
                                            anchors.leftMargin: 10
                                            anchors.right: actions.visible ? actions.left : combo.left
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8
                                            clip: true

                                            StyledText {
                                                id: rowTitle
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.min(implicitWidth, parent.width)
                                                text: list.groupTitle(row.modelData)
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.max(0, parent.width - rowTitle.width - 8)
                                                text: row.bind.generated ? "a loop, " + row.modelData.group.length + " binds" : list.detailOf(row.bind)
                                                font.family: row.bind.generated ? Services.DesktopTheme.font || Qt.application.font.family : "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                color: Colors.on_surface_variant
                                                opacity: 0.75
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            id: actions
                                            visible: row.bind.editable && (hover.hovered || row.armed)
                                            anchors.right: combo.left
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2

                                            GlyphButton {
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                icon: "edit"
                                                iconSize: 15
                                                onClicked: list.edit(row.bind)
                                            }

                                            GlyphButton {
                                                implicitWidth: row.armed ? deleteText.implicitWidth + 40 : 28
                                                implicitHeight: 28
                                                icon: row.armed ? "" : "delete"
                                                iconSize: 15
                                                idleColor: row.armed ? Colors.error : "transparent"
                                                hoverColor: row.armed ? Colors.error : Colors.surface_container_highest
                                                onClicked: {
                                                    if (row.armed) {
                                                        list.armed = "";
                                                        list.remove(row.bind);
                                                    } else {
                                                        list.armed = row.bind.id;
                                                        disarm.restart();
                                                    }
                                                }

                                                StyledText {
                                                    id: deleteText
                                                    anchors.centerIn: parent
                                                    visible: row.armed
                                                    text: "Delete?"
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: Colors.on_error
                                                }
                                            }
                                        }

                                        KeyCombo {
                                            id: combo
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            mods: row.bind.mods
                                            key: row.bind.key
                                            keyText: row.modelData.group.length > 1
                                                ? KeyData.keyLabel(row.modelData.group[0].key) + " … " + KeyData.keyLabel(row.modelData.group[row.modelData.group.length - 1].key)
                                                : ""
                                            size: 10
                                            fill: Colors.surface_container_high
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    EmptyState {
        visible: list.binds.length > 0 && list.columnSections.every(c => c.length === 0)
        glyph: "⌕"
        title: "No binds match"
        subtitle: "Try a key, an app or a word from a command"
    }
}
