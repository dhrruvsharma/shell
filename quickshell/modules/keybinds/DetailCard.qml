pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// Beside the keyboard: what the key under the pointer (or the selected one)
// does, where it's written and what it's set to, with Edit and Delete; a
// free key offers to be bound; with no key in hand, the layer at a glance.
Card {
    id: card

    // the layer shown
    property var mods: []
    // the key in hand (a KeyData spec), or null for the layer summary
    property var spec: null
    property var binds: []
    property var appIcon: null
    property var appName: null

    signal edit(var bind)
    signal remove(var bind)
    signal bindHere(var mods, string key)

    readonly property var bind: binds.length ? binds[0] : null
    readonly property string keyName: spec ? spec.name : ""

    radius: Services.DesktopTheme.rad(20)
    color: Colors.surface_container_low
    clip: true

    // Deleting asks twice: the first click arms the button for a while.
    property string armed: ""

    Timer {
        id: disarm
        interval: 3200
        onTriggered: card.armed = ""
    }

    function askRemove(b) {
        if (armed === b.id) {
            armed = "";
            remove(b);
        } else {
            armed = b.id;
            disarm.restart();
        }
    }

    onSpecChanged: armed = ""

    function iconOf(b) {
        return b && b.category === "app" && appIcon ? appIcon(b.app) : "";
    }

    function titleOf(b) {
        if (!b)
            return "";
        if (b.category === "app" && !b.description && appName)
            return appName(b.app) || b.title;
        return b.title;
    }

    // What a bind runs, as written.
    function codeOf(b) {
        if (!b || b.liveOnly)
            return "";
        if ((b.preset === "exec" || b.preset === "ipc") && typeof b.param === "string")
            return b.param;
        return b.rawArgs?.dsp ?? "";
    }

    function flagsOf(b) {
        const on = [];
        for (const f of KeyData.flags)
            if (b?.opts?.[f.id])
                on.push(f.label);
        return on;
    }

    readonly property var layerStats: {
        const byLayer = Services.Keybinds.byLayer[KeyData.layerKey(mods)] ?? {};
        const all = [].concat(...Object.values(byLayer));
        const counts = {};
        for (const b of all)
            counts[b.category] = (counts[b.category] ?? 0) + 1;
        const plain = KeyData.keys.filter(k => !k.mod);
        const free = plain.filter(k => !(Services.Keybinds.norm(k.name) in byLayer)).length;
        return { count: all.length, free: free, categories: KeyData.categories.filter(c => counts[c.id]).map(c => ({ id: c.id, label: c.label, count: counts[c.id] })) };
    }

    // ── A bound key ──────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        visible: card.spec !== null && !card.spec.mod && card.binds.length > 0

        KeyCombo {
            mods: card.mods
            key: card.keyName
            size: 13
        }

        // two binds on one key: both fire
        RowLayout {
            Layout.fillWidth: true
            visible: card.binds.length > 1
            spacing: 6

            Glyph {
                text: "warning"
                filled: true
                font.pixelSize: 15
                color: Colors.error
            }

            StyledText {
                Layout.fillWidth: true
                text: card.binds.length + " binds on this key; they all go off"
                font.pixelSize: 12
                color: Colors.error
                wrapMode: Text.WordWrap
            }
        }

        // one bind, in full
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: card.binds.length === 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: Services.DesktopTheme.rad(12)
                    color: Colors.withAlpha(KeyData.toneOf(card.bind?.category), 0.16)

                    BindIcon {
                        anchors.centerIn: parent
                        bind: card.bind
                        source: card.iconOf(card.bind)
                        size: 24
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: card.titleOf(card.bind)
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: card.bind ? (card.bind.liveOnly ? "Not in your config files" : KeyData.categories.find(c => c.id === card.bind.category)?.label ?? "") : ""
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                        elide: Text.ElideRight
                    }
                }
            }

            // what it runs
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: codeText.implicitHeight + 16
                visible: card.codeOf(card.bind) !== ""
                radius: Services.DesktopTheme.rad(10)
                color: Colors.surface_container

                Text {
                    id: codeText
                    anchors.fill: parent
                    anchors.margins: 8
                    text: card.codeOf(card.bind)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: Colors.on_surface
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !!card.bind && !card.bind.liveOnly
                text: card.bind ? card.bind.file + ":" + card.bind.line + "  ·  " + card.bind.section : ""
                font.pixelSize: 11
                color: Colors.on_surface_variant
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: card.flagsOf(card.bind).length > 0

                Repeater {
                    model: card.flagsOf(card.bind)

                    delegate: Rectangle {
                        required property string modelData
                        width: flagText.implicitWidth + 16
                        height: 22
                        radius: Services.DesktopTheme.rad(11)
                        color: Colors.secondary_container

                        StyledText {
                            id: flagText
                            anchors.centerIn: parent
                            text: parent.modelData
                            font.pixelSize: 11
                            color: Colors.on_secondary_container
                        }
                    }
                }
            }

            Note {
                Layout.fillWidth: true
                visible: !!card.bind && card.bind.generated
                icon: "repeat"
                text: card.bind ? "One of " + card.bind.groupSize + " binds a loop makes at " + card.bind.file + ":" + card.bind.line + "; change them there." : ""
            }

            Note {
                Layout.fillWidth: true
                visible: !!card.bind && card.bind.liveOnly === true
                icon: "link"
                text: "Hyprland has this bind, but it isn't in hyprland.lua or the files it loads (another program set it)."
            }

            Note {
                Layout.fillWidth: true
                visible: !!card.bind && !card.bind.liveOnly && !card.bind.generated && !Services.Keybinds.isLive(card.bind)
                icon: "error"
                warn: true
                text: "Hyprland doesn't have this bind right now. A reload should load it."
            }
        }

        // several binds, one line each
        Repeater {
            model: card.binds.length > 1 ? card.binds.length : 0

            delegate: RowLayout {
                id: entry
                required property int index
                readonly property var b: card.binds[index] ?? null
                Layout.fillWidth: true
                spacing: 10

                BindIcon {
                    bind: entry.b
                    source: card.iconOf(entry.b)
                    size: 20
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: card.titleOf(entry.b)
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.b ? (entry.b.liveOnly ? "not in your files" : entry.b.file + ":" + entry.b.line) : ""
                        font.pixelSize: 11
                        color: Colors.on_surface_variant
                    }
                }

                GlyphButton {
                    visible: !!entry.b && entry.b.editable
                    icon: "edit"
                    iconSize: 16
                    onClicked: card.edit(entry.b)
                }

                GlyphButton {
                    visible: !!entry.b && entry.b.editable
                    icon: card.armed === entry.b?.id ? "delete_forever" : "delete"
                    iconSize: 16
                    iconColor: card.armed === entry.b?.id ? Colors.on_error : Colors.on_surface_variant
                    idleColor: card.armed === entry.b?.id ? Colors.error : "transparent"
                    hoverColor: card.armed === entry.b?.id ? Colors.error : Colors.surface_container_highest
                    onClicked: card.askRemove(entry.b)
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: card.binds.length === 1 && !!card.bind && card.bind.editable

            PanelButton {
                Layout.fillWidth: true
                icon: "edit"
                text: "Edit"
                primary: true
                onClicked: card.edit(card.bind)
            }

            PanelButton {
                Layout.fillWidth: true
                icon: card.armed === card.bind?.id ? "delete_forever" : "delete"
                text: card.armed === card.bind?.id ? "Sure?" : "Delete"
                danger: card.armed === card.bind?.id
                onClicked: card.askRemove(card.bind)
            }
        }
    }

    // ── A free key ───────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        visible: card.spec !== null && !card.spec.mod && card.binds.length === 0

        KeyCombo {
            mods: card.mods
            key: card.keyName
            size: 13
        }

        StyledText {
            Layout.topMargin: 6
            text: "Free"
            font.pixelSize: 26
            font.weight: Font.Bold
            color: Colors.on_surface_variant
            opacity: 0.7
        }

        StyledText {
            Layout.fillWidth: true
            text: "Nothing goes off on " + KeyData.comboText(card.mods.map(m => KeyData.modLabel(m)), KeyData.keyLabel(card.keyName)) + " yet."
            font.pixelSize: 13
            color: Colors.on_surface_variant
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillHeight: true
        }

        PanelButton {
            Layout.fillWidth: true
            icon: "add"
            text: "Bind this key"
            primary: true
            onClicked: card.bindHere(card.mods, card.keyName)
        }
    }

    // ── A modifier key ───────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10
        visible: card.spec !== null && !!card.spec.mod

        StyledText {
            text: KeyData.modLabel(card.spec?.mod ?? "")
            font.pixelSize: 22
            font.weight: Font.Bold
        }

        StyledText {
            Layout.fillWidth: true
            text: card.mods.includes(card.spec?.mod ?? "")
                ? "Part of the layer shown. Click it to take it out."
                : "Click it to show the binds that need " + KeyData.modLabel(card.spec?.mod ?? "") + " held as well."
            font.pixelSize: 13
            color: Colors.on_surface_variant
            wrapMode: Text.WordWrap
        }
    }

    // ── The layer at a glance ────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12
        visible: card.spec === null

        StyledText {
            Layout.fillWidth: true
            text: card.mods.length ? KeyData.layerName(card.mods) : "No modifier"
            font.pixelSize: 19
            font.weight: Font.Bold
            elide: Text.ElideRight
        }

        StyledText {
            Layout.topMargin: -8
            text: card.layerStats.count === 1 ? "1 bind" : card.layerStats.count + " binds, " + card.layerStats.free + " keys free"
            font.pixelSize: 13
            color: Colors.on_surface_variant
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: card.layerStats.categories

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    width: chipRow.implicitWidth + 18
                    height: 26
                    radius: Services.DesktopTheme.rad(13)
                    color: Colors.withAlpha(KeyData.toneOf(chip.modelData.id), 0.14)

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: KeyData.toneOf(chip.modelData.id)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.label + "  " + chip.modelData.count
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        Repeater {
            model: [
                ["ads_click", "Click a free key to bind it"],
                ["keyboard_command_key", "Hold Super, Alt, Ctrl or Shift to peek at their layer"],
                ["edit", "Double-click a bind to edit it"],
                ["search", "/ searches, N makes a new bind"]
            ]

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10

                Glyph {
                    text: parent.modelData[0]
                    font.pixelSize: 16
                    color: Colors.on_surface_variant
                    opacity: 0.8
                }

                StyledText {
                    Layout.fillWidth: true
                    text: parent.modelData[1]
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component Note: RowLayout {
        id: note
        property string icon: "info"
        property string text: ""
        property bool warn: false
        spacing: 8

        Glyph {
            Layout.alignment: Qt.AlignTop
            text: note.icon
            font.pixelSize: 15
            color: note.warn ? Colors.error : Colors.on_surface_variant
        }

        StyledText {
            Layout.fillWidth: true
            text: note.text
            font.pixelSize: 12
            color: note.warn ? Colors.error : Colors.on_surface_variant
            wrapMode: Text.WordWrap
        }
    }
}
