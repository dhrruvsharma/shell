pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.components
import qs.Core
import qs.modules.lock
import qs.services as Services

// The bar laid out flat over your wallpaper, as it stands (a plate in the
// customizer's book): its widgets in their islands, in the theme's look and
// the colours and widths set in the book, the media pill in the middle and
// the tray at the end. The widgets are the bar's own (modules/bar/
// components), and text that doesn't fit scrolls under the pointer as it
// would on the bar. Hidden ones keep their place as dashed ghosts. A click
// on anything is `picked`.
//
// `part` draws one stretch of it (its left end, the middle, its right
// end), so each can be shown large enough to read; it's drawn lying down
// whichever edge the bar is on, and shrunk to fit when it's longer than
// the strip is wide.
Item {
    id: root

    // "all", or "left", "middle" or "right".
    property string part: "all"
    // What the pointer is over ("" for nothing), and a widget lit from the
    // facing page.
    property string hoveredId: ""
    property string litId: ""
    // Each widget's width as wide as its text ({ id: px }), from the bar's
    // own widgets here.
    property var naturals: ({})
    readonly property bool hasLeft: root.part === "all" || root.part === "left"
    readonly property bool hasMiddle: root.part === "all" || root.part === "middle"
    readonly property bool hasRight: root.part === "all" || root.part === "right"

    signal picked(string which)

    function noteNatural(id, w) {
        if (root.naturals[id] === w)
            return;
        const next = Object.assign({}, root.naturals);
        next[id] = w;
        root.naturals = next;
    }

    implicitHeight: 64

    // ── Your wallpaper, behind ───────────────────────────────────────────────
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: Math.min(12, (BookStyle.b.radius ?? 6) + 4)
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.background
        }

        // The top of the wallpaper, where a top bar sits.
        Image {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: width * 9 / 16
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: mask.radius
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
    }

    // ── The bar ──────────────────────────────────────────────────────────────
    Item {
        id: track

        readonly property real natural: root.part === "left" ? leftRow.width + 32
            : root.part === "middle" ? capsule.width + 32
            : root.part === "right" ? rightRow.width + 32
            : 16 + leftRow.width + 28 + capsule.width + 28 + rightRow.width + 16
        readonly property real s: Math.min(1, root.width / Math.max(1, track.natural))

        width: root.width / track.s
        height: Services.BarLayout.size
        scale: track.s
        transformOrigin: Item.TopLeft
        y: (root.height - height * track.s) / 2

        Row {
            id: leftRow
            x: root.part === "left" ? (track.width - width) / 2 : 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasLeft
            spacing: 8

            Repeater {
                model: root.hasLeft ? Services.BarLayout.left : []

                MapIsland {
                    required property var modelData
                    ids: modelData
                }
            }
        }

        // The media pill, centred in the room between the two ends.
        MapThing {
            id: capsule
            thingId: "media"
            visible: root.hasMiddle
            x: root.part === "middle" ? (track.width - width) / 2 : leftRow.x + leftRow.width + (rightRow.x - leftRow.x - leftRow.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            // As the media pill: as set, else 200.
            width: Services.BarSettings.widthOf("media") || Services.BarSettings.autoWidths.media
            height: 32
            ghostRadius: Services.DesktopTheme.radius(Services.DesktopTheme.look, 16, 32)

            Rectangle {
                anchors.fill: parent
                radius: capsule.ghostRadius
                color: Services.BarSettings.capsule
                border.width: Services.DesktopTheme.look.border || (Services.BarSettings.outline ? 1 : 0)
                border.color: Services.DesktopTheme.look.border ? Services.DesktopTheme.borderColor(Services.DesktopTheme.look) : Services.BarSettings.outlineColor
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
                    hovered: capsule.hovered
                }
            }
        }

        Row {
            id: rightRow
            x: root.part === "right" ? (track.width - width) / 2 : track.width - width - 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasRight
            spacing: 8

            Repeater {
                model: root.hasRight ? Services.BarLayout.right : []

                MapIsland {
                    required property var modelData
                    ids: modelData
                }
            }

            // The tray's button.
            MapThing {
                thingId: "tray"
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                ghostRadius: 13

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: Services.BarSettings.capsule
                    border.width: 1
                    border.color: Colors.outline_variant

                    Text {
                        anchors.centerIn: parent
                        text: Icons.arrowLeft
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 14
                        color: Services.BarSettings.ink
                    }
                }
            }
        }
    }

    // An island of the bar, as the bar groups it: in a tray when two or more
    // of its widgets show. Hidden ones sit in it as ghosts.
    component MapIsland: Rectangle {
        id: island

        required property var ids
        readonly property int shownCount: island.ids.filter(id => Services.BarSettings.shown(id)).length
        readonly property bool grouped: island.shownCount > 1
        readonly property real pad: island.grouped ? 5 : 0
        readonly property var look: Services.DesktopTheme.look

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: atoms.width + 2 * island.pad
        height: 34
        radius: Services.DesktopTheme.radius(island.look, 16, Math.min(width, height))
        color: island.grouped ? Services.BarSettings.group : "transparent"
        border.width: island.grouped && island.look.shape !== "print" ? (island.look.border || (Services.BarSettings.outline ? 1 : 0)) : 0
        border.color: island.look.border ? Services.DesktopTheme.borderColor(island.look) : Services.BarSettings.outlineColor

        Row {
            id: atoms
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: island.ids

                MapThing {
                    id: atom

                    required property string modelData

                    thingId: modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    width: widget.implicitWidth
                    height: widget.implicitHeight
                    // The pill's own corners (components/BarPill).
                    ghostRadius: Services.DesktopTheme.radius(island.look, 13, Math.min(width, height))

                    // The bar's own widget, as it looks on the bar now, at the
                    // width set for it; it scrolls its text under the pointer.
                    Loader {
                        id: widget
                        anchors.centerIn: parent
                        source: {
                            const e = Services.BarSettings.info(atom.modelData);
                            return e && e.file ? Qt.resolvedUrl("../bar/" + e.file) : "";
                        }
                        onLoaded: {
                            // A picture of the widget: it opens nothing here.
                            if ("preview" in item)
                                item["preview"] = true;
                            if ("barId" in item)
                                item["barId"] = atom.modelData;
                            if ("forceHover" in item)
                                item["forceHover"] = Qt.binding(() => atom.hovered);
                            if ("naturalWidth" in item)
                                root.noteNatural(atom.modelData, item["naturalWidth"]);
                        }
                    }

                    Connections {
                        target: widget.item
                        ignoreUnknownSignals: true

                        function onNaturalWidthChanged() {
                            root.noteNatural(atom.modelData, widget.item["naturalWidth"]);
                        }
                    }
                }
            }
        }
    }

    // Something on the bar to show or hide: what it holds draws it; hidden,
    // it fades to a dashed ghost with a crossed-out eye. It takes the
    // pointer over whatever it holds, so the widgets' own clicks never run.
    component MapThing: Item {
        id: thing

        required property string thingId
        property real ghostRadius: 13
        readonly property bool on: Services.BarSettings.shown(thing.thingId)
        readonly property bool hovered: area.containsMouse
        default property alias content: holder.data

        Item {
            id: holder
            anchors.fill: parent
            opacity: thing.on ? 1 : 0.22

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
        }

        Item {
            anchors.fill: parent
            visible: !thing.on

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.GeometryRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.withAlpha(Colors.on_surface, 0.75)
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 2.5]

                    PathRectangle {
                        x: 0.75
                        y: 0.75
                        width: thing.width - 1.5
                        height: thing.height - 1.5
                        radius: Math.min(thing.ghostRadius, (thing.height - 1.5) / 2)
                    }
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: "visibility_off"
                font.pixelSize: Math.min(18, thing.height - 8)
                color: Colors.on_surface
            }
        }

        // Lit round the edge under the pointer, or from the facing page.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: thing.ghostRadius + 3
            color: "transparent"
            border.width: 2
            border.color: BookStyle.accent
            visible: thing.hovered || root.litId === thing.thingId
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.picked(thing.thingId)
            onContainsMouseChanged: {
                if (containsMouse)
                    root.hoveredId = thing.thingId;
                else if (root.hoveredId === thing.thingId)
                    root.hoveredId = "";
            }
        }
    }
}
