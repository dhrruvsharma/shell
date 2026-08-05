import QtQuick
import qs.services
import qs.colors

// Waterwheel: a spoked hub with outward-facing bucket chambers.
Item {
    id: root

    property int discRadius: 0
    property int effectiveN: 1

    readonly property bool counterRotateChambers: false
    readonly property real orbitRadius: root.discRadius * 0.62
    readonly property color activeNumberColor: Colors.accent

    Canvas {
        anchors.fill: parent

        readonly property color _text: Colors.text
        on_TextChanged: requestPaint()
        readonly property color _accent: Colors.accent
        on_AccentChanged: requestPaint()
        readonly property int _n: root.effectiveN
        on_NChanged: requestPaint()
        readonly property int _r: root.discRadius
        on_RChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = _r, cy = _r
            var N = _n
            var orbit = root.orbitRadius
            var scale = UIScale.value
            var hubR = Math.round(8 * scale)

            // Outer rim
            ctx.beginPath()
            ctx.arc(cx, cy, _r - Math.round(2 * scale), 0, 2 * Math.PI)
            ctx.strokeStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.22)
            ctx.lineWidth = Math.round(1.5 * scale)
            ctx.stroke()

            // Spokes, hub edge -> orbit
            ctx.strokeStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.36)
            ctx.lineWidth = Math.round(1.5 * scale)
            ctx.lineCap = "round"
            for (var i = 0; i < N; i++) {
                var angle = i * 2 * Math.PI / N
                ctx.beginPath()
                ctx.moveTo(cx + hubR * Math.cos(angle), cy - hubR * Math.sin(angle))
                ctx.lineTo(cx + orbit * Math.cos(angle), cy - orbit * Math.sin(angle))
                ctx.stroke()
            }

            // Hub ring
            ctx.beginPath()
            ctx.arc(cx, cy, hubR, 0, 2 * Math.PI)
            ctx.fillStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.14)
            ctx.fill()
            ctx.strokeStyle = Qt.rgba(_text.r, _text.g, _text.b, 0.28)
            ctx.lineWidth = scale
            ctx.stroke()

            // Axle pin
            ctx.beginPath()
            ctx.arc(cx, cy, Math.round(3.5 * scale), 0, 2 * Math.PI)
            ctx.fillStyle = Qt.rgba(_accent.r, _accent.g, _accent.b, 0.95)
            ctx.fill()
        }
    }

    property Component chamberDelegate: Component {
        Item {
            id: bucket
            property bool isActive: false
            property bool hasWindows: false
            property real chamberAngle: 0

            Canvas {
                anchors.fill: parent

                // 90 - chamberAngle aligns the upward-drawn bucket to face outward
                // in the disc frame, so the whole wheel rotates as one piece.
                rotation: 90 - bucket.chamberAngle

                property bool _isActive: bucket.isActive
                on_IsActiveChanged: requestPaint()
                property bool _hasWindows: bucket.hasWindows
                on_HasWindowsChanged: requestPaint()
                property color _accent: Colors.accent
                on_AccentChanged: requestPaint()
                property color _text: Colors.text
                on_TextChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2, cy = height / 2
                    var H = height

                    var rOut = H * 0.46
                    var rIn = H * 0.25
                    var spread = 0.50 // +-28.6, fits N=6 without overlap

                    ctx.beginPath()
                    ctx.arc(cx, cy, rOut, -Math.PI / 2 - spread, -Math.PI / 2 + spread, false)
                    ctx.arc(cx, cy, rIn, -Math.PI / 2 + spread, -Math.PI / 2 - spread, true)
                    ctx.closePath()

                    var c = (_isActive || _hasWindows) ? _accent : _text
                    var fillAlpha = _isActive ? 0.90 : (_hasWindows ? 0.40 : 0.16)
                    var strokeAlpha = _isActive ? 0.85 : (_hasWindows ? 0.55 : 0.32)

                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, fillAlpha)
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, strokeAlpha)
                    ctx.lineWidth = 1.5 * UIScale.value
                    ctx.lineJoin = "round"
                    ctx.fill()
                    ctx.stroke()
                }
            }
        }
    }
}
