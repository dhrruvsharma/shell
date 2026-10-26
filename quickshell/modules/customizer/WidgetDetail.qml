pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.services as Services

// One of the bar's widgets drawn large, as an engraver's detail, with a
// dimension line over it giving its width: as set, or "auto" and the width
// of its text.
Item {
    id: detail

    property string widgetId: "clock"
    readonly property var entry: Services.BarSettings.info(detail.widgetId)
    readonly property real set: Services.BarSettings.widthOf(detail.widgetId)
    // The widget's own width on the bar, unscaled.
    readonly property real natural: detail.widgetId === "media" ? (detail.set || Services.BarSettings.autoWidths.media) : widget.item ? widget.item.width : 0
    readonly property real k: Math.min(2.2, (detail.width - 60) / Math.max(1, detail.natural))

    // The widget itself, scaled up.
    Item {
        id: holder
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64
        width: detail.natural * detail.k
        height: 30 * detail.k

        Loader {
            id: widget
            active: detail.entry !== null && detail.entry.file !== undefined
            source: active ? Qt.resolvedUrl("../bar/" + detail.entry.file) : ""
            scale: detail.k
            transformOrigin: Item.TopLeft
            onLoaded: {
                if ("preview" in item)
                    item["preview"] = true;
                if ("barId" in item)
                    item["barId"] = detail.widgetId;
                if ("forceHover" in item)
                    item["forceHover"] = true;
            }
        }

        // The media pill, as the bar draws it.
        Rectangle {
            visible: detail.widgetId === "media"
            width: detail.natural
            height: 32
            scale: detail.k
            transformOrigin: Item.TopLeft
            radius: Services.DesktopTheme.radius(Services.DesktopTheme.look, 16, 32)
            color: Services.BarSettings.capsule
            clip: true

            MarqueeText {
                anchors.centerIn: parent
                width: parent.width - 20
                text: Services.Media.activePlayer ? (Services.Media.artist ? Services.Media.title + " — " + Services.Media.artist : Services.Media.title) : "♪  Now playing"
                font.pixelSize: 17
                color: Services.BarSettings.ink
                gap: 50
                mode: Services.BarSettings.overflow
                speed: Services.BarSettings.scrollPxPerSecond
                hovered: true
            }
        }
    }

    // The dimension line: witness lines at its ends, arrows, the figure.
    Item {
        x: holder.x
        y: 18
        width: holder.width
        height: 40
        visible: detail.natural > 0

        Rectangle {
            x: 0
            y: 6
            width: 1
            height: 38
            color: BookStyle.inkSoft
        }

        Rectangle {
            x: parent.width - 1
            y: 6
            width: 1
            height: 38
            color: BookStyle.inkSoft
        }

        Rectangle {
            x: 4
            y: 18
            width: parent.width - 8
            height: 1
            color: BookStyle.accent
        }

        BookText {
            x: 1
            y: 9
            text: "◀"
            font.pixelSize: 9
            color: BookStyle.accent
        }

        BookText {
            x: parent.width - width - 1
            y: 9
            text: "▶"
            font.pixelSize: 9
            color: BookStyle.accent
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: figure.implicitWidth + 16
            height: 24
            color: BookStyle.paper

            BookText {
                id: figure
                anchors.centerIn: parent
                text: detail.set ? detail.set + " px" : "auto · " + Math.round(detail.natural) + " px"
                font.family: BookStyle.ui
                font.pixelSize: 14
                font.features: ({ "tnum": 1, "lnum": 1 })
                color: BookStyle.accent
            }
        }
    }

    BookText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: holder.bottom
        anchors.topMargin: 16
        text: "Detail · " + (detail.entry ? detail.entry.name : "") + (detail.k > 1.05 ? ", drawn " + detail.k.toFixed(1) + " times its size" : "")
        font.italic: true
        font.pixelSize: 13
        color: BookStyle.inkSoft
    }
}
