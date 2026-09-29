pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.lock.themes.siege

// Siege clock face: a buckler, its sword the hour hand and its spear the
// minutes, the quarter of the dial the watch is in lit by firelight;
// beside it the hour, the watch of the siege and what the garrison is
// about, the date, and the day of the siege in the year of Our Lord, over
// a drift of smoke so they read on a pale sky too. The face keeps room
// round the words for the smoke to thin out in: a widget's surface ends at
// its bounds, and the drift would stop there in a hard edge.
Item {
    id: root

    property date now: new Date()
    readonly property var watch: War.watch(now)
    readonly property real drift: 44

    implicitWidth: body.implicitWidth + 3 * drift
    implicitHeight: body.implicitHeight + 2 * drift

    Row {
        id: body
        x: root.drift
        y: root.drift
        spacing: 26

        Buckler {
            anchors.verticalCenter: parent.verticalCenter
            width: 222
            height: 222
            hour: root.now.getHours()
            minute: root.now.getMinutes()
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: words.implicitWidth
            height: words.implicitHeight

            // The smoke: a dark drift thinning out to nothing, an ellipse
            // round the words.
            Shape {
                id: smoke
                readonly property real r: words.width / 2 + 2 * root.drift
                x: words.width / 2 - r
                y: words.height / 2 - r
                width: 2 * r
                height: 2 * r
                transform: Scale {
                    origin.x: smoke.r
                    origin.y: smoke.r
                    yScale: (words.height + 2 * root.drift) / (2 * smoke.r)
                }
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: smoke.r
                        centerY: smoke.r
                        centerRadius: smoke.r
                        focalX: smoke.r
                        focalY: smoke.r
                        GradientStop { position: 0; color: War.alpha("black", 0.58) }
                        GradientStop { position: 0.62; color: War.alpha("black", 0.46) }
                        GradientStop { position: 1; color: "transparent" }
                    }

                    PathAngleArc {
                        centerX: smoke.r
                        centerY: smoke.r
                        radiusX: smoke.r
                        radiusY: smoke.r
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            Column {
                id: words
                spacing: 2

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
                        font.family: War.display
                        font.pixelSize: 86
                        color: War.ivory
                    }

                    Text {
                        anchors.baseline: time.baseline
                        text: root.now.getHours() < 12 ? "a.m." : "p.m."
                        font.family: War.display
                        font.pixelSize: 28
                        color: War.tinctureLight
                    }
                }

                Text {
                    text: root.watch.name + "  ·  " + root.watch.deed
                    font.family: War.book
                    font.italic: true
                    font.pixelSize: 21
                    color: War.tinctureLight
                }

                Text {
                    topPadding: 2
                    text: War.date(root.now)
                    font.family: War.book
                    font.pixelSize: 18
                    color: War.ivory
                }

                Text {
                    topPadding: 5
                    text: ("Day " + War.siegeDay(root.now) + " of the siege  ·  " + War.year(root.now)).toUpperCase()
                    font.family: War.display
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: War.alpha(War.ivory, 0.78)
                }
            }
        }
    }
}
