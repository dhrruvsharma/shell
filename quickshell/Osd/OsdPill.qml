pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.services as Services

// The OSD itself. It drops in as a bead holding the sign, opens out into a
// pill to show the meter and the number, and folds back into the bead and
// away when it hides. Each kind has a face of its own (the volume's speaker
// and waveform, the brightness's sun and daylight); switching between them
// while it's up cross-fades the faces in the open pill. `shown` drives the
// opening; `pulse`, bumped by every step, sets off the sign's flare and the
// meter's wavefront or glint. The desktop theme gives it its corners, frame,
// type and colours.
Item {
    id: osd

    property bool shown: false
    property string kind: "volume"
    // Percent; the volume can run past 100 (wpctl allows it).
    property real volume: 0
    property bool muted: false
    property string device: ""
    property string deviceIcon: ""
    property real brightness: 0
    property int pulse: 0

    // 0 → gone, 1 → the bead is in.
    property real pop: 0
    // 0 → a bead, 1 → open.
    property real grow: 0
    // 0 → the meters start from nothing (a fresh show), 1 → at the level.
    property real sweep: 1
    // 1 at a step, falling back to 0.
    property real kick: 0

    readonly property int pillHeight: 70
    readonly property int pillWidth: 376
    readonly property var look: Services.DesktopTheme.look
    readonly property bool squareCaps: Services.DesktopTheme.squareShapes.includes(look.shape)
    readonly property real radius: Services.DesktopTheme.panelRadius(pillHeight / 2)
    readonly property color ground: Colors.surface_container_high
    readonly property int caps: look.caps === true ? Font.AllUppercase : look.caps === "small" ? Font.SmallCaps : Font.MixedCase
    // A saturated warning colour for the boost (the scheme's error is a
    // pastel that can sit right next to the accents).
    readonly property color hot: Qt.hsla(Math.max(0, Qt.color(Colors.error).hslHue), 0.92, Qt.color(Colors.background).hslLightness < 0.5 ? 0.62 : 0.45, 1)
    readonly property bool open: grow > 0.9

    // The levels the faces draw: eased, and swept up on a fresh show.
    property real volumeEased: volume
    property real brightnessEased: brightness

    Behavior on volumeEased {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    Behavior on brightnessEased {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    implicitWidth: pillWidth
    implicitHeight: pillHeight

    onShownChanged: {
        if (shown) {
            outro.stop();
            const fresh = pop === 0;
            if (fresh)
                sweep = 0;
            intro.popTime = fresh ? 220 : Math.round(160 * (1 - Math.min(1, pop)));
            intro.lag = fresh ? 80 : 0;
            intro.restart();
        } else {
            intro.stop();
            outro.restart();
        }
    }

    onPulseChanged: {
        if (!open)
            return;
        flare.restart();
        if (kind === "volume")
            waveMeter.emit();
        else
            daylight.emit();
    }

    SequentialAnimation {
        id: intro

        property int popTime: 220
        property int lag: 80

        ParallelAnimation {
            NumberAnimation { target: osd; property: "pop"; to: 1; duration: intro.popTime; easing.type: Easing.OutBack; easing.overshoot: 2.4 }

            SequentialAnimation {
                PauseAnimation { duration: intro.lag }
                NumberAnimation { target: osd; property: "grow"; to: 1; duration: 460; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: intro.lag + 90 }
                NumberAnimation { target: osd; property: "sweep"; to: 1; duration: 620; easing.type: Easing.OutCubic }
            }
        }
    }

    SequentialAnimation {
        id: outro

        NumberAnimation { target: osd; property: "grow"; to: 0; duration: 250; easing.type: Easing.InCubic }
        NumberAnimation { target: osd; property: "pop"; to: 0; duration: 180; easing.type: Easing.InBack; easing.overshoot: 2.4 }
    }

    NumberAnimation { id: flare; target: osd; property: "kick"; from: 1; to: 0; duration: 560; easing.type: Easing.OutCubic }

    RectangularShadow {
        anchors.fill: body
        scale: body.scale
        radius: body.radius
        blur: 26
        offset.y: 7
        color: Qt.rgba(0, 0, 0, 0.42)
        opacity: body.opacity
    }

    Rectangle {
        id: body

        x: (osd.width - width) / 2
        y: (osd.height - height) / 2
        width: osd.pillHeight + (osd.pillWidth - osd.pillHeight) * osd.grow
        height: osd.pillHeight
        scale: 0.45 + 0.55 * osd.pop
        opacity: Math.max(0, Math.min(1, osd.pop * 1.8))
        radius: osd.radius
        topLeftRadius: Services.DesktopTheme.corner(osd.look, radius, 0)
        topRightRadius: Services.DesktopTheme.corner(osd.look, radius, 1)
        bottomRightRadius: Services.DesktopTheme.corner(osd.look, radius, 2)
        bottomLeftRadius: Services.DesktopTheme.corner(osd.look, radius, 3)
        color: osd.ground
        border.width: 1
        border.color: Services.DesktopTheme.enabled && osd.look.border
            ? Services.DesktopTheme.borderColor(osd.look)
            : Colors.withAlpha(Colors.outline_variant, 0.8)

        // The sun lights the pill round it, more as the level rises: a glow
        // filling the pill's own outline, so it keeps to the corners.
        Shape {
            id: wash

            readonly property real rad: osd.pillWidth * 0.66

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: brightnessFace.opacity * Math.pow(Math.min(1, brightnessFace.level), 1.5) * (0.85 + 0.15 * osd.kick)
            visible: opacity > 0.01

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: osd.pillHeight / 2
                    centerY: osd.pillHeight / 2
                    centerRadius: wash.rad
                    focalX: osd.pillHeight / 2
                    focalY: osd.pillHeight / 2

                    GradientStop { position: 0; color: Colors.withAlpha(Services.DesktopTheme.accent, 0.22) }
                    GradientStop { position: 0.45; color: Colors.withAlpha(Services.DesktopTheme.accent, 0.07) }
                    GradientStop { position: 1; color: Colors.withAlpha(Services.DesktopTheme.accent, 0) }
                }

                PathRectangle {
                    width: body.width
                    height: body.height
                    topLeftRadius: body.topLeftRadius
                    topRightRadius: body.topRightRadius
                    bottomRightRadius: body.bottomRightRadius
                    bottomLeftRadius: body.bottomLeftRadius
                }
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            // ── Volume ───────────────────────────────────────────────────
            Item {
                id: volumeFace

                readonly property real level: osd.volumeEased * osd.sweep / 100

                anchors.fill: parent
                opacity: osd.kind === "volume" ? 1 : 0
                visible: opacity > 0

                // Cross-fades only in a pill that's up; a fresh one
                // starts with the right face.
                Behavior on opacity {
                    enabled: osd.pop > 0
                    NumberAnimation { duration: 180 }
                }

                SpeakerGlyph {
                    id: speaker

                    x: (osd.pillHeight - width) / 2
                    y: (osd.pillHeight - height) / 2
                    width: 44
                    height: 44
                    level: Math.min(1, volumeFace.level)
                    muted: osd.muted
                    color: osd.muted ? Colors.outline : Services.DesktopTheme.accent
                    squareCaps: osd.squareCaps
                    scale: 1 + 0.07 * osd.kick
                }

                Item {
                    anchors.fill: parent
                    opacity: Math.max(0, Math.min(1, (osd.grow - 0.4) / 0.45))
                    visible: opacity > 0

                    Row {
                        x: osd.pillHeight
                        y: 13
                        spacing: 5

                        MaterialIcon {
                            visible: text !== "" && !osd.muted
                            text: osd.deviceIcon
                            font.pixelSize: 13
                            color: Colors.on_surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            width: Math.min(implicitWidth, waveMeter.width - 18)
                            text: osd.muted ? "Muted" : osd.device
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            font.capitalization: osd.caps
                            font.letterSpacing: 0.3
                            color: Colors.on_surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    WaveMeter {
                        id: waveMeter

                        x: osd.pillHeight
                        y: osd.pillHeight - 10 - height
                        width: osd.pillWidth - osd.pillHeight - 96
                        height: 28
                        level: Math.min(1, volumeFace.level)
                        boost: Math.max(0, volumeFace.level - 1)
                        muted: osd.muted
                        hot: osd.hot
                        squareCaps: osd.squareCaps
                        origin: speaker.x + speaker.mouthX - x
                    }

                    Readout {
                        value: volumeFace.level * 100
                        dim: osd.muted
                        hot: volumeFace.level > 1.005
                    }
                }
            }

            // ── Brightness ───────────────────────────────────────────────
            Item {
                id: brightnessFace

                readonly property real level: osd.brightnessEased * osd.sweep / 100

                anchors.fill: parent
                opacity: osd.kind === "brightness" ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: osd.pop > 0
                    NumberAnimation { duration: 180 }
                }

                SunGlyph {
                    x: (osd.pillHeight - width) / 2
                    y: (osd.pillHeight - height) / 2
                    width: 44
                    height: 44
                    level: Math.min(1, brightnessFace.level)
                    kick: osd.kick
                    ground: osd.ground
                    squareCaps: osd.squareCaps
                }

                Item {
                    anchors.fill: parent
                    opacity: Math.max(0, Math.min(1, (osd.grow - 0.4) / 0.45))
                    visible: opacity > 0

                    StyledText {
                        x: osd.pillHeight
                        y: 13
                        text: "Brightness"
                        font.pixelSize: 12
                        font.capitalization: osd.caps
                        font.letterSpacing: 0.3
                        color: Colors.on_surface_variant
                    }

                    DaylightMeter {
                        id: daylight

                        x: osd.pillHeight
                        y: osd.pillHeight - 10 - 14 - height / 2
                        width: osd.pillWidth - osd.pillHeight - 96
                        height: 14
                        level: Math.min(1, brightnessFace.level)
                        squareCaps: osd.squareCaps
                    }

                    Readout {
                        value: brightnessFace.level * 100
                    }
                }
            }
        }

        PanelDecor {
            radius: body.radius
            topLeftRadius: body.topLeftRadius
            topRightRadius: body.topRightRadius
            bottomRightRadius: body.bottomRightRadius
            bottomLeftRadius: body.bottomLeftRadius
        }
    }

    // The number at the open pill's far end, its % set small. It keeps its
    // place while the pill opens and folds (the edge uncovers it), rather
    // than riding the edge over the meter.
    component Readout: Row {
        id: readout

        property real value: 0
        property bool dim: false
        property bool hot: false

        x: osd.pillWidth - 18 - width
        y: (osd.pillHeight - height) / 2 + 1

        StyledText {
            id: digits

            text: Math.round(readout.value)
            font.pixelSize: 26
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: readout.hot ? osd.hot : readout.dim ? Colors.outline : Colors.on_surface
        }

        StyledText {
            anchors.baseline: digits.baseline
            text: "%"
            font.pixelSize: 13
            font.weight: Font.Medium
            color: readout.hot ? osd.hot : Colors.on_surface_variant
        }
    }
}
