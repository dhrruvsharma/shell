pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// A wide switch: its glyph in a lamp that lights in the accent, a name and
// what it's doing now. The body flips it; the chevron at its end, where
// there is one, opens its own panel.
Item {
    id: tile

    property string icon
    property string title
    property string status
    // A figure beside the name (a device's battery).
    property string badge
    property bool on
    property bool detail: true

    signal toggled
    signal opened

    readonly property color accent: ControlStyle.accent
    readonly property real r: 16

    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ControlStyle.corner(tile.r, 0)
        topRightRadius: ControlStyle.corner(tile.r, 1)
        bottomRightRadius: ControlStyle.corner(tile.r, 2)
        bottomLeftRadius: ControlStyle.corner(tile.r, 3)
        color: tile.on ? Colors.withAlpha(tile.accent, ControlStyle.paper ? 0.14 : 0.17) : body.containsMouse || more.containsMouse ? ControlStyle.wellHover : ControlStyle.well
        border.width: 1
        border.color: tile.on ? Colors.withAlpha(tile.accent, 0.5) : ControlStyle.line

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        anchors.rightMargin: tile.detail ? 44 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.toggled()
    }

    // The lamp.
    Rectangle {
        id: lamp
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: ControlStyle.radius(19)
        color: tile.on ? tile.accent : Colors.withAlpha(ControlStyle.ink, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Glyph {
            anchors.centerIn: parent
            text: tile.icon
            filled: tile.on
            font.pixelSize: 21
            color: tile.on ? ControlStyle.inkOn(tile.accent) : Colors.withAlpha(ControlStyle.ink, 0.78)
        }
    }

    Column {
        anchors.left: lamp.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: tile.detail ? 50 : 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: tile.title
            elide: Text.ElideRight
            font.family: ControlStyle.ui
            font.pixelSize: 14
            font.weight: Font.DemiBold
            font.capitalization: ControlStyle.caps
            font.letterSpacing: ControlStyle.upper ? 1 : 0
            color: ControlStyle.ink
        }

        // What it's doing, and the badge at its end (the name gives way).
        Item {
            width: parent.width
            height: statusText.implicitHeight

            Text {
                id: statusText
                width: Math.min(implicitWidth, parent.width - (badgeText.visible ? badgeText.implicitWidth + 6 : 0))
                text: tile.status
                elide: Text.ElideRight
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: tile.on ? Colors.withAlpha(ControlStyle.ink, 0.8) : Colors.withAlpha(ControlStyle.ink, 0.58)
            }

            Text {
                id: badgeText
                visible: tile.badge.length > 0
                anchors.left: statusText.right
                anchors.leftMargin: 6
                anchors.baseline: statusText.baseline
                text: tile.badge
                font.family: ControlStyle.mono
                font.pixelSize: 11
                font.weight: Font.Medium
                color: tile.on ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.6)
            }
        }
    }

    // The way into its panel.
    MouseArea {
        id: more
        visible: tile.detail
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.opened()

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height - 24
            color: tile.on ? Colors.withAlpha(tile.accent, 0.4) : ControlStyle.line
        }

        Glyph {
            anchors.centerIn: parent
            text: "chevron_right"
            font.pixelSize: 22
            color: more.containsMouse ? tile.accent : Colors.withAlpha(ControlStyle.ink, 0.62)
        }
    }
}
