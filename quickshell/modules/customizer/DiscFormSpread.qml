pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// Chapter III, § 2: the disc's corner, its look, its size, how far it
// peeks out, and how many chambers it has.
Spread {
    id: spread

    readonly property var wd: Services.WorkspaceDiscService
    readonly property var cornerNames: ({ topLeft: "Top left", topRight: "Top right", bottomLeft: "Bottom left", bottomRight: "Bottom right" })

    leftContent: Plate {
        chapter: 3
        title: "The Workspace Disc"
        opening: false
        section: "Its form and place"
        figure: "Fig. 6."
        caption: "The disc opened out in its corner, at its own size; below, the four corners it can keep to."

        Item {
            anchors.fill: parent

            DiscCorner {
                id: big
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: Math.min(parent.width - 20, 420)
                height: 260
                phase: spread.focusKey === "peek" ? "peek" : "open"
            }

            // The four corners: click one to send it there.
            Item {
                id: corners
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: big.bottom
                anchors.topMargin: 34
                width: 230
                height: 144

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: BookStyle.line
                }

                Repeater {
                    model: spread.wd.corners

                    Rectangle {
                        id: dot

                        required property string modelData
                        readonly property bool here: spread.wd.corner === dot.modelData
                        readonly property bool r: dot.modelData.endsWith("Right")
                        readonly property bool b: dot.modelData.startsWith("bottom")

                        x: dot.r ? corners.width - width / 2 - 2 : -width / 2 + 2
                        y: dot.b ? corners.height - height / 2 - 2 : -height / 2 + 2
                        width: 40
                        height: 40
                        radius: 20
                        color: dot.here ? BookStyle.accent : dotArea.containsMouse ? Colors.withAlpha(BookStyle.accent, 0.3) : BookStyle.paper
                        border.width: 1.5
                        border.color: dot.here ? BookStyle.accent : BookStyle.inkSoft

                        MouseArea {
                            id: dotArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: spread.wd.setCorner(dot.modelData)
                        }
                    }
                }

                BookText {
                    anchors.centerIn: parent
                    text: spread.cornerNames[spread.wd.corner]
                    font.italic: true
                    color: BookStyle.inkSoft
                }
            }
        }
    }

    Leaf {
        kicker: "§ 2"
        title: "Its form and place"
        intro: "Where it keeps, what it's made of, and how big. You can also drag the disc itself into another corner."
        spacing: 18

        Entry {
            width: parent.width
            key: "corner"
            label: "Its corner"
            stacked: true

            InkChoice {
                options: spread.wd.corners.map(c => ({ id: c, label: spread.cornerNames[c] }))
                current: spread.wd.corner
                spacing: 14
                onChosen: id => spread.wd.setCorner(id)
            }
        }

        Entry {
            width: parent.width
            key: "skin"
            label: "Its look"

            InkChoice {
                options: spread.wd.skins.map(k => ({ id: k.id, label: k.name }))
                current: spread.wd.skin
                onChosen: id => spread.wd.set("skin", id)
            }
        }

        Entry {
            width: parent.width
            key: "size"
            label: "Size"
            note: "Its radius; the chambers grow with it."
            controlWidth: 290

            InkSlider {
                from: 36
                to: 96
                stepSize: 1
                unit: "px"
                value: spread.wd.discRadius
                mark: 55
                onMoved: v => spread.wd.setSize(v)
            }
        }

        Entry {
            width: parent.width
            key: "peek"
            label: "Peeks out by"
            note: "How much of it shows at rest."
            controlWidth: 290

            InkSlider {
                from: 6
                to: 48
                stepSize: 1
                unit: "px"
                value: spread.wd.peekOffset
                mark: 16
                onMoved: v => spread.wd.set("peekOffset", v)
            }
        }

        Entry {
            width: parent.width
            key: "chambers"
            label: "Chambers"
            stacked: true

            InkChoice {
                options: [{ id: "live", label: "One per workspace in use" }, { id: "fixed", label: "A fixed number" }]
                current: spread.wd.expressive ? "live" : "fixed"
                spacing: 14
                onChosen: id => spread.wd.set("expressive", id === "live")
            }
        }

        Entry {
            width: parent.width
            key: "count"
            label: "How many"
            controlWidth: 290
            dim: spread.wd.expressive

            InkSlider {
                from: 3
                to: 10
                stepSize: 1
                value: spread.wd.workSpaceAmount
                onMoved: v => spread.wd.set("workSpaceAmount", v)
            }
        }

        Entry {
            width: parent.width
            key: "teeth"
            label: "The cog's teeth"
            note: "Their width, and the valleys' depth between them."
            dim: spread.wd.skin !== "default"
            stacked: true

            Column {
                spacing: 4

                InkSlider {
                    width: parent.width
                    from: 0
                    to: 100
                    stepSize: 1
                    unit: "%"
                    value: spread.wd.toothWidth
                    onMoved: v => spread.wd.set("toothWidth", v)
                }

                InkSlider {
                    width: parent.width
                    from: 0
                    to: 100
                    stepSize: 1
                    unit: "%"
                    value: spread.wd.valleyDepth
                    onMoved: v => spread.wd.set("valleyDepth", v)
                }
            }
        }
    }
}
