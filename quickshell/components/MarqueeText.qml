import QtQuick
import qs.colors

// A line of text in a set width. When it fits it sits by `alignment`; when
// it doesn't it's cut short with "…" and, as `mode` says, scrolled through
// like a ticker: "hover" while `hovered` is set (the media pill's way),
// "always", or "cut" (never). It runs left at `speed` px a second with a
// copy `gap` behind it, rests 2 s at the start of each turn, and glides
// back to the start when it stops. Nothing moves while it fits or isn't
// visible.
Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property color color: Colors.on_surface
    property string mode: "hover"
    property bool hovered: false
    property real gap: 40
    property real speed: 50
    property int alignment: Qt.AlignHCenter

    // The text's own width, whatever room it's given.
    readonly property real textWidth: label.implicitWidth
    readonly property bool overflowing: root.textWidth > root.width + 0.5
    readonly property bool scrolling: root.overflowing && root.visible && (root.mode === "always" || (root.mode === "hover" && root.hovered))
    // Out of its resting place (scrolling, or on its way back).
    readonly property bool moving: root.scrolling || runner.running || home.running

    implicitWidth: root.textWidth
    implicitHeight: label.implicitHeight
    clip: root.overflowing

    onScrollingChanged: {
        if (root.scrolling)
            home.stop();
        else if (mover.x !== 0)
            home.restart();
    }

    Item {
        id: mover
        height: parent.height

        StyledText {
            id: label
            x: root.overflowing ? 0 : root.alignment === Qt.AlignLeft ? 0 : root.alignment === Qt.AlignRight ? root.width - implicitWidth : (root.width - implicitWidth) / 2
            // Cut to the room it has while it rests there.
            width: root.overflowing && !root.moving ? root.width : implicitWidth
            elide: root.overflowing && !root.moving ? Text.ElideRight : Text.ElideNone
            color: root.color
        }

        // The copy that comes round after it, made only while it moves.
        Loader {
            x: root.textWidth + root.gap
            active: root.moving
            sourceComponent: StyledText {
                text: label.text
                font: label.font
                color: root.color
            }
        }
    }

    SequentialAnimation {
        id: runner
        running: root.scrolling
        loops: Animation.Infinite

        PauseAnimation { duration: 2000 }
        NumberAnimation {
            target: mover
            property: "x"
            from: 0
            to: -(root.textWidth + root.gap)
            duration: (root.textWidth + root.gap) * 1000 / Math.max(1, root.speed)
            easing.type: Easing.Linear
        }
        PropertyAction { target: mover; property: "x"; value: 0 }
    }

    NumberAnimation {
        id: home
        target: mover
        property: "x"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
    }
}
