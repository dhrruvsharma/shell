pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.desktopwidgets

// The control centre: a full-height panel on the left, made like the desktop
// theme's widgets (ControlStyle): the theme's frame for its surface (scrap
// plate, war banner, lancet window, newsprint…), its type, wording and
// meters. From the top: the time and the day as the theme keeps it, the
// switches, the levels, what's playing, the notifications (they take what
// height is left), the machine, and the power actions.
//
// Opens from the left edge, clear of the bar wherever it stands:
// `qs ipc call controlCenter changeVisible`, ALT+SHIFT+C, or the bar's
// memory pill. shell.qml builds it for each opening and drops it once it
// has closed. Esc closes it.
Item {
    id: root

    anchors.fill: parent
    visible: false

    property bool opened: false

    // Another panel to open as this one goes: "wifi", "bluetooth",
    // "themes" or "avatar".
    signal panelRequested(string which)

    readonly property real gap: 10
    readonly property real panelWidth: 468
    readonly property real openX: Services.BarLayout.reserveLeft + gap
    readonly property real closedX: -panelWidth - 24

    function close() {
        opened = false;
    }

    function openPanel(which) {
        close();
        panelRequested(which);
    }

    // Closes, then runs `command` once the panel is out of the way (the
    // lock screen starts from a capture of the screen).
    function closeThen(command) {
        close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + command]);
    }

    readonly property string lockCommand: "exec quickshell -p \"$HOME/.config/quickshell/Lock.qml\""

    function lock() {
        closeThen(lockCommand);
    }

    // Locks first: Lock.qml suspends once every screen is covered.
    function suspend() {
        closeThen("QS_LOCK_THEN=suspend " + lockCommand);
    }

    function logOut() {
        closeThen("loginctl terminate-user \"$USER\"");
    }

    function reboot() {
        closeThen("systemctl reboot");
    }

    function powerOff() {
        closeThen("systemctl poweroff");
    }

    // The sections rise into place one after another as it opens (0..1).
    property real intro: 1

    // How far section `i` has risen at the moment, eased.
    function reveal(i) {
        const x = Math.max(0, Math.min(1, (intro - i * 0.075) / 0.42));
        return 1 - Math.pow(1 - x, 3);
    }

    // The panels' surface grows from a pixel to the screen as this opens,
    // and its first full-size frame comes 30-90 ms later; a slide started
    // at once would jump most of the way in. It starts on that frame.
    property bool waiting: false

    onOpenedChanged: {
        if (opened) {
            visible = true;
            closeAnim.stop();
            panel.x = closedX;
            scrim.opacity = 0;
            intro = 0;
            Services.Osd.quiet = true;
            waiting = true;
            startAnyway.restart();
        } else {
            waiting = false;
            startAnyway.stop();
            Services.Osd.quiet = false;
            openAnim.stop();
            closeAnim.restart();
        }
    }

    // The OSD isn't left held back if this goes while open (a reload).
    Component.onDestruction: Services.Osd.quiet = false

    function slideIn() {
        waiting = false;
        startAnyway.stop();
        openAnim.restart();
    }

    Connections {
        target: root.Window.window
        enabled: root.waiting

        function onFrameSwapped() {
            if (root.Window.window.width >= root.width)
                root.slideIn();
        }
    }

    // in case that frame never comes
    Timer {
        id: startAnyway
        interval: 250
        onTriggered: root.slideIn()
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
        enabled: opacity > 0.01

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Item {
        id: panel

        x: root.closedX
        y: Services.BarLayout.reserveTop + root.gap
        width: root.panelWidth
        height: root.height - Services.BarLayout.reserveTop - Services.BarLayout.reserveBottom - 2 * root.gap

        readonly property bool bare: ControlStyle.frame === "bare"
        // Room the frame keeps for itself: its padding, Cathedral's arch,
        // Mainframe's title tab, Siege's crossbar and swallowtail.
        readonly property real pad: bare ? 22 : ControlStyle.st.pad
        readonly property real headRoom: bare ? 0 : surface.tabRoom + surface.headRoom
        readonly property real footRoom: bare ? 0 : surface.footRoom

        // Clicks on the panel stay on it.
        MouseArea {
            anchors.fill: parent
        }

        // Astral's glass is thin for a panel this full: a tint behind it
        // keeps the wallpaper from showing through the text.
        Rectangle {
            visible: ControlStyle.frame === "glass"
            anchors.fill: parent
            radius: 28
            color: Colors.withAlpha(Colors.background, 0.5)
        }

        WidgetFrame {
            id: surface
            visible: !panel.bare
            anchors.fill: parent
            themeId: ControlStyle.themeId
            title: ControlStyle.frame === "console" ? "control" : ""
            seal: "控"
        }

        // Still: a quiet sheet, no frame at all.
        Rectangle {
            visible: panel.bare
            anchors.fill: parent
            radius: 18
            color: Colors.withAlpha(Colors.surface_container_low, 0.94)
        }

        FocusScope {
            anchors.fill: parent
            focus: root.opened

            Keys.onEscapePressed: root.close()

            Flickable {
                id: flick
                x: panel.pad
                y: panel.headRoom + panel.pad
                width: panel.width - 2 * panel.pad
                height: panel.height - panel.headRoom - panel.footRoom - 2 * panel.pad
                contentWidth: width
                contentHeight: Math.max(height, layout.implicitHeight)
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: interactive

                ColumnLayout {
                    id: layout
                    width: flick.width
                    height: flick.contentHeight
                    spacing: 22

                    Masthead {
                        Layout.fillWidth: true
                        opacity: root.reveal(0)
                        transform: Translate {
                            y: (1 - root.reveal(0)) * 16
                        }
                        onAvatarClicked: root.openPanel("avatar")
                    }

                    Toggles {
                        Layout.fillWidth: true
                        opacity: root.reveal(1)
                        transform: Translate {
                            y: (1 - root.reveal(1)) * 16
                        }
                        center: root
                    }

                    Levels {
                        Layout.fillWidth: true
                        opacity: root.reveal(2)
                        transform: Translate {
                            y: (1 - root.reveal(2)) * 16
                        }
                    }

                    NowPlaying {
                        Layout.fillWidth: true
                        opacity: root.reveal(3)
                        transform: Translate {
                            y: (1 - root.reveal(3)) * 16
                        }
                        visible: Services.Media.activePlayer !== null
                    }

                    NotificationList {
                        Layout.fillWidth: true
                        opacity: root.reveal(4)
                        transform: Translate {
                            y: (1 - root.reveal(4)) * 16
                        }
                        Layout.fillHeight: true
                        center: root
                    }

                    Vitals {
                        Layout.fillWidth: true
                        opacity: root.reveal(5)
                        transform: Translate {
                            y: (1 - root.reveal(5)) * 16
                        }
                    }

                    PowerRow {
                        Layout.fillWidth: true
                        opacity: root.reveal(6)
                        transform: Translate {
                            y: (1 - root.reveal(6)) * 16
                        }
                        center: root
                    }
                }
            }
        }
    }

    // ── Animations ────────────────────────────────────────────────────────────

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 0.5
            duration: 280
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "x"
            to: root.openX
            duration: 340
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "intro"
            from: 0
            to: 1
            duration: 640
        }
        // Then fresh state, read once the slide is over (each read is a
        // fork of this large process, kept out of the motion).
        onFinished: {
            if (!root.opened)
                return;
            // (and it keeps clear of the bar if that moves to another edge)
            panel.x = Qt.binding(() => root.openX);
            Services.Radios.refresh();
            Services.NightLight.checkAvailable();
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: scrim
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "x"
            to: root.closedX
            duration: 260
            easing.type: Easing.InCubic
        }
        onFinished: root.visible = false
    }
}
