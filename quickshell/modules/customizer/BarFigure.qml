pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services

// The bar's plate: the bar as it stands, cut into its three stretches (the
// left end, the media pill in the middle, the right end) so each reads at
// a fair size, and under them the screen with the bar on its edge (`edges`
// shows that; a click on another edge moves it there). A click on a widget
// is `picked`; the one the facing page points at is lit.
Item {
    id: fig

    property string lit: ""
    property bool edges: true
    property string hoveredId: ""
    // Each widget's width as wide as its text, from the strips.
    property var naturals: ({})
    readonly property real stripsHeight: strips.height

    signal picked(string id)

    readonly property bool standing: Services.BarLayout.vertical

    Column {
        id: strips
        width: parent.width
        spacing: 10

        Repeater {
            model: [
                { part: "left", name: fig.standing ? "The top end" : "The left end" },
                { part: "middle", name: "The middle" },
                { part: "right", name: fig.standing ? "The bottom end" : "The right end" }
            ]

            Column {
                id: stretch

                required property var modelData

                width: strips.width
                spacing: 4

                BookText {
                    text: stretch.modelData.name
                    font.family: BookStyle.ui
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                    color: BookStyle.inkSoft
                }

                BarStrip {
                    width: parent.width
                    height: 58
                    part: stretch.modelData.part
                    litId: fig.lit
                    onPicked: which => fig.picked(which)
                    onHoveredIdChanged: fig.hoveredId = hoveredId
                    onNaturalsChanged: fig.naturals = Object.assign({}, fig.naturals, naturals)
                }
            }
        }
    }

    // The screen, the bar on its edge; the other edges to move it to.
    Item {
        id: screen
        visible: fig.edges
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: strips.bottom
        anchors.topMargin: Math.max(18, (fig.height - strips.height - height) / 2)
        width: 210
        height: 132

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: BookStyle.line
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
                sourceSize: Qt.size(420, 264)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.55
            }
        }

        Repeater {
            model: ["top", "bottom", "left", "right"]

            Item {
                id: edge

                required property string modelData
                readonly property bool here: Services.BarLayout.edge === edge.modelData
                readonly property bool across: edge.modelData === "top" || edge.modelData === "bottom"

                x: edge.modelData === "right" ? screen.width - 12 : 0
                y: edge.modelData === "bottom" ? screen.height - 12 : 0
                width: edge.across ? screen.width : 12
                height: edge.across ? 12 : screen.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: edge.here ? 1 : 3
                    radius: 3
                    color: edge.here ? BookStyle.accent : edgeArea.containsMouse ? Colors.withAlpha(BookStyle.accent, 0.35) : "transparent"
                    border.width: edge.here ? 0 : 1
                    border.color: Colors.withAlpha(BookStyle.ink, edgeArea.containsMouse ? 0.6 : 0.25)
                }

                MouseArea {
                    id: edgeArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: edge.here ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: Services.BarLayout.setEdge(edge.modelData)
                }
            }
        }
    }
}
