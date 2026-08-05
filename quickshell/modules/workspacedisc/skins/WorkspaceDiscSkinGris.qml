import QtQuick
import qs.services
import qs.colors

// Gris: an angular, faceted gear with square chambers and a target hub.
Item {
    id: root

    property int discRadius: 0
    property int effectiveN: 1

    readonly property real _gearScale: 0.84

    readonly property real orbitRadius: root.discRadius * root._gearScale
    readonly property bool counterRotateChambers: false

    property Component chamberDelegate: Component {
        Item {
            id: chamber
            property bool isActive: false
            property bool hasWindows: false
            property real chamberAngle: 0
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.78
                height: parent.height * 0.78
                rotation: 0 - chamber.chamberAngle
                radius: 2
                color: chamber.isActive ? Colors.accent : (chamber.hasWindows ? Colors.withAlpha(Colors.accent, 0.35) : Colors.withAlpha(Colors.surface, 0.75))
                border.color: chamber.isActive ? Colors.withAlpha(Colors.onAccent, 0.6) : Colors.withAlpha(Colors.text, 0.28)
                border.width: 1.5
                Behavior on color { ColorAnimation { duration: Anim.fast } }
            }
        }
    }

    Canvas {
        anchors.fill: parent
        rotation: (WorkspaceDiscService.toothWidth / 200) * (360 / root.effectiveN)

        readonly property color _text: Colors.text
        on_TextChanged: requestPaint()
        readonly property int _n: root.effectiveN
        on_NChanged: requestPaint()
        readonly property int _r: root.discRadius
        on_RChanged: requestPaint()
        readonly property int _toothWidth: WorkspaceDiscService.toothWidth
        on_ToothWidthChanged: requestPaint()
        readonly property int _valleyDepth: WorkspaceDiscService.valleyDepth
        on_ValleyDepthChanged: requestPaint()
        readonly property real _gearScale: root._gearScale

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var W = _toothWidth / 100
            var D = _valleyDepth / 100
            var N = _n
            var rOut = _r * _gearScale
            var rIn = rOut * (1 - D)
            var cx = _r
            var cy = _r

            var angPerTooth = 2 * Math.PI / N
            var wAngle = W * angPerTooth
            var vAngle = (W + 1) / 2 * angPerTooth

            ctx.beginPath()
            for (var tooth = 0; tooth < N; tooth++) {
                var base = -tooth * angPerTooth
                var p0x = cx + rOut * Math.cos(base)
                var p0y = cy + rOut * Math.sin(base)
                var p1x = cx + rOut * Math.cos(base - wAngle)
                var p1y = cy + rOut * Math.sin(base - wAngle)
                var p2x = cx + rIn * Math.cos(base - vAngle)
                var p2y = cy + rIn * Math.sin(base - vAngle)
                if (tooth === 0) ctx.moveTo(p0x, p0y)
                else ctx.lineTo(p0x, p0y)
                ctx.lineTo(p1x, p1y)
                ctx.lineTo(p2x, p2y)
            }
            ctx.closePath()

            ctx.strokeStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.52)
            ctx.lineWidth = 1.5 * UIScale.value
            ctx.lineJoin = "miter"
            ctx.stroke()

            // Orbit ring outside the gear body
            ctx.lineWidth = 1
            ctx.strokeStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.18)
            ctx.beginPath()
            ctx.arc(cx, cy, _r - 3, 0, 2 * Math.PI)
            ctx.stroke()
        }
    }

    Canvas {
        readonly property real _sz: Math.round(32 * UIScale.value)
        width: _sz
        height: _sz
        anchors.centerIn: parent

        property color _ink: Colors.text
        on_InkChanged: requestPaint()
        property color _acc: Colors.accent
        on_AccChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            ctx.strokeStyle = Qt.rgba(_ink.r, _ink.g, _ink.b, 0.40)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(cx, cy, cx * 0.88, 0, 2 * Math.PI)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(cx, cy, cx * 0.55, 0, 2 * Math.PI)
            ctx.stroke()
            ctx.fillStyle = Qt.rgba(_acc.r, _acc.g, _acc.b, 0.9)
            ctx.beginPath()
            ctx.arc(cx, cy, cx * 0.22, 0, 2 * Math.PI)
            ctx.fill()
        }
    }
}
