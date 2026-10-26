pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.components

// One of a few words, as on a printed form: the chosen one is marked in
// the theme's way (circled in ink, bracketed, underlined, or a stroke of
// the brush under it), and the mark moves over when another is chosen.
// `options` are { id, label }.
Item {
    id: choice

    property var options: []
    property string current: ""
    property int fontSize: 15
    property real spacing: 20
    readonly property string mark: BookStyle.b.mark ?? "ring"

    signal chosen(string id)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 30

    // The chosen word: each word says when it's the one (they're built
    // after this, and asynchronously on a page turned to).
    property Item picked: null

    // The mark, behind the words; it glides to the chosen one.
    Item {
        id: markBox
        visible: choice.picked !== null && choice.picked.modelData.id === choice.current
        x: choice.picked ? row.x + choice.picked.x - pad : 0
        y: (choice.height - height) / 2
        width: choice.picked ? choice.picked.width + 2 * pad : 0
        height: choice.fontSize + 14

        readonly property real pad: choice.mark === "underline" ? 0 : 7

        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: ({ ring: ringMark, box: boxMark, underline: lineMark, brush: brushMark })[choice.mark] ?? ringMark
        }
    }

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: choice.spacing

        Repeater {
            id: words
            model: choice.options

            BookText {
                id: word

                required property var modelData
                readonly property bool on: word.modelData.id === choice.current

                onOnChanged: if (word.on) choice.picked = word
                Component.onCompleted: if (word.on) choice.picked = word
                Component.onDestruction: if (choice.picked === word) choice.picked = null

                text: word.modelData.label
                font.family: BookStyle.ui
                font.pixelSize: choice.fontSize
                font.weight: word.on ? Font.DemiBold : Font.Normal
                font.capitalization: BookStyle.labelCaps
                font.letterSpacing: BookStyle.labelSpacing * 0.6
                color: word.on ? (choice.mark === "brush" && BookStyle.themeId === "sekiro" ? BookStyle.ink : BookStyle.accent)
                    : area.containsMouse ? BookStyle.ink : BookStyle.inkSoft

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                // A dotted line under a word the pointer's on.
                Row {
                    anchors.top: parent.bottom
                    anchors.topMargin: 1
                    visible: area.containsMouse && !word.on
                    spacing: 3

                    Repeater {
                        model: Math.ceil(word.width / 5)

                        Rectangle {
                            width: 2
                            height: 1
                            color: BookStyle.inkFaint
                        }
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: choice.chosen(word.modelData.id)
                }
            }
        }
    }

    // Circled in ink: a pen's loop, not quite closed, running past its start.
    Component {
        id: ringMark

        Item {
            id: ring

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: BookStyle.accent
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: {
                            const pts = [];
                            const w = ring.width / 2, h = ring.height / 2;
                            const n = 56;
                            for (let i = 0; i <= n; i++) {
                                const a = -2.5 + (i / n) * (Math.PI * 2 + 0.55);
                                const wob = 1 + 0.035 * Math.sin(3 * a + 1.3) + i / n * 0.07;
                                pts.push(Qt.point(w + Math.cos(a) * w * wob, h + Math.sin(a) * h * wob * 1.02));
                            }
                            return pts;
                        }
                    }
                }
            }
        }
    }

    // Bracketed: the theme's corners, square or a little round.
    Component {
        id: boxMark

        Rectangle {
            color: Colors.withAlpha(BookStyle.accent, 0.1)
            border.width: 1
            border.color: BookStyle.accent
            radius: BookStyle.b.radius ?? 0
        }
    }

    Component {
        id: lineMark

        Item {
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: parent.width
                height: 2
                color: BookStyle.accent
            }
        }
    }

    // A stroke of the brush: Sekiro's crimson swash, Wabi-sabi's ink.
    Component {
        id: brushMark

        Item {
            BrushStroke {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: -6
                anchors.rightMargin: -6
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: BookStyle.themeId === "sekiro" ? 1 : parent.height * 0.32
                height: BookStyle.themeId === "sekiro" ? parent.height * 1.05 : 9
                ink: BookStyle.themeId === "sekiro" ? Colors.withAlpha(BookStyle.accent, 0.92) : Colors.withAlpha(BookStyle.ink, 0.72)
                seed: 3
                dry: 0.6
            }
        }
    }
}
