pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.lock

// The passcode as a constellation: each typed character ignites a star on a
// gently winding path, joined to the previous one by a faint line. Verifying
// sends a pulse of light along it, a wrong password makes the stars fall like
// meteors (`fall`), a right one makes them flare (`flare`).
Item {
    id: con

    required property LockContext ctx
    property real sc: 1
    property color tint: "white"
    property color alarm: "#ff8a80"
    property real fall: 0
    property real flare: 0
    property real pulse: 0

    readonly property int maxStars: 24
    readonly property int count: Math.min(ctx.cells, maxStars)
    readonly property real stepX: Math.min(48 * sc, (width - 40 * sc) / Math.max(1, count))
    readonly property color tone: ctx.denying ? alarm : tint

    function pos(i) {
        const n = Math.max(1, count);
        return Qt.point(width / 2 + (i - (n - 1) / 2) * stepX,
                        height / 2 + Math.sin(i * 1.9 + 0.6) * 15 * sc + (i % 3 === 0 ? -9 : 5) * sc);
    }

    Shape {
        anchors.fill: parent
        opacity: (1 - con.fall) * (0.4 + 0.4 * con.flare)
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: con.tone
            strokeWidth: 1 * con.sc
            PathPolyline {
                path: {
                    const pts = [];
                    for (let i = 0; i < con.count; i++)
                        pts.push(con.pos(i));
                    return pts;
                }
            }
        }
    }

    Repeater {
        model: con.maxStars

        Item {
            id: star

            required property int index
            readonly property bool active: index < con.count
            readonly property point at: con.pos(index)
            // A bump of light travelling along the constellation while verifying.
            readonly property real lit: con.ctx.phase === "verifying"
                ? Math.max(0, 1 - Math.abs(con.pulse * (con.count + 3) - 1.5 - index) / 1.5) : 0
            readonly property real drift: ((index * 53) % 41 - 20) * con.sc
            readonly property real drop: (90 + (index * 37) % 70) * con.sc

            width: 30 * con.sc
            height: width
            x: at.x - width / 2 + con.fall * drift
            y: at.y - height / 2 + con.fall * con.fall * drop
            rotation: con.fall * (index % 2 ? 40 : -40)
            opacity: 1 - con.fall
            scale: 0
            visible: scale > 0.01

            Behavior on x {
                enabled: star.active && con.fall === 0
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            onActiveChanged: {
                if (active) {
                    fade.stop();
                    ignite.restart();
                } else {
                    ignite.stop();
                    fade.restart();
                }
            }

            NumberAnimation {
                id: ignite
                target: star
                property: "scale"
                from: 2.2
                to: 1
                duration: 360
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: fade
                target: star
                property: "scale"
                to: 0
                duration: 180
            }

            // Glow, four-point sparkle and core.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (0.6 + 0.5 * con.flare + 0.4 * star.lit)
                height: width
                radius: width / 2
                color: Qt.rgba(con.tone.r, con.tone.g, con.tone.b, 0.16 + 0.2 * star.lit + 0.2 * con.flare)
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (1 + con.flare)
                height: 1.4 * con.sc
                color: Qt.rgba(con.tone.r, con.tone.g, con.tone.b, 0.7)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 1.4 * con.sc
                height: parent.height * (1 + con.flare)
                color: Qt.rgba(con.tone.r, con.tone.g, con.tone.b, 0.7)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 5 * con.sc
                height: width
                radius: width / 2
                color: "white"
            }
        }
    }
}
