pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// What the pet's hub shows (PetHub puts it in a window under the pet): the
// pet and how it's doing, one search over everything it can do, and below
// it the tricks you've taught it (pinned commands), what you ran lately,
// reminders, and its care. Also its settings, and a form to teach it a new
// trick. Themed like every panel (PanelDecor, rad(), the theme's type).
//
// Keys: type to search, ↑↓ choose, Enter run, Shift+Enter run in a
// terminal, Ctrl+Enter pin the choice as a trick, Esc back / close.
Item {
    id: card

    readonly property var pet: Services.Pet
    property string view: "home"   // home | settings | teach
    property string query: ""
    property var results: []
    property int selected: 0
    property bool editing: false
    property string saying: ""

    signal closeRequested

    implicitWidth: 640
    implicitHeight: column.implicitHeight + 44

    function focusSearch() {
        search.forceActiveFocus();
    }

    // Each view's keyboard home: the search, the new trick's name, or the
    // card itself (for Esc).
    function focusView() {
        if (card.view === "home")
            search.forceActiveFocus();
        else if (card.view === "teach")
            trickName.forceActiveFocus();
        else
            card.forceActiveFocus();
    }

    onViewChanged: Qt.callLater(card.focusView)
    Keys.onEscapePressed: card.back()

    function runAction(a, terminal) {
        if (!a || a.type === "none")
            return;
        card.pet.run(a, terminal);
        if (a.type !== "pet" && a.type !== "calc")
            card.closeRequested();
        else
            search.text = "";
    }

    function back() {
        if (card.view !== "home") {
            card.view = "home";
            Qt.callLater(card.focusSearch);
        } else if (search.text.length > 0) {
            search.text = "";
        } else {
            card.closeRequested();
        }
    }

    Connections {
        target: card.pet

        function onBubbleSerialChanged() {
            card.saying = card.pet.bubbleText;
            sayingTimer.interval = card.pet.bubbleMs;
            sayingTimer.restart();
        }
    }

    Timer {
        id: sayingTimer
        onTriggered: card.saying = ""
    }

    onQueryChanged: {
        card.results = card.pet.search(card.query, 8);
        card.selected = 0;
    }

    // ── Surface ──────────────────────────────────────────────────────────────
    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Services.DesktopTheme.panelRadius(26)
        color: Colors.surface_container_lowest
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Colors.withAlpha(Services.DesktopTheme.accent, 0.08) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }
    }

    PanelDecor {
        radius: surface.radius
        title: card.pet.name.toLowerCase()
        seal: "猫"
    }

    component Heading: StyledText {
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Colors.on_surface_variant
    }

    component Chip: ClickableRect {
        id: chip
        property string icon: ""
        property string text: ""
        property bool on: false
        width: chipRow.implicitWidth + 24
        height: 34
        radius: Services.DesktopTheme.rad(17)
        color: chip.on ? Colors.secondary_container : chip.hovered ? Colors.surface_container_high : Colors.surface_container
        border.width: chip.on ? 0 : 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
        cursorShape: Qt.PointingHandCursor

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon.length > 0
                text: chip.icon
                font.pixelSize: 17
                color: chip.on ? Colors.on_secondary_container : Services.DesktopTheme.accent
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font.pixelSize: 13
                font.weight: Font.Medium
                color: chip.on ? Colors.on_secondary_container : Colors.on_surface
            }
        }
    }

    component ActionIcon: Item {
        id: icon
        property string glyph: "bolt"
        property string image: ""
        property real size: 24
        property color color: Services.DesktopTheme.accent
        width: size
        height: size

        Image {
            id: img
            anchors.fill: parent
            visible: icon.image.length > 0 && status === Image.Ready
            source: icon.image
            sourceSize: Qt.size(icon.size * 2, icon.size * 2)
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        Glyph {
            anchors.centerIn: parent
            visible: !img.visible
            text: icon.glyph
            font.pixelSize: icon.size
            color: icon.color
        }
    }

    Column {
        id: column
        x: 22
        y: 22
        width: parent.width - 44
        spacing: 14

        // ── The pet, and how it's doing ──────────────────────────────────────
        Item {
            width: parent.width
            height: 112

            Rectangle {
                id: stage
                width: 112
                height: 112
                radius: Services.DesktopTheme.rad(24)
                color: Colors.surface_container
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
                clip: true

                PetPortrait {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    width: 104
                    height: 91
                }
            }

            Column {
                x: stage.width + 18
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 90
                spacing: 5

                StyledText {
                    text: card.pet.name
                    font.pixelSize: 26
                    font.weight: Font.Bold
                }

                StyledText {
                    text: card.pet.moodWords[card.pet.mood] + "  ·  " + card.pet.bond + ", level " + card.pet.level
                    font.pixelSize: 13
                    color: Services.DesktopTheme.accent
                }

                // Friendship towards the next level.
                Rectangle {
                    width: Math.min(parent.width, 260)
                    height: 6
                    radius: Services.DesktopTheme.rad(3)
                    color: Colors.withAlpha(Colors.on_surface, 0.12)

                    Rectangle {
                        width: parent.width * card.pet.levelProgress
                        height: parent.height
                        radius: parent.radius
                        color: Services.DesktopTheme.accent
                    }
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: card.saying ? "“" + card.saying + "”" : card.pet.greeting()
                    font.pixelSize: 13
                    font.italic: true
                    color: card.saying ? Colors.on_surface : Colors.on_surface_variant
                }
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 4

                Repeater {
                    model: [
                        { icon: "tune", act: "settings" },
                        { icon: "close", act: "close" }
                    ]

                    ClickableRect {
                        id: headBtn
                        required property var modelData
                        width: 36
                        height: 36
                        radius: Services.DesktopTheme.rad(18)
                        color: (headBtn.modelData.act === "settings" && card.view === "settings") ? Colors.secondary_container
                            : headBtn.hovered ? Colors.surface_container_high : "transparent"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (headBtn.modelData.act === "close")
                                card.closeRequested();
                            else
                                card.view = card.view === "settings" ? "home" : "settings";
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: headBtn.modelData.icon
                            font.pixelSize: 20
                            color: Colors.on_surface_variant
                        }
                    }
                }
            }
        }

        // ── Search ───────────────────────────────────────────────────────────
        StyledTextField {
            id: search
            visible: card.view === "home"
            width: parent.width
            height: 48
            leftPadding: 44
            radius: Services.DesktopTheme.rad(16)
            font.pixelSize: 15
            font.family: Services.DesktopTheme.font || Qt.application.font.family
            backgroundColor: Colors.surface_container
            focusBorderColor: Services.DesktopTheme.accent
            placeholderText: "Ask " + card.pet.name + ": an app, an action, >command, =sum, ?search, remind in 10m…"
            onTextChanged: card.query = text

            Glyph {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                font.pixelSize: 20
                color: Colors.on_surface_variant
            }

            Keys.onPressed: event => {
                const n = card.results.length;
                if (event.key === Qt.Key_Down && n > 0) {
                    card.selected = (card.selected + 1) % n;
                } else if (event.key === Qt.Key_Up && n > 0) {
                    card.selected = (card.selected + n - 1) % n;
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && n > 0) {
                    const a = card.results[card.selected];
                    if (event.modifiers & Qt.ControlModifier) {
                        card.pet.pin(a);
                        search.text = "";
                    } else {
                        card.runAction(a, !!(event.modifiers & Qt.ShiftModifier));
                    }
                } else if (event.key === Qt.Key_Escape) {
                    card.back();
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        // ── Results ──────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 4
            visible: card.view === "home" && card.query.trim().length > 0

            Repeater {
                model: card.results

                ClickableRect {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: card.selected === index
                    readonly property bool pinnable: (modelData.type === "cmd" || modelData.type === "app") && !String(modelData.key).startsWith("trick:") && modelData.key !== "run"
                    width: parent.width
                    height: 50
                    radius: Services.DesktopTheme.rad(14)
                    color: row.current ? Colors.withAlpha(Services.DesktopTheme.accent, 0.16) : row.hovered ? Colors.surface_container : "transparent"
                    border.width: row.current ? 1 : 0
                    border.color: Colors.withAlpha(Services.DesktopTheme.accent, 0.45)
                    cursorShape: Qt.PointingHandCursor
                    onEntered: card.selected = row.index
                    onClicked: card.runAction(row.modelData, false)

                    ActionIcon {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: row.modelData.icon || "bolt"
                        image: row.modelData.image || ""
                        size: 26
                    }

                    Column {
                        x: 54
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - (row.pinnable ? 52 : 16)

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.title
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.modelData.subtitle
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                        }
                    }

                    ClickableRect {
                        id: pinBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.pinnable && (row.hovered || pinBtn.hovered || row.current)
                        width: 32
                        height: 32
                        radius: Services.DesktopTheme.rad(16)
                        color: pinBtn.hovered ? Colors.surface_container_high : "transparent"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            card.pet.pin(row.modelData);
                            search.text = "";
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: "push_pin"
                            font.pixelSize: 18
                            color: Colors.on_surface_variant
                        }
                    }
                }
            }
        }

        // ── Home: tricks, recent, reminders, care ────────────────────────────
        Column {
            width: parent.width
            spacing: 14
            visible: card.view === "home" && card.query.trim().length === 0

            Item {
                width: parent.width
                height: 26

                Heading {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tricks"
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Chip {
                        height: 26
                        icon: card.editing ? "check" : "edit"
                        text: card.editing ? "Done" : "Edit"
                        on: card.editing
                        onClicked: card.editing = !card.editing
                    }

                    Chip {
                        height: 26
                        icon: "add"
                        text: "Teach a trick"
                        onClicked: {
                            card.editing = false;
                            card.view = "teach";
                        }
                    }
                }
            }

            Grid {
                id: trickGrid
                width: parent.width
                columns: 5
                spacing: 8

                readonly property real tileW: (width - spacing * (columns - 1)) / columns

                Repeater {
                    model: card.pet.trickActions

                    ClickableRect {
                        id: tile
                        required property var modelData
                        required property int index
                        width: trickGrid.tileW
                        height: 80
                        radius: Services.DesktopTheme.rad(18)
                        color: tile.hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!card.editing)
                                card.runAction(tile.modelData, false);
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            ActionIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                glyph: tile.modelData.icon || "bolt"
                                image: tile.modelData.image || ""
                                size: 28
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: !card.editing
                                width: Math.min(implicitWidth, tile.width - 12)
                                elide: Text.ElideRight
                                text: tile.modelData.title
                                font.pixelSize: 13
                            }

                            // Editing: move it along, or forget it.
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: card.editing
                                spacing: 4

                                Repeater {
                                    model: [
                                        { icon: "chevron_left", act: -1 },
                                        { icon: "close", act: 0 },
                                        { icon: "chevron_right", act: 1 }
                                    ]

                                    ClickableRect {
                                        id: editBtn
                                        required property var modelData
                                        width: 24
                                        height: 24
                                        radius: Services.DesktopTheme.rad(12)
                                        color: editBtn.hovered ? (editBtn.modelData.act === 0 ? Colors.error : Colors.surface_container_highest) : Colors.withAlpha(Colors.surface_container_highest, 0.8)
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (editBtn.modelData.act === 0)
                                                card.pet.forget(tile.modelData.trickId);
                                            else
                                                card.pet.moveTrick(tile.modelData.trickId, editBtn.modelData.act);
                                        }

                                        Glyph {
                                            anchors.centerIn: parent
                                            text: editBtn.modelData.icon
                                            font.pixelSize: 16
                                            color: editBtn.hovered && editBtn.modelData.act === 0 ? Colors.on_error : Colors.on_surface
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Lately.
            Heading {
                visible: card.pet.recent.length > 0
                text: "Lately"
            }

            Flow {
                width: parent.width
                spacing: 6
                visible: card.pet.recent.length > 0

                Repeater {
                    model: card.pet.recent

                    Chip {
                        required property var modelData
                        icon: modelData.icon || "history"
                        text: modelData.title.length > 34 ? modelData.title.slice(0, 33) + "…" : modelData.title
                        onClicked: card.runAction(modelData, false)
                    }
                }
            }

            // Reminders.
            Heading {
                visible: card.pet.reminders.length > 0
                text: "Reminders"
            }

            Repeater {
                model: card.pet.reminders

                Item {
                    id: rem
                    required property var modelData
                    width: column.width
                    height: 32

                    Glyph {
                        id: remIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: "alarm"
                        font.pixelSize: 18
                        color: Services.DesktopTheme.accent
                    }

                    StyledText {
                        anchors.left: remIcon.right
                        anchors.leftMargin: 10
                        anchors.right: remCancel.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: Qt.formatTime(new Date(rem.modelData.at), "h:mm AP") + "  ·  " + rem.modelData.text
                        font.pixelSize: 14
                    }

                    ClickableRect {
                        id: remCancel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: Services.DesktopTheme.rad(14)
                        color: remCancel.hovered ? Colors.surface_container_high : "transparent"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pet.cancelReminder(rem.modelData.id)

                        Glyph {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 16
                            color: Colors.on_surface_variant
                        }
                    }
                }
            }

            // Care.
            Heading {
                text: "Care"
            }

            Flow {
                width: parent.width
                spacing: 8

                Chip {
                    icon: "pets"
                    text: "Pat"
                    onClicked: card.pet.pat()
                }

                Chip {
                    icon: "set_meal"
                    text: "Feed"
                    onClicked: card.pet.feed()
                }

                Chip {
                    icon: "sports_baseball"
                    text: "Play"
                    onClicked: card.pet.play()
                }

                Chip {
                    icon: "bedtime"
                    text: "Nap"
                    onClicked: card.pet.nap()
                }

                Chip {
                    icon: "alarm_add"
                    text: "Remind me…"
                    onClicked: {
                        search.text = "remind in 10m ";
                        card.focusSearch();
                    }
                }
            }
        }

        // ── Settings ─────────────────────────────────────────────────────────
        Column {
            width: parent.width
            spacing: 14
            visible: card.view === "settings"

            Heading {
                text: "Name"
            }

            StyledTextField {
                id: nameField
                width: Math.min(parent.width, 320)
                height: 40
                radius: Services.DesktopTheme.rad(12)
                font.pixelSize: 15
                font.family: Services.DesktopTheme.font || Qt.application.font.family
                leftPadding: 14
                backgroundColor: Colors.surface_container
                focusBorderColor: Services.DesktopTheme.accent
                text: card.pet.name
                onEditingFinished: card.pet.setName(text)
                Keys.onEscapePressed: card.back()
            }

            Heading {
                text: "Kind"
            }

            Row {
                spacing: 10

                Repeater {
                    model: [
                        { id: "cat", label: "Cat" },
                        { id: "fox", label: "Fox" },
                        { id: "bunny", label: "Bunny" }
                    ]

                    ClickableRect {
                        id: kind
                        required property var modelData
                        readonly property bool on: card.pet.species === kind.modelData.id
                        width: 110
                        height: 104
                        radius: Services.DesktopTheme.rad(18)
                        color: kind.on ? Colors.withAlpha(Services.DesktopTheme.accent, 0.16) : kind.hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: kind.on ? 2 : 1
                        border.color: kind.on ? Services.DesktopTheme.accent : Colors.withAlpha(Colors.outline_variant, 0.6)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pet.setSpecies(kind.modelData.id)

                        PetFigure {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: 80
                            height: 70
                            pose: "sit"
                            species: kind.modelData.id
                            coat: card.pet.fur === "natural" ? card.pet.furs[kind.modelData.id === "fox" ? "fox" : kind.modelData.id === "bunny" ? "white" : "cream"] : card.pet.coat
                            costume: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
                            accent: Services.DesktopTheme.accent
                            accent2: Services.DesktopTheme.accent2
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: kind.modelData.label
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Heading {
                text: "Fur"
            }

            Flow {
                width: parent.width
                spacing: 8

                Repeater {
                    model: card.pet.furNames

                    ClickableRect {
                        id: swatch
                        required property string modelData
                        readonly property bool on: card.pet.fur === swatch.modelData
                        readonly property color tone: swatch.modelData === "theme" ? Qt.hsla(Math.max(0, Qt.color(Services.DesktopTheme.accent).hslHue), 0.5, 0.8, 1)
                            : swatch.modelData === "natural" ? (card.pet.species === "fox" ? card.pet.furs.fox.base : card.pet.species === "bunny" ? card.pet.furs.white.base : card.pet.furs.cream.base)
                            : card.pet.furs[swatch.modelData].base
                        width: swatchRow.implicitWidth + 22
                        height: 34
                        radius: Services.DesktopTheme.rad(17)
                        color: swatch.on ? Colors.secondary_container : swatch.hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: swatch.on ? 0 : 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.pet.setFur(swatch.modelData)

                        Row {
                            id: swatchRow
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: swatch.tone
                                border.width: 1
                                border.color: Colors.withAlpha(Colors.on_surface, 0.35)
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: swatch.modelData === "theme" ? "Theme colour" : swatch.modelData.charAt(0).toUpperCase() + swatch.modelData.slice(1)
                                font.pixelSize: 13
                                color: swatch.on ? Colors.on_secondary_container : Colors.on_surface
                            }
                        }
                    }
                }
            }

            Heading {
                text: "Chattiness"
            }

            Row {
                spacing: 8

                Repeater {
                    model: [
                        { v: 0, label: "Quiet", icon: "volume_off" },
                        { v: 1, label: "Normal", icon: "chat_bubble" },
                        { v: 2, label: "Chatty", icon: "forum" }
                    ]

                    Chip {
                        required property var modelData
                        icon: modelData.icon
                        text: modelData.label
                        on: card.pet.chatty === modelData.v
                        onClicked: card.pet.setChatty(modelData.v)
                    }
                }
            }

            Heading {
                text: "Wanders"
            }

            Row {
                spacing: 8

                Repeater {
                    model: [
                        { v: "bar", label: "The whole bar", icon: "swap_horiz" },
                        { v: "left", label: "Left side", icon: "west" },
                        { v: "right", label: "Right side", icon: "east" },
                        { v: "still", label: "Stays put", icon: "do_not_step" }
                    ]

                    Chip {
                        required property var modelData
                        icon: modelData.icon
                        text: modelData.label
                        on: card.pet.roam === modelData.v
                        onClicked: card.pet.setRoam(modelData.v)
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8

                Chip {
                    icon: card.pet.sleepAtNight ? "check_box" : "check_box_outline_blank"
                    text: "Sleeps at night"
                    on: card.pet.sleepAtNight
                    onClicked: card.pet.setSleepAtNight(!card.pet.sleepAtNight)
                }

                Chip {
                    icon: card.pet.shown ? "check_box" : "check_box_outline_blank"
                    text: "Lives in the bar"
                    on: card.pet.shown
                    onClicked: card.pet.setShown(!card.pet.shown)
                }

                Chip {
                    icon: "restart_alt"
                    text: "Reset tricks"
                    onClicked: card.pet.resetTricks()
                }
            }
        }

        // ── Teach a trick ────────────────────────────────────────────────────
        Column {
            id: teach
            width: parent.width
            spacing: 12
            visible: card.view === "teach"

            property string icon: "bolt"
            property bool terminal: false

            function save() {
                card.pet.teach(trickName.text, trickCmd.text, teach.icon, teach.terminal);
                trickName.text = "";
                trickCmd.text = "";
                teach.icon = "bolt";
                teach.terminal = false;
                card.view = "home";
                Qt.callLater(card.focusSearch);
            }

            Heading {
                text: "Teach " + card.pet.name + " a trick"
            }

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 48
                    height: 48
                    radius: Services.DesktopTheme.rad(14)
                    color: Colors.surface_container

                    Glyph {
                        anchors.centerIn: parent
                        text: teach.icon || "bolt"
                        font.pixelSize: 26
                        color: Services.DesktopTheme.accent
                    }
                }

                StyledTextField {
                    id: trickName
                    width: parent.width - 58
                    height: 48
                    radius: Services.DesktopTheme.rad(14)
                    font.pixelSize: 15
                    font.family: Services.DesktopTheme.font || Qt.application.font.family
                    leftPadding: 14
                    backgroundColor: Colors.surface_container
                    focusBorderColor: Services.DesktopTheme.accent
                    placeholderText: "What it's called (e.g. Update system)"
                    Keys.onEscapePressed: card.back()
                    Keys.onReturnPressed: trickCmd.forceActiveFocus()
                }
            }

            StyledTextField {
                id: trickCmd
                width: parent.width
                height: 48
                radius: Services.DesktopTheme.rad(14)
                font.pixelSize: 14
                font.family: "JetBrainsMono Nerd Font"
                leftPadding: 14
                backgroundColor: Colors.surface_container
                focusBorderColor: Services.DesktopTheme.accent
                placeholderText: "The command (e.g. yay -Syu)"
                Keys.onEscapePressed: card.back()
                Keys.onReturnPressed: teach.save()
            }

            Heading {
                text: "Icon"
            }

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["bolt", "terminal", "folder", "language", "code", "music_note", "sports_esports", "rocket_launch", "build", "cloud", "star", "favorite", "school", "work", "movie", "photo_camera", "download", "sync", "bug_report", "coffee"]

                    ClickableRect {
                        id: iconPick
                        required property string modelData
                        width: 38
                        height: 38
                        radius: Services.DesktopTheme.rad(12)
                        color: teach.icon === iconPick.modelData ? Colors.secondary_container : iconPick.hovered ? Colors.surface_container_high : Colors.surface_container
                        cursorShape: Qt.PointingHandCursor
                        onClicked: teach.icon = iconPick.modelData

                        Glyph {
                            anchors.centerIn: parent
                            text: iconPick.modelData
                            font.pixelSize: 20
                            color: teach.icon === iconPick.modelData ? Colors.on_secondary_container : Colors.on_surface
                        }
                    }
                }
            }

            Row {
                spacing: 8

                Chip {
                    icon: teach.terminal ? "check_box" : "check_box_outline_blank"
                    text: "Run it in a terminal"
                    on: teach.terminal
                    onClicked: teach.terminal = !teach.terminal
                }

                Chip {
                    icon: "school"
                    text: "Teach it"
                    onClicked: teach.save()
                }

                Chip {
                    icon: "arrow_back"
                    text: "Never mind"
                    onClicked: card.back()
                }
            }
        }

        // ── Hints ────────────────────────────────────────────────────────────
        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: card.view === "settings" ? "Everything saves as you go · Esc back"
                : card.view === "teach" ? "Enter teaches it · Esc back"
                : card.query.trim().length > 0 ? "↑↓ choose · Enter run · Shift+Enter in a terminal · Ctrl+Enter pin as a trick · Esc clear"
                : "Type to search apps and actions · >cmd runs it · =2+2 · ?web search · remind in 10m tea · right-click " + card.pet.name + " to pat"
            font.pixelSize: 12
            color: Colors.on_surface_variant
        }
    }
}
