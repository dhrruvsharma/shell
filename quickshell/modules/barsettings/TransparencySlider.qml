import QtQuick
import qs.colors
import qs.services as Services

// How see-through the containers are: 0 (solid, at the left) to 1 (clear).
// The track fades the containers' own colour away over a checkerboard, so
// it reads as what it does; it snaps to whole percents.
Item {
    id: root

    // 0..1, as BarSettings has it.
    property real value: 0
    property color fill: Colors.surface_container

    signal moved(real value)

    readonly property bool dragging: area.pressed
    property real dragValue: 0
    // The drag wins while the pointer is down, so the knob never lags
    // behind it waiting for the setting to come back.
    readonly property real shownValue: root.dragging ? root.dragValue : Math.max(0, Math.min(1, root.value))

    implicitHeight: 28

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: knob.width / 2
        anchors.rightMargin: knob.width / 2
        anchors.verticalCenter: parent.verticalCenter
        height: 18

        readonly property real radius: Services.DesktopTheme.rad(9)

        // The checkerboard, painted once per size, inside the track's
        // rounded ends.
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const s = 6;
                const r = Math.min(track.radius, height / 2);
                ctx.reset();
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, r, r);
                ctx.clip();
                ctx.fillStyle = "#d9d9d9";
                ctx.fillRect(0, 0, width, height);
                ctx.fillStyle = "#9a9a9a";
                for (let y = 0; y < height; y += s)
                    for (let x = (y / s) % 2 ? s : 0; x < width; x += 2 * s)
                        ctx.fillRect(x, y, s, s);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: track.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.withAlpha(root.fill, 1) }
                GradientStop { position: 1; color: Colors.withAlpha(root.fill, 0) }
            }
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.9)
        }
    }

    Rectangle {
        id: knob
        x: root.shownValue * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        radius: 13
        color: Colors.surface_container_highest
        border.width: 3
        border.color: area.pressed || area.containsMouse ? Colors.primary : Colors.on_surface

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }

        // The containers' colour at the strength it's set to.
        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            radius: 6
            color: Colors.withAlpha(root.fill, 1 - root.shownValue)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function at(mouse) {
            const span = root.width - knob.width;
            const v = Math.round(Math.max(0, Math.min(1, (mouse.x - knob.width / 2) / span)) * 100) / 100;
            root.dragValue = v;
            root.moved(v);
        }

        onPressed: mouse => at(mouse)
        onPositionChanged: mouse => {
            if (pressed)
                at(mouse);
        }
    }

    // The wheel nudges it by 5 %.
    WheelHandler {
        onWheel: event => {
            const step = event.angleDelta.y > 0 ? -0.05 : 0.05;
            root.moved(Math.round(Math.max(0, Math.min(1, root.value + step)) * 100) / 100);
        }
    }
}
