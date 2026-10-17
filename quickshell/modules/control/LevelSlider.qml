pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.modules.desktopwidgets

// A level you can drag or click: its glyph (a button where it does
// something, like muting), a track drawn in the theme's meter style (HUD
// segments, a neon tube, prayer beads, a sword drawn from its scabbard…;
// a rail and a knob without a theme), the figure, and an optional chevron
// for a drawer under it.
Item {
    id: root

    property string icon
    // 0..1, as the service has it.
    property real value
    property string figure
    // Faded (muted): the track still works.
    property bool dim
    property bool iconButton
    property bool detail
    property bool detailOpen

    // While a drag or click is setting it.
    signal moved(real value)
    signal released
    signal iconClicked
    signal detailClicked

    readonly property bool dragging: track.pressed
    property real dragValue: 0
    // The drag wins over the service while the pointer is down, so the
    // track never jumps back to a level on its way.
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
    readonly property bool themed: ControlStyle.themeId !== ""

    implicitHeight: 40

    // The glyph.
    Item {
        id: glyphBox
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(18)
            color: ControlStyle.wellHover
            visible: root.iconButton && glyphArea.containsMouse
        }

        Glyph {
            anchors.centerIn: parent
            text: root.icon
            filled: !root.dim
            font.pixelSize: 21
            color: root.dim ? Colors.withAlpha(ControlStyle.ink, 0.5) : ControlStyle.accent
        }

        MouseArea {
            id: glyphArea
            anchors.fill: parent
            enabled: root.iconButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    // The chevron for the drawer.
    MouseArea {
        id: chevron
        visible: root.detail
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.detail ? 32 : 0
        height: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.detailClicked()

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(16)
            color: chevron.containsMouse || root.detailOpen ? ControlStyle.wellHover : "transparent"
        }

        Glyph {
            anchors.centerIn: parent
            text: "expand_more"
            rotation: root.detailOpen ? 180 : 0
            font.pixelSize: 22
            color: chevron.containsMouse || root.detailOpen ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.62)

            Behavior on rotation {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Text {
        id: figureText
        anchors.right: root.detail ? chevron.left : parent.right
        anchors.rightMargin: root.detail ? 4 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        horizontalAlignment: Text.AlignRight
        text: root.figure
        font.family: ControlStyle.mono
        font.pixelSize: 13
        font.weight: Font.Medium
        color: root.dim ? Colors.withAlpha(ControlStyle.ink, 0.5) : Colors.withAlpha(ControlStyle.ink, 0.85)
    }

    Item {
        id: lane
        anchors.left: glyphBox.right
        anchors.leftMargin: 10
        anchors.right: figureText.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        opacity: root.dim ? 0.45 : 1

        Loader {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.themed ? themedTrack : plainTrack
        }

        MouseArea {
            id: track
            anchors.fill: parent
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function at(x) {
                return Math.max(0, Math.min(1, x / width));
            }

            onPressed: mouse => {
                root.dragValue = at(mouse.x);
                root.moved(root.dragValue);
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const v = at(mouse.x);
                if (Math.abs(v - root.dragValue) < 0.004)
                    return;
                root.dragValue = v;
                root.moved(v);
            }
            onReleased: root.released()
        }
    }

    Component {
        id: themedTrack

        WidgetBar {
            themeId: ControlStyle.themeId
            value: root.shown
        }
    }

    // Without a theme: a rail, filled to the level, and a knob.
    Component {
        id: plainTrack

        Item {
            id: rail
            height: 22

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: 3
                color: Colors.withAlpha(ControlStyle.ink, 0.13)

                Rectangle {
                    width: Math.max(parent.height, parent.width * root.shown)
                    height: parent.height
                    radius: 3
                    color: ControlStyle.accent
                }
            }

            Rectangle {
                x: rail.width * root.shown - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.dragging || track.containsMouse ? 28 : 0
                height: width
                radius: width / 2
                color: Colors.withAlpha(ControlStyle.accent, 0.2)

                Behavior on width {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }

            Rectangle {
                x: rail.width * root.shown - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: ControlStyle.accent
                border.width: 2
                border.color: Qt.lighter(ControlStyle.accent, 1.25)
            }
        }
    }
}
