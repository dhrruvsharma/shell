pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.desktopwidgets
import qs.modules.lock
import qs.services as Services

// The launcher: a great wheel rolled out of the left edge of the screen,
// the apps riding its rim. Turning it (↑↓, Page Up/Down, the scroll wheel,
// or dragging it round) brings an app to the pointer at three o'clock, where
// it swells and its name is set large beside it, with what it is, whether it
// runs in a terminal, and its actions. Typing filters the wheel to the apps
// that match (Services.AppRegistry.search), best first at the pointer.
//
// The wheel's face is the desktop theme's own object (DialFace and its
// faces): an astrolabe with its rule for the pointer, the Konark wheel, a
// rose window, an ensō, a war shield with a sword laid at the app, a tsuba
// and its blade, a luopan's red thread, a sonar's sweep, a tape reel, a
// rotary telephone's dial…
//
// Enter, or a click on the app at the pointer, launches; a click on another
// app turns the wheel to it; Tab steps through the app's actions; Esc
// clears the search, then closes. LauncherWindow builds this for each
// opening and drops it once it has rolled away again.
Item {
    id: root

    required property LauncherWindow launcher

    anchors.fill: parent

    // ── The apps on the wheel ────────────────────────────────────────────────

    property string query: ""
    readonly property var results: Services.AppRegistry.search(query)
    readonly property int count: results.length
    // With more apps than the rim shows at once, it runs on past the last
    // round to the first.
    readonly property bool wraps: count > 14
    // Where the wheel stands, in apps from the first: `position` as it
    // turns, `target` where it's turning to (whole when it's at rest).
    property real position: 0
    property real target: 0
    readonly property int current: count > 0 ? wrap(Math.round(target)) : -1
    readonly property var app: current >= 0 ? results[current] : null
    readonly property var actions: app ? app.actions.slice(0, 4) : []
    // The action Tab is on, -1 for the app itself.
    property int actionIndex: -1
    onCurrentChanged: actionIndex = -1

    function wrap(i) {
        return count > 0 ? ((i % count) + count) % count : 0;
    }

    // A new search starts the wheel at its best match; the apps changing
    // under the same search (one installed meanwhile) keep it on its app.
    property string _searched: ""
    property string _onId: ""
    onAppChanged: if (app) _onId = app.id
    onResultsChanged: {
        turning.stop();
        const kept = query === _searched ? results.findIndex(a => a.id === _onId) : -1;
        _searched = query;
        position = Math.max(0, kept);
        target = position;
        if (kept < 0)
            settle.restart();
    }

    // ── Its build ────────────────────────────────────────────────────────────

    readonly property real freeW: width - Services.BarLayout.reserveLeft - Services.BarLayout.reserveRight
    readonly property real freeH: height - Services.BarLayout.reserveTop - Services.BarLayout.reserveBottom
    // The face, and the ring the apps ride on just outside it.
    readonly property real radius: Math.round(Math.max(260, Math.min(freeH * 0.44, 560)))
    readonly property real track: radius + 54
    // Degrees from one app to the next.
    readonly property real step: 11
    // The hub sits a little past the screen's edge, so the face shows as a
    // great D; it rolls in from further out.
    readonly property real cx: Services.BarLayout.reserveLeft - radius * 0.24 - (1 - roll) * radius * 1.35
    readonly property real cy: Services.BarLayout.reserveTop + freeH / 2
    // 0 → 1 as the wheel rolls out (and back as it goes).
    property real roll: 0
    // The turn of the face in degrees: with the apps, plus the spin it rolls
    // in with.
    readonly property real spin: (1 - roll) * -150
    readonly property real turn: -position * step + spin
    // A new search's apps settle onto the rim (0 → 1).
    property real settled: 1
    // From the app at the pointer out to its name.
    readonly property real reach: 210
    // Where the name beside the pointer is set, for faces that dress it
    // (a swash of brush, a rule, flanking marks).
    readonly property real nameX: info.x + name.x
    readonly property real nameY: info.y + name.y
    readonly property real nameWidth: Math.min(name.width, name.contentWidth)
    readonly property real nameHeight: name.height
    readonly property real nameShown: shown
    // The whole of what's beside the pointer, for a face that sets it on
    // something (Broadsheet's clipping).
    readonly property real infoX: info.x
    readonly property real infoY: info.y
    readonly property real infoWidth: info.width
    readonly property real infoHeight: keys.y + keys.height

    // Where app `i` stands on the rim, in degrees clockwise from three
    // o'clock.
    function angleOf(i) {
        let d = i - position;
        if (wraps) {
            d = ((d % count) + count) % count;
            if (d > count / 2)
                d -= count;
        }
        return d * step + spin + (1 - settled) * 9;
    }

    // ── Look ─────────────────────────────────────────────────────────────────

    readonly property string themeId: ControlStyle.themeId
    readonly property var st: ControlStyle.st
    readonly property bool darkScheme: ControlStyle.darkScheme
    // Text over the darkened desktop: light whatever the scheme.
    readonly property color light: darkScheme ? Colors.on_surface : Colors.inverse_on_surface
    // Broadsheet sets what's beside the pointer on a clipping of newsprint,
    // in printer's ink with its accent printed dark.
    readonly property bool paper: themeId === "newspaper"
    readonly property color ink: paper ? "#1b1a17" : light
    readonly property color infoAccent: paper ? ControlStyle.accent : accent
    readonly property color accent: Services.DesktopTheme.accentOf(themeId)
    readonly property color accent2: Services.DesktopTheme.accent2Of(themeId)
    readonly property string bodyFont: ControlStyle.body
    readonly property string uiFont: ControlStyle.ui
    readonly property string monoFont: ControlStyle.mono
    // The app's name: in the theme's display face (its UI face where the
    // display one is for figures or too ornate to read at a glance).
    readonly property string nameFont: ["cyberpunk", "gothic"].includes(themeId) ? ControlStyle.ui : ControlStyle.display
    readonly property bool upper: ["hud", "cosmos", "cyberpunk", "artdeco", "wasteland", "abyss"].includes(themeId)
    readonly property real labelSpacing: Math.min(3, ControlStyle.labelSpacing)

    function label(text) {
        return ControlStyle.label(text);
    }

    // ── Turning ──────────────────────────────────────────────────────────────

    // Turns the wheel `steps` apps on (back, when negative).
    function turnBy(steps) {
        if (count === 0)
            return;
        let to = Math.round(target) + steps;
        if (!wraps)
            to = Math.max(0, Math.min(count - 1, to));
        turnTo(to);
    }

    // Turns to app `i` by the shorter way round.
    function turnToIndex(i) {
        let d = i - wrap(Math.round(target));
        if (wraps && Math.abs(d) > count / 2)
            d -= Math.sign(d) * count;
        turnTo(Math.round(target) + d);
    }

    function turnTo(to) {
        target = to;
        turning.from = position;
        turning.to = to;
        turning.restart();
    }

    NumberAnimation {
        id: turning
        target: root
        property: "position"
        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: settle
        target: root
        property: "settled"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    function launch(a, action) {
        if (!a)
            return;
        Services.AppRegistry.launch(a, action ?? null);
        launcher.close();
    }

    function activate() {
        launch(app, actionIndex >= 0 ? actions[actionIndex] : null);
    }

    function cycleAction(by) {
        const n = actions.length;
        if (n > 0)
            actionIndex = (actionIndex + 1 + by + n + 1) % (n + 1) - 1;
    }

    function key(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            if (query.length > 0)
                field.clear();
            else
                launcher.close();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate();
            break;
        case Qt.Key_Up:
            turnBy(-1);
            break;
        case Qt.Key_Down:
            turnBy(1);
            break;
        case Qt.Key_PageUp:
            turnBy(-6);
            break;
        case Qt.Key_PageDown:
            turnBy(6);
            break;
        case Qt.Key_Tab:
            cycleAction(1);
            break;
        case Qt.Key_Backtab:
            cycleAction(-1);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // ── Opening and closing ──────────────────────────────────────────────────

    // The name and the rest beside the pointer come in after the wheel.
    property real shown: 0

    // The panels' surface grows from a pixel to the screen as this opens,
    // and its first full-size frame comes 30-90 ms later; the wheel starts
    // rolling on that frame.
    property bool waiting: true

    Component.onCompleted: {
        field.forceActiveFocus();
        startAnyway.start();
    }

    function rollIn() {
        waiting = false;
        startAnyway.stop();
        rollOut.stop();
        rollIn_.restart();
    }

    Connections {
        target: root.Window.window
        enabled: root.waiting

        function onFrameSwapped() {
            if (root.Window.window.width >= root.width)
                root.rollIn();
        }
    }

    // in case that frame never comes
    Timer {
        id: startAnyway
        interval: 250
        onTriggered: root.rollIn()
    }

    Connections {
        target: root.launcher

        function onClosingChanged() {
            if (root.launcher.closing) {
                rollIn_.stop();
                rollOut.restart();
            } else {
                root.rollIn();
                field.forceActiveFocus();
            }
        }
    }

    ParallelAnimation {
        id: rollIn_
        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 0.62
            duration: 300
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "roll"
            to: 1
            duration: 620
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 220
            }
            NumberAnimation {
                target: root
                property: "shown"
                to: 1
                duration: 380
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: rollOut
        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 0
            duration: 260
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "roll"
            to: 0
            duration: 300
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "shown"
            to: 0
            duration: 160
            easing.type: Easing.InCubic
        }
        onFinished: root.launcher.closed()
    }

    // ── The scene ────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
    }

    // Pointer on the scene: turning the wheel by dragging or scrolling it,
    // choosing or launching an app on its rim, closing on a click away.
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: hoverIndex >= 0 ? Qt.PointingHandCursor : dragging ? Qt.ClosedHandCursor : overWheel ? Qt.OpenHandCursor : Qt.ArrowCursor

        readonly property real dx: mouseX - root.cx
        readonly property real dy: mouseY - root.cy
        readonly property real reach: Math.sqrt(dx * dx + dy * dy)
        readonly property bool overWheel: reach < root.track + 48
        // The app under the pointer, if it's over one on the rim.
        readonly property int hoverIndex: containsMouse && Math.abs(reach - root.track) < 40 ? root.indexAt(Math.atan2(dy, dx) * 180 / Math.PI) : -1

        property bool dragging: false
        property real pressY: 0
        property real pressAt: 0
        property real lastY: 0
        property real lastT: 0
        property real speed: 0
        property real spun: 0

        onPressed: mouse => {
            dragging = false;
            pressY = mouse.y;
            lastY = mouse.y;
            lastT = Date.now();
            speed = 0;
            pressAt = root.position;
        }
        onPositionChanged: mouse => {
            if (!pressed || !overWheel && !dragging)
                return;
            if (!dragging && Math.abs(mouse.y - pressY) < 6)
                return;
            if (!dragging) {
                dragging = true;
                turning.stop();
            }
            // A pixel along the rim is this much of an app.
            const perPx = 180 / (Math.PI * root.track * root.step);
            root.position = pressAt - (mouse.y - pressY) * perPx;
            root.target = root.position;
            const now = Date.now();
            if (now > lastT)
                speed = 0.7 * speed + 0.3 * (-(mouse.y - lastY) * perPx / (now - lastT));
            lastY = mouse.y;
            lastT = now;
        }
        onReleased: mouse => {
            if (!dragging)
                return;
            dragging = false;
            // Let it run on a little with the flick, then rest on an app.
            let to = Math.round(root.position + speed * 160);
            if (!root.wraps)
                to = Math.max(0, Math.min(root.count - 1, to));
            root.turnTo(to);
        }
        onClicked: mouse => {
            if (dragging)
                return;
            if (hoverIndex >= 0) {
                if (hoverIndex === root.current)
                    root.activate();
                else
                    root.turnToIndex(hoverIndex);
            } else if (!overWheel && !info.contains(mapToItem(info, mouse.x, mouse.y))) {
                root.launcher.close();
            }
        }
        onWheel: wheel => {
            if (wheel.pixelDelta.y !== 0 && wheel.angleDelta.y % 120 !== 0) {
                // A touchpad: glide with the fingers, rest when they lift.
                spun -= wheel.pixelDelta.y / (Math.PI * root.track * root.step / 180);
            } else {
                spun -= wheel.angleDelta.y / 120;
            }
            const whole = spun > 0 ? Math.floor(spun) : Math.ceil(spun);
            if (whole !== 0) {
                spun -= whole;
                root.turnBy(whole);
            }
        }
    }

    // The app whose place on the rim is nearest `angle` (degrees).
    function indexAt(angle) {
        if (count === 0)
            return -1;
        const d = (angle - spin) / step;
        const i = Math.round(position + d);
        if (!wraps && (i < 0 || i >= count))
            return -1;
        return Math.abs(angleOf(wrap(i)) - angle) < step / 2 + 0.5 ? wrap(i) : -1;
    }

    // The face, and its pointer.
    DialFace {
        anchors.fill: parent
        dial: root
    }

    // The apps.
    Repeater {
        model: root.results

        DialApp {
            dial: root
            hovered: pointer.hoverIndex === index
        }
    }

    // ── Beside the pointer ───────────────────────────────────────────────────

    Item {
        id: info

        // Far enough past the app at the pointer for the face's pointer to
        // reach across to the name, which sits on the pointer's line.
        readonly property real startX: Services.BarLayout.reserveLeft - root.radius * 0.24 + root.track + root.reach
        x: startX + (1 - root.shown) * 40
        y: Math.round(root.cy - name.y - name.height / 2)
        width: Math.min(820, root.width - Services.BarLayout.reserveRight - startX - 60)
        height: 300
        opacity: root.shown

        // The search, as a prompt over the rest.
        Item {
            id: prompt
            width: parent.width
            height: 34

            Text {
                id: caret
                anchors.verticalCenter: parent.verticalCenter
                text: root.themeId === "terminal" ? "$" : "›"
                font.family: root.monoFont
                font.pixelSize: 24
                font.weight: Font.Bold
                color: root.infoAccent
            }

            TextInput {
                id: field
                anchors.left: caret.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.family: root.bodyFont
                font.pixelSize: 22
                color: root.ink
                selectionColor: Colors.withAlpha(root.infoAccent, 0.45)
                selectedTextColor: root.ink
                selectByMouse: true
                clip: true
                onTextChanged: root.query = text
                Keys.onPressed: event => root.key(event)

                cursorDelegate: Rectangle {
                    width: 2
                    color: root.infoAccent
                    visible: field.cursorVisible
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text.length === 0
                    text: ControlStyle.word("launcherSearch")
                    font: field.font
                    color: Colors.withAlpha(root.ink, 0.4)
                }
            }
        }

        // What the wheel holds: the theme's name for the apps, and how many.
        Text {
            id: meta
            y: prompt.height + 26
            width: parent.width
            text: root.label(ControlStyle.word("launcher")) + "   ·   " + (root.count > 0 ? (root.current + 1) + " / " + root.count : "0")
            elide: Text.ElideRight
            font.family: root.uiFont
            font.pixelSize: 13
            font.letterSpacing: root.labelSpacing
            font.capitalization: ControlStyle.caps
            color: Colors.withAlpha(root.infoAccent, 0.9)
        }

        Text {
            id: name
            y: meta.y + meta.height + 4
            width: parent.width
            height: 76
            verticalAlignment: Text.AlignVCenter
            text: root.app ? (root.upper ? root.app.name.toUpperCase() : root.app.name) : ControlStyle.word("launcherEmpty")
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 26
            font.family: root.nameFont
            font.pixelSize: root.app ? 64 : 40
            font.letterSpacing: root.upper ? 4 : 0
            elide: Text.ElideRight
            color: root.app ? root.ink : Colors.withAlpha(root.ink, 0.6)

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: parent.width - parent.contentWidth
                enabled: root.app !== null
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate()
            }
        }

        Text {
            id: about
            y: name.y + name.height + 4
            width: parent.width
            text: root.app ? root.app.comment || root.app.genericName : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: root.bodyFont
            font.pixelSize: 17
            color: Colors.withAlpha(root.ink, 0.7)
        }

        // Runs in a terminal; its actions.
        Flow {
            id: extras
            y: about.y + about.height + 16
            width: parent.width
            spacing: 8

            Rectangle {
                visible: root.app !== null && root.app.terminal
                width: termRow.implicitWidth + 18
                height: 28
                radius: ControlStyle.radius(14)
                color: Colors.withAlpha(root.infoAccent, 0.16)
                border.width: 1
                border.color: Colors.withAlpha(root.infoAccent, 0.5)

                Row {
                    id: termRow
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "terminal"
                        font.pixelSize: 15
                        color: root.infoAccent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "in " + Services.AppRegistry.terminal.replace(/^.*\//, "")
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.ink
                    }
                }
            }

            Repeater {
                model: root.actions

                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.actionIndex === index
                    width: chipText.implicitWidth + 22
                    height: 28
                    radius: ControlStyle.radius(14)
                    color: chosen ? Colors.withAlpha(root.infoAccent, 0.3) : chipMouse.containsMouse ? Colors.withAlpha(root.ink, 0.14) : Colors.withAlpha(root.ink, 0.07)
                    border.width: 1
                    border.color: chosen ? root.infoAccent : Colors.withAlpha(root.ink, 0.18)

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.name
                        font.family: root.bodyFont
                        font.pixelSize: 13
                        color: chip.chosen ? root.ink : Colors.withAlpha(root.ink, 0.8)
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launch(root.app, chip.modelData)
                    }
                }
            }
        }

        // The keys.
        Text {
            id: keys
            y: extras.y + (extras.height > 0 ? extras.height + 22 : 6)
            width: parent.width
            text: root.label("↑ ↓  turn    ↵  open" + (root.actions.length > 0 ? "    ⇥  actions" : "") + "    esc  close")
            elide: Text.ElideRight
            font.family: root.uiFont
            font.pixelSize: 12
            font.letterSpacing: Math.min(2, root.labelSpacing)
            font.capitalization: ControlStyle.caps
            color: Colors.withAlpha(root.ink, 0.42)
        }
    }
}
