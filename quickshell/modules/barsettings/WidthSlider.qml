import QtQuick
import qs.colors
import qs.services as Services

// A width to drag, `from`..`to` px in whole pixels. `muted` (the width is
// automatic) shows it as a hollow knob on a plain rail: where it is, not
// what's set; dragging it sets it all the same.
Item {
    id: root

    property real from: 24
    property real to: 480
    property real value: 100
    property bool muted: false

    signal moved(real value)

    readonly property bool dragging: area.pressed
    property real dragValue: 0
    // The drag wins while the pointer is down, so the knob never lags
    // behind it waiting for the setting to come back.
    readonly property real shownValue: root.dragging ? root.dragValue : Math.max(root.from, Math.min(root.to, root.value))
    readonly property real fraction: (root.shownValue - root.from) / Math.max(1, root.to - root.from)

    implicitHeight: 24

    Rectangle {
        id: rail
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: knob.width / 2
        anchors.rightMargin: knob.width / 2
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: Services.DesktopTheme.rad(3)
        color: Colors.surface_container_highest

        Rectangle {
            width: root.fraction * rail.width
            height: parent.height
            radius: parent.radius
            color: root.muted ? Colors.withAlpha(Colors.on_surface_variant, 0.35) : Colors.primary
        }
    }

    Rectangle {
        id: knob
        x: root.fraction * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 9
        color: root.muted ? Colors.surface_container_high : Colors.primary
        border.width: root.muted || area.containsMouse || area.pressed ? 2 : 0
        border.color: root.muted && !area.containsMouse && !area.pressed ? Colors.outline : Colors.primary_fixed_dim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function at(mouse) {
            const span = Math.max(1, root.width - knob.width);
            const f = Math.max(0, Math.min(1, (mouse.x - knob.width / 2) / span));
            root.dragValue = Math.round(root.from + f * (root.to - root.from));
            root.moved(root.dragValue);
        }

        onPressed: mouse => at(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                at(mouse);
        }
    }

    // The wheel nudges it by 4 px.
    WheelHandler {
        onWheel: event => root.moved(Math.max(root.from, Math.min(root.to, Math.round(root.shownValue + (event.angleDelta.y > 0 ? 4 : -4)))))
    }
}
