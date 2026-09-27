pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.desktoptheme
import qs.modules.lock

// Astral clock face: the minutes trace an orbit, the hour is a planet on the
// inner ring, and the year's progress around the sun sits underneath.
Item {
    id: root

    property date now: new Date()
    readonly property color accent: Colors.primary
    readonly property color accent2: Colors.tertiary
    readonly property real minutes: now.getMinutes()
    readonly property real hours: now.getHours() % 12 + minutes / 60
    readonly property real outer: 104
    readonly property real inner: 76

    implicitWidth: Math.max(orbit.width, year.implicitWidth)
    implicitHeight: orbit.height + 14 + year.implicitHeight

    Item {
        id: orbit

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.outer * 2 + 16
        height: width

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.accent
            shadowOpacity: 0.45
            shadowBlur: 0.6
            blurMax: 24
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: LockTheme.alpha(Colors.on_surface, 0.2)
                strokeWidth: 1
                PathAngleArc {
                    centerX: orbit.width / 2
                    centerY: orbit.height / 2
                    radiusX: root.outer
                    radiusY: root.outer
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: LockTheme.alpha(Colors.on_surface, 0.12)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 5]
                PathAngleArc {
                    centerX: orbit.width / 2
                    centerY: orbit.height / 2
                    radiusX: root.inner
                    radiusY: root.inner
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.accent
                strokeWidth: 2.5
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: orbit.width / 2
                    centerY: orbit.height / 2
                    radiusX: root.outer
                    radiusY: root.outer
                    startAngle: -90
                    sweepAngle: Math.max(0.5, root.minutes / 60 * 360)
                }
            }
        }

        component Body: Rectangle {
            property real angle
            property real ring
            width: 10
            height: width
            radius: width / 2
            x: orbit.width / 2 + Math.sin(angle * Math.PI / 180) * ring - width / 2
            y: orbit.height / 2 - Math.cos(angle * Math.PI / 180) * ring - height / 2
        }

        Body {
            angle: root.minutes / 60 * 360
            ring: root.outer
            width: 9
            color: root.accent
        }

        Body {
            angle: root.hours / 12 * 360
            ring: root.inner
            width: 13
            color: root.accent2
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "hh:mm")
                font.family: "ESPACION"
                font.pixelSize: 34
                color: Colors.on_surface
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "AP · ddd d MMM").toUpperCase()
                font.family: "Adwaita Sans"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 2.5
                color: LockTheme.alpha(Colors.on_surface, 0.72)
            }
        }
    }

    Text {
        id: year
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: "YEAR " + root.now.getFullYear() + "  ·  " + Math.round(Clocks.yearFraction(root.now) * 100) + "% AROUND THE SUN"
        font.family: "Adwaita Sans"
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 3
        color: LockTheme.alpha(Colors.on_surface, 0.6)
    }
}
