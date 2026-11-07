pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The workspaces on the spine: a dot for each, the one you're on drawn out
// into a bar in the accent, the ones with windows brighter. A click goes
// to one; the wheel steps through them.
Item {
    id: dots

    property bool vertical: false
    property int focusedWs: 1
    property int wsCount: 5
    property var occupied: n => false
    property color ink: Colors.on_surface
    property color accent: Colors.primary

    readonly property real dot: 7
    readonly property real longLen: 20
    readonly property real step: 13

    implicitWidth: dots.vertical ? 34 : (dots.wsCount - 1) * dots.step + dots.longLen + 12
    implicitHeight: dots.vertical ? (dots.wsCount - 1) * dots.step + dots.longLen + 12 : 34

    Repeater {
        model: dots.wsCount

        Item {
            id: slot
            required property int index
            readonly property int ws: slot.index + 1
            readonly property bool here: slot.ws === dots.focusedWs
            // Along the strip: the bar of the one you're on pushes the
            // later dots along.
            readonly property real at: 6 + slot.index * dots.step + (slot.ws > dots.focusedWs ? dots.longLen - dots.dot : 0)
            readonly property real len: slot.here ? dots.longLen : dots.dot

            x: dots.vertical ? 0 : slot.at - 3
            y: dots.vertical ? slot.at - 3 : 0
            width: dots.vertical ? dots.width : slot.len + 6
            height: dots.vertical ? slot.len + 6 : dots.height

            Behavior on x {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dots.vertical ? dots.dot : slot.len
                height: dots.vertical ? slot.len : dots.dot
                radius: dots.dot / 2
                color: slot.here ? dots.accent : Colors.withAlpha(dots.ink, dots.occupied(slot.ws) ? (pick.containsMouse ? 0.95 : 0.7) : (pick.containsMouse ? 0.6 : 0.26))

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }
            }

            MouseArea {
                id: pick
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Hyprland.changeWorkspace(slot.ws)
            }
        }
    }

    // The wheel, anywhere over the dots: a notch a workspace (a touchpad's
    // little deltas add up to notches).
    property real wheelSum: 0

    WheelHandler {
        onWheel: event => {
            dots.wheelSum += event.angleDelta.y;
            if (Math.abs(dots.wheelSum) < 120)
                return;
            const d = dots.wheelSum > 0 ? -1 : 1;
            dots.wheelSum = 0;
            const next = Math.max(1, Math.min(dots.wsCount + 1, dots.focusedWs + d));
            if (next !== dots.focusedWs)
                Services.Hyprland.changeWorkspace(next);
        }
    }
}
