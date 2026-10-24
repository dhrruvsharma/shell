pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.modules.lock.themes.sekiro

// Sekiro clock face: the hour in an antique Mincho, and under it the
// posture gauge of the hour, filling from the middle out as the minutes
// run (gold, then orange as the hour nears its end: at the top of the
// hour its posture breaks and it starts again); the area of Ashina the
// shinobi is in at this hour with the Sculptor's Idol he rests at, what's
// happening there, and the date with the season. Beside it the season's
// character, brushed in crimson. A drift of dark mist behind the words
// keeps them legible on a pale sky; the face keeps room round them for it
// to thin out in, since a widget's surface ends at its bounds.
Item {
    id: root

    property date now: new Date()
    readonly property var stretch: Shinobi.stretch(now)
    readonly property var season: Shinobi.season(now)
    readonly property real drift: 40

    implicitWidth: body.implicitWidth + 2.5 * drift
    implicitHeight: body.implicitHeight + 2 * drift

    Row {
        id: body
        x: root.drift
        y: root.drift
        spacing: 8

        BrushKanji {
            anchors.verticalCenter: parent.verticalCenter
            text: root.season.kanji
            vertical: true
            size: root.season.kanji.length > 1 ? 96 : 150
            ink: Shinobi.alpha(Shinobi.kanji, 0.94)
            seed: root.now.getMonth() + 1
            dry: 0.55

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
                shadowBlur: 0.6
                blurMax: 20
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 3
            }
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: words.implicitWidth
            height: words.implicitHeight

            // The mist: dark, thinning out to nothing, an ellipse round the
            // words.
            Shape {
                id: mist
                readonly property real r: words.width / 2 + 2 * root.drift
                x: words.width / 2 - r
                y: words.height / 2 - r
                width: 2 * r
                height: 2 * r
                transform: Scale {
                    origin.x: mist.r
                    origin.y: mist.r
                    yScale: (words.height + 2 * root.drift) / (2 * mist.r)
                }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: mist.r
                        centerY: mist.r
                        centerRadius: mist.r
                        focalX: mist.r
                        focalY: mist.r
                        GradientStop { position: 0; color: Shinobi.alpha("#07080c", 0.6) }
                        GradientStop { position: 0.6; color: Shinobi.alpha("#07080c", 0.46) }
                        GradientStop { position: 1; color: "transparent" }
                    }

                    PathAngleArc {
                        centerX: mist.r
                        centerY: mist.r
                        radiusX: mist.r
                        radiusY: mist.r
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            Column {
                id: words
                spacing: 4

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.9
                    shadowBlur: 0.5
                    blurMax: 16
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 2
                }

                Row {
                    spacing: 12

                    Text {
                        id: time
                        text: Qt.formatTime(root.now, "h:mm AP").split(" ")[0]
                        font.family: Shinobi.display
                        font.pixelSize: 92
                        color: Shinobi.ivory
                    }

                    Text {
                        anchors.baseline: time.baseline
                        text: root.now.getHours() < 12 ? "a.m." : "p.m."
                        font.family: Shinobi.book
                        font.pixelSize: 26
                        color: Shinobi.landLight
                    }
                }

                // The posture of the hour.
                PostureGauge {
                    width: Math.max(words.width, 380)
                    height: 15
                    value: root.now.getMinutes() / 60
                    lineWidth: 1.2
                    gold: Shinobi.postureGold
                    orange: Shinobi.postureOrange
                    red: Shinobi.postureRed
                }

                Text {
                    topPadding: 4
                    text: Shinobi.place(root.stretch)
                    font.family: Shinobi.book
                    font.weight: Font.Bold
                    font.pixelSize: 21
                    color: Shinobi.landLight
                }

                Text {
                    text: root.stretch.deed
                    font.family: Shinobi.book
                    font.pixelSize: 17
                    color: Shinobi.alpha(Shinobi.ivory, 0.86)
                }

                Text {
                    topPadding: 4
                    text: (Shinobi.date(root.now) + "  ·  " + root.season.name).toUpperCase()
                    font.family: Shinobi.book
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: Shinobi.alpha(Shinobi.ivory, 0.7)
                }
            }
        }
    }
}
