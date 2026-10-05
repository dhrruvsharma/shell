pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.services

// The whole deck in one line, for the wallpaper picker: a segment per
// wallpaper in its scheme's source colour (sorted by colour, a spectrum),
// a bracket round the cards in hand, ticks over the favourites and a dot
// under the wallpaper on screen. Hover for a glimpse of any wallpaper;
// click or drag to go there.
Item {
    id: ribbon

    // One colour per wallpaper ("" while it isn't read yet).
    property var colors: []
    // Indexes of the favourites.
    property var favourites: []
    // The deck's position (fractional while it moves) and the cards shown
    // on each side of the one in front.
    property real pos: 0
    property int span: 7
    // The wallpaper on screen, or -1.
    property int activeIndex: -1
    property real u: 1
    property color accent: Colors.primary
    property color ink: Colors.on_surface
    // Thumbnail URLs and names, for the glimpse.
    property var thumbs: []
    property var names: []

    readonly property int count: colors.length
    readonly property real seg: count > 0 ? width / count : 0
    readonly property bool active: mouse.containsMouse || mouse.pressed

    signal scrub(real index)
    signal settle(int index)

    implicitHeight: 26 * u

    // The track.
    Item {
        id: track
        width: parent.width
        height: (ribbon.active ? 12 : 8) * ribbon.u
        anchors.verticalCenter: parent.verticalCenter

        Behavior on height {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: ribbon.count

            Rectangle {
                required property int index
                readonly property string c: ribbon.colors[index] ?? ""
                x: index * ribbon.seg
                // A hair wider than its slot, so neighbours never leave a seam.
                width: ribbon.seg + 0.6
                height: track.height
                color: c !== "" ? c : Colors.withAlpha(ribbon.ink, 0.14)
                topLeftRadius: index === 0 ? height / 2 : 0
                bottomLeftRadius: topLeftRadius
                topRightRadius: index === ribbon.count - 1 ? height / 2 : 0
                bottomRightRadius: topRightRadius
            }
        }
    }

    // Favourites: ticks over the track.
    Repeater {
        model: ribbon.favourites

        Rectangle {
            required property int modelData
            x: (modelData + 0.5) * ribbon.seg - width / 2
            y: track.y - 5 * ribbon.u
            width: Math.max(2, Math.min(ribbon.seg - 1, 3 * ribbon.u))
            height: 3 * ribbon.u
            radius: width / 2
            color: "#ff7a93"
        }
    }

    // The wallpaper on screen: a dot under the track.
    Rectangle {
        visible: ribbon.activeIndex >= 0
        x: (ribbon.activeIndex + 0.5) * ribbon.seg - width / 2
        y: track.y + track.height + 3 * ribbon.u
        width: 4 * ribbon.u
        height: width
        radius: width / 2
        color: ribbon.ink
    }

    // The cards in hand.
    Rectangle {
        readonly property real from: Math.max(0, ribbon.pos - ribbon.span)
        readonly property real to: Math.min(ribbon.count, ribbon.pos + ribbon.span + 1)
        visible: ribbon.count > 0
        x: from * ribbon.seg - 3 * ribbon.u
        width: Math.max(6 * ribbon.u, (to - from) * ribbon.seg + 6 * ribbon.u)
        y: track.y - 4 * ribbon.u
        height: track.height + 8 * ribbon.u
        radius: DesktopTheme.rad(5) * ribbon.u
        color: "transparent"
        border.width: Math.max(1, 1.3 * ribbon.u)
        border.color: Colors.withAlpha(ribbon.ink, 0.55)
    }

    // The card in front.
    Rectangle {
        visible: ribbon.count > 0
        x: (ribbon.pos + 0.5) * ribbon.seg - width / 2
        y: track.y - 6 * ribbon.u
        width: Math.max(3 * ribbon.u, Math.min(ribbon.seg, 6 * ribbon.u))
        height: track.height + 12 * ribbon.u
        radius: width / 2
        color: ribbon.accent
        border.width: 1
        border.color: Colors.withAlpha("black", 0.35)
    }

    MouseArea {
        id: mouse

        readonly property int at: ribbon.count > 0 ? Math.max(0, Math.min(ribbon.count - 1, Math.floor(mouseX / ribbon.seg))) : -1

        anchors.fill: parent
        anchors.topMargin: -6 * ribbon.u
        anchors.bottomMargin: -6 * ribbon.u
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => ribbon.scrub(Math.max(0, Math.min(ribbon.count - 1, mouse.x / ribbon.seg - 0.5)))
        onPositionChanged: mouse => {
            if (pressed)
                ribbon.scrub(Math.max(0, Math.min(ribbon.count - 1, mouse.x / ribbon.seg - 0.5)));
        }
        onReleased: ribbon.settle(at)
    }

    // A glimpse of the wallpaper under the pointer.
    Rectangle {
        id: glimpse

        readonly property int index: mouse.at
        // Follows the pointer; the picture waits for it to slow down.
        property string shown: ""

        visible: mouse.containsMouse && !mouse.pressed && index >= 0
        x: Math.max(0, Math.min(ribbon.width - width, mouse.mouseX - width / 2))
        y: ribbon.height + 8 * ribbon.u
        width: 176 * ribbon.u
        height: glimpseCol.implicitHeight + 12 * ribbon.u
        radius: DesktopTheme.rad(12) * ribbon.u
        color: Colors.surface_container_low
        border.width: 1
        border.color: Colors.withAlpha(ribbon.ink, 0.16)

        onIndexChanged: glimpseTimer.restart()
        onVisibleChanged: {
            if (visible)
                glimpseTimer.restart();
        }

        Timer {
            id: glimpseTimer
            interval: 70
            onTriggered: glimpse.shown = glimpse.index >= 0 ? (ribbon.thumbs[glimpse.index] ?? "") : ""
        }

        Column {
            id: glimpseCol
            x: 6 * ribbon.u
            y: 6 * ribbon.u
            width: parent.width - 12 * ribbon.u
            spacing: 5 * ribbon.u

            Rectangle {
                id: glimpseFrame
                width: parent.width
                height: Math.round(width * 10 / 16)
                radius: DesktopTheme.rad(8) * ribbon.u
                color: glimpse.index >= 0 && ribbon.colors[glimpse.index] ? ribbon.colors[glimpse.index] : Colors.surface_container_high

                Image {
                    anchors.fill: parent
                    source: glimpse.shown
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 1.25, height * 1.25)
                    asynchronous: true
                    smooth: true
                }

                // Rounds the picture's corners (see SwatchCard).
                Rectangle {
                    visible: glimpseFrame.radius > 0
                    anchors.fill: parent
                    anchors.margins: -border.width
                    radius: glimpseFrame.radius + border.width
                    color: "transparent"
                    border.width: 4 * ribbon.u
                    border.color: glimpse.color
                }
            }

            StyledText {
                width: parent.width
                text: glimpse.index >= 0 ? (glimpse.index + 1) + "  ·  " + (ribbon.names[glimpse.index] ?? "") : ""
                elide: Text.ElideMiddle
                font.pixelSize: 11 * ribbon.u
                color: Colors.on_surface
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
