pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.desktopwidgets

// One toast: a NotificationCard on the desktop theme's own frame, the same
// surface as the control centre (scrap plate, lancet window, newsprint…),
// with the time it has left drawn along its foot. It slides in from the
// screen's edge.
Item {
    id: root

    required property var n
    readonly property alias replying: card.replying

    readonly property bool bare: ControlStyle.frame === "bare"
    readonly property real pad: bare ? 16 : Math.min(ControlStyle.st.pad, 18)
    readonly property real headRoom: bare ? 0 : surface.tabRoom + surface.headRoom
    readonly property real footRoom: bare ? 0 : surface.footRoom
    readonly property int lifetime: (n?.notification?.expireTimeout ?? 0) > 0 ? n.notification.expireTimeout : 5000

    // What's left of its time (1..0); held, it's full again, and starts
    // over when let go, as the service's timer does.
    property real remaining: 1

    implicitHeight: headRoom + 2 * pad + card.implicitHeight + footRoom + 4

    NumberAnimation {
        target: root
        property: "remaining"
        from: 1
        to: 0
        duration: root.lifetime
        running: !!root.n && root.n.popup && !root.n.critical && !root.n.held
    }

    // Slides in.
    property real enter: 0
    Component.onCompleted: enter = 1
    Behavior on enter {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: body
        width: parent.width
        height: parent.height
        x: (1 - root.enter) * (root.width * 0.4)
        opacity: root.enter

        Rectangle {
            visible: ControlStyle.frame === "glass"
            anchors.fill: parent
            radius: 28
            color: Colors.withAlpha(Colors.background, 0.55)
        }

        WidgetFrame {
            id: surface
            visible: !root.bare
            anchors.fill: parent
            themeId: ControlStyle.themeId
            title: ControlStyle.frame === "console" ? "notify" : ""
            seal: "信"
        }

        // Still: a quiet sheet.
        Rectangle {
            visible: root.bare
            anchors.fill: parent
            radius: 16
            color: Colors.withAlpha(Colors.surface_container_low, 0.96)
            border.width: 1
            border.color: ControlStyle.line
        }

        NotificationCard {
            id: card
            x: root.pad
            y: root.headRoom + root.pad
            width: parent.width - 2 * root.pad
            n: root.n
            toast: true
            // (clear of the scroll's seal)
            headerRight: ControlStyle.frame === "scroll" ? 24 : 0
        }

        // The time left.
        Rectangle {
            visible: !(root.n?.critical ?? true)
            x: root.pad
            y: parent.height - root.footRoom - root.pad * 0.5 - 1
            width: (parent.width - 2 * root.pad) * (root.n?.held ? 1 : root.remaining)
            height: 2
            radius: 1
            color: ControlStyle.accent
            opacity: root.n?.held ? 0.3 : 0.7
        }
    }
}
