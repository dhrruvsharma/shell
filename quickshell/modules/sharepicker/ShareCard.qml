pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.colors
import qs.modules.control

// A workspace on the shelf: its windows, live, on the wallpaper, over its
// name. Everything on it fits: a scrolling layout's columns run past the edge
// of the screen, and each of them can be shared, from here if nowhere else.
// Anywhere that isn't a window is the workspace.
Item {
    id: card

    // An entry of the session's shelf, and its windows.
    required property var info
    required property var windows
    // The screen it would be on, for the proportions.
    required property var output
    // The view: what's lit, and how far the rest goes down.
    required property var owner
    property real rounding: 0

    readonly property string key: "workspace:" + info.capture
    readonly property bool showing: info.showing === true
    readonly property bool shareable: info.capture > 0
    readonly property bool hot: shareable && owner.hotKey === key
    readonly property string name: info.workspace === null ? "Elsewhere" : info.workspace < 0 ? info.name.replace(/^special:/, "") : "Workspace " + info.name

    readonly property var frame: {
        let left = output.x, right = output.x + output.w, top = output.y, bottom = output.y + output.h;
        for (const w of windows) {
            left = Math.min(left, w.x);
            right = Math.max(right, w.x + w.w);
            top = Math.min(top, w.y);
            bottom = Math.max(bottom, w.y + w.h);
        }
        const s = Math.min(picture.width / (right - left), picture.height / (bottom - top));
        return {
            s: s,
            x: (picture.width - (right - left) * s) / 2 - left * s,
            y: (picture.height - (bottom - top) * s) / 2 - top * s
        };
    }

    // The window at a point in `other`'s coordinates, or null.
    function windowAt(other, px, py) {
        for (let i = rep.count - 1; i >= 0; i--) {
            const item = rep.itemAt(i) as ShareWindow;
            if (item?.holds(other, px, py))
                return item;
        }
        return null;
    }

    function holds(other, px, py) {
        const p = mapFromItem(other, px, py);
        return p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;
    }

    function windowFor(id) {
        for (let i = 0; i < rep.count; i++) {
            const item = rep.itemAt(i) as ShareWindow;
            if (item?.info.id === id)
                return item;
        }
        return null;
    }

    readonly property Item surface: picture

    Item {
        id: picture

        width: card.width
        height: card.height - caption.height - 8
        layer.enabled: ControlStyle.radius(10) > 0
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: picture.width
                height: picture.height
                radius: ControlStyle.radius(10)
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.surface_container
        }

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(480, 300)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: card.owner.hotKey !== "" && !card.hot ? card.owner.dim : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Repeater {
                id: rep

                model: card.windows

                ShareWindow {
                    required property var modelData

                    info: modelData
                    x: card.frame.x + modelData.x * card.frame.s
                    y: card.frame.y + modelData.y * card.frame.s
                    width: modelData.w * card.frame.s
                    height: modelData.h * card.frame.s
                    radius: card.rounding * card.frame.s
                    reach: 10
                    hot: card.owner.hotKey === "window:" + modelData.id
                    dim: card.owner.lit(modelData) ? 0 : card.owner.dim
                }
            }
        }
    }

    Rectangle {
        anchors.fill: picture
        anchors.margins: -2
        radius: ControlStyle.radius(10) + 2
        color: "transparent"
        border.width: card.hot ? 2 : 1
        border.color: card.hot ? ControlStyle.accent : Colors.withAlpha(Colors.on_surface, 0.16)

        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Text {
        id: caption

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: ControlStyle.label(card.showing ? card.name + " · on screen" : card.name)
        font.family: ControlStyle.body
        font.capitalization: ControlStyle.caps
        font.letterSpacing: ControlStyle.labelSpacing * 0.5
        font.pixelSize: 13
        color: Colors.withAlpha(Colors.on_surface, card.hot ? 1 : 0.72)
    }
}
