pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.components
import qs.modules.lock
import qs.services

// One wallpaper as a paint-chip card in the picker's deck (Wallpaper.qml),
// dressed in the colour scheme the wallpaper would give the desktop: the
// card is its surface, the text its on-surface, the strip of chips its
// roles with their hex codes. A Wallhaven result wears the colours
// Wallhaven reports for the image instead: chips without role names, and
// a dress made up from them.
Item {
    id: card

    // { fileName, fileUrl, ... } as the picker lists it.
    property var entry: null
    // What the card shows (a video's frame rather than the video).
    property string picture: entry ? entry.fileUrl : ""
    // The matugen scheme ({ role: "#rrggbb" }), or null until it's read.
    property var scheme: null
    // Wallhaven's colours for the image, when there's no scheme.
    property var imageColors: []
    // Pixels per design pixel (the deck scales with the screen).
    property real u: 1
    // How far this card is in front, 0..1.
    property real front: 0
    // Shade over a card further back (lifted while hovered).
    property real dim: 0
    property bool current: false
    property bool favourite: false
    // A Wallhaven result already in the wallpaper folder.
    property bool saved: false
    // 0..1 while this card's wallpaper downloads, else -1.
    property real download: -1
    property string title: ""
    property string meta: ""

    readonly property alias hovered: mouse.containsMouse
    signal clicked
    signal doubleClicked

    readonly property real pad: 9 * u
    readonly property real radius: DesktopTheme.rad(16) * u
    readonly property real thumbRadius: DesktopTheme.rad(10) * u
    readonly property real chipHeight: 22 * u

    implicitWidth: 212 * u
    implicitHeight: pad + thumb.height + 8 * u + chipHeight * 5 + 9 * u + titleText.height + 2 * u + metaText.height + pad + 2 * u

    // Ink that reads on `c`.
    function inkOn(c) {
        const q = Qt.color(c);
        const l = 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
        return l > 0.5 ? Qt.rgba(0, 0, 0, 0.78) : Qt.rgba(1, 1, 1, 0.9);
    }

    readonly property var dress: scheme ? WallpaperSwatches.dressOf(scheme)
        : imageColors && imageColors.length > 0 ? WallpaperSwatches.dressFrom(imageColors) : {
            surface: Colors.surface_container,
            raised: Colors.surface_container_high,
            low: Colors.surface_container_low,
            ink: Colors.on_surface,
            muted: Colors.on_surface_variant,
            line: Colors.outline_variant,
            accent: Colors.primary,
            accentInk: Colors.on_primary
        }

    // The five chips, top to bottom.
    readonly property var chips: scheme ? [
        { label: "primary", fill: scheme.primary },
        { label: "secondary", fill: scheme.secondary },
        { label: "tertiary", fill: scheme.tertiary },
        { label: "container", fill: scheme.primary_container },
        { label: "surface", fill: scheme.surface_container_highest }
    ] : imageColors && imageColors.length > 0 ? imageColors.slice(0, 5).map(c => ({ label: "", fill: c })) : []

    RectangularShadow {
        anchors.fill: body
        offset.y: (8 + 10 * card.front) * card.u
        blur: (22 + 18 * card.front) * card.u
        radius: body.radius
        color: Qt.rgba(0, 0, 0, 0.42 + 0.18 * card.front)
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: card.radius
        antialiasing: true
        color: card.dress.surface
        border.width: Math.max(1, card.u * (1 + card.front * 0.6))
        border.color: Qt.tint(Colors.withAlpha(card.dress.line, 0.85), Colors.withAlpha(card.dress.accent, card.front * 0.85))

        // ── The wallpaper ────────────────────────────────────────────────
        Rectangle {
            id: thumbBase
            x: card.pad
            y: card.pad
            width: parent.width - card.pad * 2
            height: Math.round(width * 10 / 16)
            color: card.dress.raised
            antialiasing: true
            radius: card.thumbRadius

            Glyph {
                anchors.centerIn: parent
                visible: thumb.status !== Image.Ready
                text: thumb.status === Image.Error ? "broken_image" : card.entry && card.entry.video ? "movie" : "image"
                font.pixelSize: 22 * card.u
                color: Colors.withAlpha(card.dress.muted, 0.5)
            }
        }

        Image {
            id: thumb
            anchors.fill: thumbBase
            source: card.picture
            fillMode: Image.PreserveAspectCrop
            // Room for the card in front, which is drawn larger.
            sourceSize: Qt.size(Math.ceil(thumbBase.width * 1.3), Math.ceil(thumbBase.height * 1.3))
            asynchronous: true
            smooth: true
            antialiasing: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 220 }
            }
        }

        // Rounds the picture's corners: a frame in the card's own colour
        // whose inside edge is the rounded corner (cheaper than a mask).
        Rectangle {
            visible: card.thumbRadius > 0
            x: thumbBase.x - border.width
            y: thumbBase.y - border.width
            width: thumbBase.width + border.width * 2
            height: thumbBase.height + border.width * 2
            radius: card.thumbRadius + border.width
            antialiasing: true
            color: "transparent"
            border.width: 5 * card.u
            border.color: card.dress.surface
        }

        // The wallpaper on screen now.
        Rectangle {
            id: currentTag
            x: thumbBase.x + 7 * card.u
            y: thumbBase.y + thumbBase.height - height - 7 * card.u
            visible: card.current
            width: currentRow.implicitWidth + 12 * card.u
            height: 19 * card.u
            radius: DesktopTheme.rad(9.5) * card.u
            antialiasing: true
            color: card.dress.accent
            transformOrigin: Item.Left

            Row {
                id: currentRow
                anchors.centerIn: parent
                spacing: 3 * card.u

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "check"
                    weight: 700
                    font.pixelSize: 12 * card.u
                    color: card.dress.accentInk
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "current"
                    font.pixelSize: 10 * card.u
                    font.weight: Font.Bold
                    font.letterSpacing: 0.4 * card.u
                    color: card.dress.accentInk
                }
            }

            // Pops in when the card is set.
            SequentialAnimation {
                id: pop
                NumberAnimation { target: currentTag; property: "scale"; from: 0.4; to: 1.12; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { target: currentTag; property: "scale"; to: 1; duration: 160; easing.type: Easing.InOutQuad }
            }
        }

        Rectangle {
            visible: card.favourite
            x: thumbBase.x + thumbBase.width - width - 6 * card.u
            y: thumbBase.y + 6 * card.u
            width: 24 * card.u
            height: width
            radius: width / 2
            antialiasing: true
            color: Qt.rgba(0, 0, 0, 0.42)

            Glyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0.5 * card.u
                text: "favorite"
                filled: true
                font.pixelSize: 14 * card.u
                color: "#ff5c7a"
            }
        }

        Rectangle {
            visible: card.saved
            x: thumbBase.x + thumbBase.width - width - 6 * card.u
            y: thumbBase.y + thumbBase.height - height - 6 * card.u
            width: 24 * card.u
            height: width
            radius: width / 2
            antialiasing: true
            color: Qt.rgba(0, 0, 0, 0.5)

            Glyph {
                anchors.centerIn: parent
                text: "download_done"
                font.pixelSize: 14 * card.u
                color: "white"
            }
        }

        // Download progress along the foot of the picture.
        Rectangle {
            visible: card.download >= 0
            x: thumbBase.x
            y: thumbBase.y + thumbBase.height - height
            width: thumbBase.width * Math.max(0.02, card.download)
            height: 3 * card.u
            color: card.dress.accent

            Behavior on width {
                NumberAnimation { duration: 200 }
            }
        }

        // ── The chips ────────────────────────────────────────────────────
        Column {
            id: chipColumn
            x: card.pad
            y: thumbBase.y + thumbBase.height + 8 * card.u
            width: thumbBase.width

            Repeater {
                model: 5

                Rectangle {
                    id: chip
                    required property int index
                    readonly property var spec: card.chips[index] ?? null
                    readonly property real r: card.thumbRadius * 0.7

                    width: chipColumn.width
                    height: card.chipHeight
                    antialiasing: true
                    topLeftRadius: index === 0 ? r : 0
                    topRightRadius: index === 0 ? r : 0
                    bottomLeftRadius: index === 4 ? r : 0
                    bottomRightRadius: index === 4 ? r : 0
                    // Not read yet: a quiet ramp of the card's own colour.
                    color: spec ? spec.fill : Qt.tint(card.dress.raised, Qt.rgba(1, 1, 1, 0.02 + 0.025 * (4 - index)))

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.u
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!chip.spec && chip.spec.label !== ""
                        text: chip.spec ? chip.spec.label.toUpperCase() : ""
                        font.pixelSize: 8.5 * card.u
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1 * card.u
                        color: card.inkOn(chip.color)
                        opacity: 0.85
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * card.u
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!chip.spec
                        text: chip.spec ? String(chip.spec.fill).toUpperCase() : ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9.5 * card.u
                        font.weight: Font.Medium
                        color: card.inkOn(chip.color)
                    }
                }
            }
        }

        // ── Name and details ─────────────────────────────────────────────
        StyledText {
            id: titleText
            x: card.pad + 2 * card.u
            y: chipColumn.y + chipColumn.height + 9 * card.u
            width: thumbBase.width - 4 * card.u
            text: card.title
            elide: Text.ElideRight
            font.pixelSize: 13 * card.u
            font.weight: Font.DemiBold
            color: card.dress.ink
        }

        StyledText {
            id: metaText
            x: titleText.x
            y: titleText.y + titleText.height + 2 * card.u
            width: titleText.width
            text: card.meta
            elide: Text.ElideRight
            font.pixelSize: 10 * card.u
            color: card.dress.muted
        }

        Rectangle {
            anchors.fill: parent
            visible: opacity > 0
            opacity: card.hovered ? 0 : card.dim
            radius: parent.radius
            antialiasing: true
            color: "black"
        }
    }

    // The desktop theme's frame, on the card in front only.
    Loader {
        anchors.fill: parent
        active: card.front > 0.6 && DesktopTheme.enabled
        sourceComponent: PanelDecor {
            radius: card.radius
            title: card.title
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
        onDoubleClicked: card.doubleClicked()
    }

    // The tag pops in when this card is set, not when the deck reaches it.
    Connections {
        target: WallpaperEngine

        function onSerialChanged() {
            Qt.callLater(() => {
                if (card.current && card.front > 0.5)
                    pop.restart();
            });
        }
    }
}
