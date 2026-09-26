pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.lock

// The sealing formation: a luopan-like outer ring of ticks, the eight
// trigrams, the opening of the Thousand Character Classic, and twelve seal
// slots whose runes light up one per typed character. Rings turn with
// `spin` (advanced by the surface from the ambient clock), sweep in with
// `draw`, flush cinnabar with `alarm` and blaze gold with `surge`.
Item {
    id: f

    required property LockContext ctx
    property real sc: 1
    property real draw: 1
    property real spin: 0
    property real alarm: 0
    property real surge: 0
    // Fades the centre clock while a seal or an omen is shown over it.
    property real hush: 0

    readonly property real rad: 250 * sc
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property color line: Qt.tint(Qt.tint(Xian.gold, Xian.alpha(Xian.cinnabar, alarm)), Xian.alpha(Xian.goldHi, surge))
    readonly property real fadeIn: LockTheme.seg(draw, 0.35, 1)
    readonly property string trigrams: "☰☱☲☳☴☵☶☷"
    readonly property string classic: "天地玄黄宇宙洪荒日月盈昃辰宿列张寒来暑往秋收冬藏"
    readonly property string runes: "敕令雷火风山泽水天地日月"
    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"

    width: 2 * rad + 80 * sc
    height: width

    // Soft glow pooling in the centre, stronger as the seal fills.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.55 * f.fadeIn

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: f.cx
                centerY: f.cy
                centerRadius: f.rad * 0.95
                focalX: f.cx
                focalY: f.cy
                GradientStop { position: 0; color: Xian.alpha(f.alarm > 0.5 ? Xian.cinnabar : Xian.gold, 0.12 + 0.3 * f.surge + 0.012 * Math.min(f.ctx.cells, 12)) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc {
                centerX: f.cx
                centerY: f.cy
                radiusX: f.rad * 0.95
                radiusY: f.rad * 0.95
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // ── Outer ring and ticks ─────────────────────────────────────────
    Item {
        anchors.fill: parent
        rotation: f.spin

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: f.line
                strokeWidth: 1.6 * f.sc
                PathAngleArc {
                    centerX: f.cx
                    centerY: f.cy
                    radiusX: f.rad
                    radiusY: f.rad
                    startAngle: -90
                    sweepAngle: 360 * f.draw
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Xian.alpha(f.line, 0.55)
                strokeWidth: 1 * f.sc
                PathAngleArc {
                    centerX: f.cx
                    centerY: f.cy
                    radiusX: f.rad + 9 * f.sc
                    radiusY: f.rad + 9 * f.sc
                    startAngle: 90
                    sweepAngle: 360 * f.draw
                }
            }
        }

        Repeater {
            model: 72

            Item {
                id: tick
                required property int index
                anchors.fill: parent
                rotation: index * 5
                opacity: f.fadeIn

                Rectangle {
                    x: f.cx - width / 2
                    y: f.cy - f.rad
                    width: (tick.index % 3 === 0 ? 2 : 1) * f.sc
                    height: (tick.index % 3 === 0 ? 16 : 8) * f.sc
                    color: f.line
                }
            }
        }
    }

    // ── Trigrams (counter-rotating) ──────────────────────────────────
    Item {
        anchors.fill: parent
        rotation: -f.spin * 0.6
        opacity: f.fadeIn

        Repeater {
            model: 8

            Item {
                id: tri
                required property int index
                anchors.fill: parent
                rotation: index * 45

                Text {
                    x: f.cx - width / 2
                    y: f.cy - f.rad * 0.86 - height / 2
                    text: f.trigrams.charAt(tri.index)
                    font.family: Xian.cjk
                    font.pixelSize: 30 * f.sc
                    color: f.line
                }
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Xian.alpha(f.line, 0.7)
                strokeWidth: 1 * f.sc
                PathAngleArc {
                    centerX: f.cx
                    centerY: f.cy
                    radiusX: f.rad * 0.76
                    radiusY: f.rad * 0.76
                    startAngle: 0
                    sweepAngle: 360 * f.draw
                }
            }
        }
    }

    // ── The Thousand Character Classic ───────────────────────────────
    Item {
        anchors.fill: parent
        rotation: f.spin * 0.35
        opacity: f.fadeIn

        Repeater {
            model: 24

            Item {
                id: glyph
                required property int index
                anchors.fill: parent
                rotation: index * 15

                Text {
                    x: f.cx - width / 2
                    y: f.cy - f.rad * 0.67 - height / 2
                    text: f.classic.charAt(glyph.index)
                    font.family: Xian.cjk
                    font.weight: Font.Medium
                    font.pixelSize: 19 * f.sc
                    color: Xian.alpha(f.alarm > 0.3 ? Xian.cinnabar : Xian.paper, 0.62)
                }
            }
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Xian.alpha(f.line, 0.8)
                strokeWidth: 1.2 * f.sc
                PathAngleArc {
                    centerX: f.cx
                    centerY: f.cy
                    radiusX: f.rad * 0.58
                    radiusY: f.rad * 0.58
                    startAngle: 180
                    sweepAngle: 360 * f.draw
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Xian.alpha(f.line, 0.45)
                strokeWidth: 1 * f.sc
                PathAngleArc {
                    centerX: f.cx
                    centerY: f.cy
                    radiusX: f.rad * 0.555
                    radiusY: f.rad * 0.555
                    startAngle: 180
                    sweepAngle: 360 * f.draw
                }
            }
        }
    }

    // ── Seal slots: one rune per typed character ─────────────────────
    Repeater {
        model: 12

        Item {
            id: slot

            required property int index
            readonly property bool lit: f.granted || index < f.ctx.cells
            readonly property real pulse: f.ctx.phase === "verifying"
                ? 0.55 + 0.45 * Math.abs(Math.sin(f.spin * 0.04 + index * 0.52)) : 1
            property real glow: 0

            anchors.fill: parent
            rotation: index * 30
            opacity: f.fadeIn

            onLitChanged: {
                if (lit)
                    ignite.restart();
                else
                    glow = 0;
            }

            NumberAnimation {
                id: ignite
                target: slot
                property: "glow"
                from: 1.8
                to: 1
                duration: 320
                easing.type: Easing.OutCubic
            }

            Item {
                x: f.cx - width / 2
                y: f.cy - f.rad * 0.43 - height / 2
                width: 34 * f.sc
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (slot.lit ? slot.glow : 1)
                    height: width
                    radius: width / 2
                    color: slot.lit ? Xian.alpha(f.ctx.denying ? Xian.cinnabar : Xian.gold, 0.2 * slot.pulse) : "transparent"
                    border.width: 1 * f.sc
                    border.color: Xian.alpha(f.line, slot.lit ? 0.9 : 0.35)
                }

                Text {
                    anchors.centerIn: parent
                    visible: slot.lit
                    text: f.runes.charAt(slot.index)
                    font.family: Xian.cjk
                    font.weight: Font.Black
                    font.pixelSize: 17 * f.sc
                    color: f.ctx.denying ? Xian.cinnabar : Xian.goldHi
                    opacity: slot.pulse
                }
            }
        }
    }

    // ── Inner ring and the hour ──────────────────────────────────────
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Xian.alpha(Xian.ink, 0.35)
            strokeColor: Xian.alpha(f.line, 0.85)
            strokeWidth: 1.4 * f.sc
            PathAngleArc {
                centerX: f.cx
                centerY: f.cy
                radiusX: f.rad * 0.31
                radiusY: f.rad * 0.31
                startAngle: -90
                sweepAngle: 360 * f.draw
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        opacity: f.fadeIn * (1 - f.hush)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(f.ctx.now, "hh:mm")
            font.family: Xian.serif
            font.weight: Font.Light
            font.pixelSize: 50 * f.sc
            color: Xian.paper
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Xian.shichen(f.ctx.now).zh
            font.family: Xian.cjk
            font.weight: Font.Medium
            font.pixelSize: 15 * f.sc
            font.letterSpacing: 4 * f.sc
            color: Xian.gold
        }
    }
}
