pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components

// The border round a plate's figure, in the theme's manner: an engraver's
// double rule, HUD brackets, a console box, a gilt stepped frame, a cusped
// one, battlements, a neon tube with a corner cut, rivets, temple borders,
// a graduated brass rim, tape, a gold hairline with chevrons… Only the
// theme's own is built. It never takes input.
Item {
    id: frame

    readonly property color stroke: BookStyle.accent
    readonly property color hair: BookStyle.line

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            hud: hudX,
            terminal: consoleX,
            cosmos: glassX,
            zen: bareX,
            xianxia: sealX,
            cyberpunk: neonX,
            wabisabi: washiX,
            artdeco: decoX,
            gothic: cuspX,
            newspaper: pressX,
            wasteland: tapeX,
            observatory: brassX,
            abyss: rivetX,
            devaloka: templeX,
            siege: crenelX,
            sekiro: sumiX
        })[BookStyle.themeId] ?? ruleX
    }

    // An engraver's plate: a fine line, and a heavier one just inside it.
    Component {
        id: ruleX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: frame.hair
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: "transparent"
                border.width: 1.5
                border.color: Colors.withAlpha(BookStyle.ink, 0.5)
            }
        }
    }

    Component {
        id: hudX

        HudFrame {
            fill: "transparent"
            stroke: Colors.withAlpha(frame.stroke, 0.55)
            tickColor: frame.stroke
            cut: 14
        }
    }

    Component {
        id: consoleX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.ink, 0.45)
            }
            Rectangle {
                x: 14
                y: -8
                width: tab.implicitWidth + 12
                height: 16
                color: BookStyle.paper

                BookText {
                    id: tab
                    anchors.centerIn: parent
                    text: "[ figure ]"
                    font.pixelSize: 11
                    color: frame.stroke
                }
            }
        }
    }

    Component {
        id: glassX

        Item {
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(frame.stroke, 0.5)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 17
                color: "transparent"
                border.width: 3
                border.color: Colors.withAlpha(frame.stroke, 0.08)
            }
        }
    }

    Component {
        id: bareX

        Item {}
    }

    // Cave Abode: a double border and the seal in its corner.
    Component {
        id: sealX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.ink, 0.55)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.ink, 0.3)
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                width: 34
                height: 34
                radius: 3
                color: Colors.withAlpha("#b3261e", 0.85)
                rotation: -4

                BookText {
                    anchors.centerIn: parent
                    text: "印"
                    font.family: BookStyle.cjk
                    font.pixelSize: 21
                    color: "#f6e9dc"
                }
            }
        }
    }

    Component {
        id: neonX

        NeonFrame {
            fill: "transparent"
            cut: 18
            stroke: frame.stroke
            edge: BookStyle.accent2
        }
    }

    // Wabi-sabi: a quiet ink line, no two corners alike.
    Component {
        id: washiX

        Rectangle {
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(BookStyle.ink, 0.4)
            topLeftRadius: 9
            topRightRadius: 3
            bottomRightRadius: 11
            bottomLeftRadius: 5
        }
    }

    Component {
        id: decoX

        DecoFrame {
            fill: "transparent"
            stroke: frame.stroke
            cut: 10
            steps: 2
            gap: 5
        }
    }

    Component {
        id: cuspX

        CuspFrame {
            fill: "transparent"
            stroke: frame.stroke
            cut: 12
            gap: 4
        }
    }

    // A photograph in the paper: a fine rule, heavy along its foot.
    Component {
        id: pressX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: BookStyle.ink
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 4
                color: BookStyle.ink
            }
        }
    }

    // Wasteland: a scrap of a plate taped in at its corners.
    Component {
        id: tapeX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.ink, 0.5)
            }
            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    readonly property bool r: index % 2 === 1
                    readonly property bool b: index > 1
                    x: (r ? frame.width - 34 : -14)
                    y: (b ? frame.height - 14 : -8)
                    width: 48
                    height: 20
                    rotation: (r !== b ? 1 : -1) * 38
                    color: Colors.withAlpha("#e6d9a8", 0.75)
                    border.width: 1
                    border.color: Colors.withAlpha("#8a7c50", 0.35)
                }
            }
        }
    }

    // Observatory: an engraved double rim, graduated along its head.
    Component {
        id: brassX

        Item {
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: frame.stroke
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(frame.stroke, 0.5)
            }
            ScaleTicks {
                x: 14
                y: 6
                width: parent.width - 28
                height: 8
                color: frame.stroke
                step: 6
            }
        }
    }

    // Abyss: a lit hairline and bolts at the corners.
    Component {
        id: rivetX

        Item {
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(frame.stroke, 0.6)
            }
            Repeater {
                model: 4

                Rivet {
                    required property int index
                    x: index % 2 === 1 ? frame.width - 14 : 8
                    y: index > 1 ? frame.height - 14 : 8
                    size: 6
                }
            }
        }
    }

    // Devaloka: a gold rule with temple borders along the head and foot.
    Component {
        id: templeX

        Item {
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: frame.stroke
            }
            TempleBorder {
                x: 10
                y: 1
                width: parent.width - 20
                height: 9
                color: frame.stroke
                step: 9
            }
            TempleBorder {
                x: 10
                y: parent.height - 10
                width: parent.width - 20
                height: 9
                color: frame.stroke
                step: 9
                down: true
            }
        }
    }

    Component {
        id: crenelX

        CrenelFrame {
            fill: "transparent"
            stroke: frame.stroke
            merlon: 16
            depth: 7
        }
    }

    // Sekiro: a gold hairline, a fine line inside it, chevrons at the corners.
    Component {
        id: sumiX

        Item {
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.gold, 0.8)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.gold, 0.25)
            }
            Repeater {
                model: 4

                BookText {
                    required property int index
                    readonly property bool r: index % 2 === 1
                    readonly property bool b: index > 1
                    x: r ? frame.width - 18 : 6
                    y: b ? frame.height - 20 : 2
                    text: "◆"
                    font.pixelSize: 10
                    color: BookStyle.accent
                }
            }
        }
    }
}
