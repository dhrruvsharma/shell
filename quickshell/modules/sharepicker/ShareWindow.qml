pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.colors
import qs.components
import qs.modules.control
import qs.services as Services

// One window, live, where it is: at the size it's given. What will be shared
// stays bright and the rest goes down (`dim`), and `hot` lifts it a little.
Item {
    id: win

    // A window from the session.
    required property var info
    property real radius: 0
    // The outline's width and the shadow's reach, in this item's own scale.
    property real line: 2
    property real reach: 24
    property bool hot: false
    property real dim: 0
    // The live picture over what's under it; the desktop's own grab shows
    // the window as it is on screen, see-through and all, until this is 1.
    property real live: 1

    readonly property var toplevel: (Hyprland.toplevels.values ?? []).find(t => t.address === win.info.address) ?? null
    property bool seen: false
    // It closed. Windows that opened since aren't the portal's to share.
    readonly property bool gone: seen && toplevel === null

    // Whether the point (in `other`'s coordinates) is on this window.
    function holds(other, px, py) {
        if (gone)
            return false;
        const p = mapFromItem(other, px, py);
        return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;
    }

    visible: !gone
    z: hot ? 1 : 0
    scale: hot ? 1.012 : 1

    onToplevelChanged: {
        if (toplevel)
            seen = true;
    }
    Component.onCompleted: seen = toplevel !== null

    Behavior on scale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Behavior on dim {
        NumberAnimation {
            duration: 140
        }
    }

    RectangularShadow {
        anchors.fill: parent
        radius: win.radius
        blur: win.reach
        spread: win.reach * 0.1
        color: "#99000000"
        opacity: win.hot ? win.live : 0
        cached: true

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }

    // For a window that has nothing to show: minimized apps, a failed capture.
    Rectangle {
        anchors.fill: parent
        visible: !picture.hasContent
        radius: win.radius
        color: Colors.surface_container
        opacity: win.live

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.3
            height: width
            sourceSize: Qt.size(128, 128)
            source: Services.AppRegistry.iconForClass(win.info.class)
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }
    }

    Item {
        anchors.fill: parent
        opacity: win.live
        layer.enabled: win.radius > 0
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: win.width
                height: win.height
                radius: win.radius
            }
        }

        ScreencopyView {
            id: picture

            anchors.fill: parent
            captureSource: win.toplevel?.wayland ?? null
            live: true
            paintCursor: false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: win.radius
        color: "black"
        opacity: win.dim * win.live
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -win.line
        radius: win.radius + win.line
        color: "transparent"
        border.width: win.line
        border.color: ControlStyle.accent
        opacity: win.hot ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }
}
