pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.modules.lock
import qs.services as Services

// The desktop's plate: your wallpaper with the desktop widgets where they
// stand on it (the visualizer too), those that are off as dashed ghosts in
// their places. A click on one puts it out or takes it in.
Item {
    id: fig

    property string lit: ""

    readonly property real sw: 1920
    readonly property real sh: 1200
    readonly property real k: Math.min(fig.width / fig.sw, (fig.height - 30) / fig.sh)
    // Roughly how big each widget is on the screen.
    readonly property var sizes: ({ clock: [380, 220], music: [380, 160], sysmon: [340, 250], quote: [400, 130] })

    Item {
        id: screen
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: fig.sw * fig.k
        height: fig.sh * fig.k

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 6
            color: Qt.darker(BookStyle.cover, 1.2)
        }

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.85
        }

        Repeater {
            model: Services.DesktopWidgets.widgets

            Item {
                id: w

                required property var modelData
                readonly property string wid: w.modelData.id
                readonly property bool on: Services.DesktopWidgets.enabled(w.wid)
                readonly property var size: w.wid === "cava" ? [Services.CavaWidget.boxWidth, Services.CavaWidget.boxHeight] : fig.sizes[w.wid] ?? [300, 200]
                readonly property var frac: Services.DesktopWidgets.pos(w.wid)
                readonly property real rx: w.wid === "cava" ? Services.CavaWidget.posX : w.frac.x * (fig.sw - w.size[0])
                readonly property real ry: w.wid === "cava" ? Services.CavaWidget.posY : w.frac.y * (fig.sh - w.size[1])

                x: Math.max(0, Math.min(fig.sw - w.size[0], w.rx)) * fig.k
                y: Math.max(Services.BarLayout.reserveTop, Math.min(fig.sh - w.size[1], w.ry)) * fig.k
                width: w.size[0] * fig.k
                height: w.size[1] * fig.k

                Rectangle {
                    anchors.fill: parent
                    visible: w.on
                    radius: 4
                    color: Colors.withAlpha(Colors.surface_container, 0.85)
                    border.width: fig.lit === w.wid || area.containsMouse ? 2 : 1
                    border.color: fig.lit === w.wid || area.containsMouse ? BookStyle.accent : Colors.withAlpha(Colors.on_surface, 0.3)
                }

                Shape {
                    anchors.fill: parent
                    visible: !w.on
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: fig.lit === w.wid || area.containsMouse ? BookStyle.accent : Colors.withAlpha("#ffffff", 0.7)
                        strokeWidth: 1.2
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 3]

                        PathRectangle {
                            x: 0.6
                            y: 0.6
                            width: w.width - 1.2
                            height: w.height - 1.2
                            radius: 4
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: w.on ? w.modelData.icon : "visibility_off"
                        filled: w.on
                        font.pixelSize: Math.min(22, w.height * 0.4)
                        color: w.on ? Colors.primary : "#ffffff"
                        opacity: w.on ? 1 : 0.7
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: w.height > 34
                        text: w.modelData.name
                        font.pixelSize: 10
                        color: w.on ? Colors.on_surface : "#ffffff"
                        opacity: w.on ? 0.85 : 0.7
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.DesktopWidgets.toggle(w.wid)
                }
            }
        }
    }

    BookText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: screen.bottom
        anchors.topMargin: 12
        text: "Drag them about on the desktop itself; ALT+SHIFT+W styles them."
        font.italic: true
        font.pixelSize: 12
        color: BookStyle.inkSoft
    }
}
