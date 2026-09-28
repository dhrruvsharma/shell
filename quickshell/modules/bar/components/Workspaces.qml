import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services as Services
import qs.colors
import qs.components

Rectangle {
    id: wsContainer

    required property string fontFamily
    required property int fontSize

    readonly property var hypr: Services.Hyprland
    readonly property int activeWs: hypr.focusedWorkspaceId
    readonly property int workspaceCount: Math.max(10, hypr.workspaceIds.length)
    readonly property bool isSpecialOpen: false

    readonly property int visibleCount: 5
    property int pageCount: Math.max(
        20,
        Math.ceil(workspaceCount / visibleCount),
        Math.ceil(activeWs / visibleCount)
    )


    function changeWorkspace(id) {
        Services.Hyprland.changeWorkspace(id)
    }

    function changeWorkspaceRelative(delta) {
        changeWorkspace(activeWs + delta)
    }

    // Desktop themes restyle the capsule and pips (look.shape): the HUD
    // theme's is chamfered with square bars and diamond pips, Neon Noir's
    // has a cut corner and bars for pips, Wabi-sabi's is a pebble with
    // uneven dots and empty rings.
    readonly property var look: Services.DesktopTheme.look
    readonly property bool hud: look.shape === "chamfer"
    readonly property bool neon: look.shape === "neon"
    readonly property bool pebble: look.shape === "pebble"
    readonly property bool squarePips: look.shape === "chamfer" || look.shape === "square"

    Layout.preferredHeight: 26
    Layout.preferredWidth: visibleCount * 26 + (visibleCount - 1) * 4 + 4
    color: hud || neon ? "transparent" : Colors.surface_container
    radius: Services.DesktopTheme.radius(look, height / 2, height)
    topLeftRadius: Services.DesktopTheme.corner(look, radius, 0)
    topRightRadius: Services.DesktopTheme.corner(look, radius, 1)
    bottomRightRadius: Services.DesktopTheme.corner(look, radius, 2)
    bottomLeftRadius: Services.DesktopTheme.corner(look, radius, 3)
    border.width: hud || neon ? 0 : look.border
    border.color: Services.DesktopTheme.borderColor(look)
    clip: true

    HudFrame {
        visible: wsContainer.hud
        cut: 7
        fill: Colors.surface_container
    }

    NeonFrame {
        visible: wsContainer.neon
        cut: 7
        fill: Colors.surface_container
        glow: 0.4
    }

    ListView {
        id: pager
        anchors.fill: parent

        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        interactive: false

        highlightMoveDuration: 400

        model: pageCount
        currentIndex: Math.floor((activeWs - 1) / visibleCount)

        delegate: Item {
            property int startWs: index * visibleCount + 1
            property var pageOccupiedRanges: []

            function updatePageOccupied() {
                const ranges = []
                let start = -1

                for (let i = 0; i < visibleCount; i++) {
                    let wsId = startWs + i
                    let occupied = hypr.isWorkspaceOccupied(wsId)

                    if (occupied) {
                        if (start === -1) start = i
                    } else if (start !== -1) {
                        ranges.push({ start, end: i - 1 })
                        start = -1
                    }
                }

                if (start !== -1)
                    ranges.push({ start, end: visibleCount - 1 })

                pageOccupiedRanges = ranges
            }

            width: wsContainer.width
            height: wsContainer.height

            Component.onCompleted: updatePageOccupied()

            Connections {
                target: hypr
                function onStateChanged() { updatePageOccupied() }
            }

            Repeater {
                model: pageOccupiedRanges

                Rectangle {
                    height: 26
                    radius: Services.DesktopTheme.radius(wsContainer.look, 14, height)
                    topLeftRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 0)
                    topRightRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 1)
                    bottomRightRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 2)
                    bottomLeftRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 3)
                    opacity: 0.8
                    color: Colors.background

                    x: modelData.start * (26 + 4)
                    width: (modelData.end - modelData.start + 1) * 26 +
                        (modelData.end - modelData.start) * 4
                }
            }

            Rectangle {
                property int localIndex: activeWs - startWs

                visible: localIndex >= 0 && localIndex < visibleCount

                x: localIndex * (26 + 4) + 2
                width: 26
                height: 26
                radius: Services.DesktopTheme.radius(wsContainer.look, 13, height)
                topLeftRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 0)
                topRightRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 1)
                bottomRightRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 2)
                bottomLeftRadius: Services.DesktopTheme.corner(wsContainer.look, radius, 3)

                color: Services.DesktopTheme.accent

                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutSine } }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 4

                Repeater {
                    model: visibleCount

                    Item {
                        property int wsId: startWs + index
                        property bool isActive: wsId === activeWs
                        property bool hasWindows: hypr.isWorkspaceOccupied(wsId)

                        width: 26
                        height: 26

                        Rectangle {
                            visible: !isActive
                            anchors.centerIn: parent
                            width: wsContainer.neon ? 3 : (hasWindows ? 6 : 4) + (wsContainer.pebble ? [0, 1, -1, 2, 0][index % 5] : 0)
                            height: wsContainer.neon ? (hasWindows ? 12 : 6) : width
                            radius: wsContainer.squarePips || wsContainer.neon ? 0 : width / 2
                            rotation: wsContainer.hud ? 45 : 0
                            color: wsContainer.pebble && !hasWindows ? "transparent"
                                : wsContainer.neon && !hasWindows ? Colors.withAlpha(Colors.on_surface, 0.35)
                                : hasWindows ? Services.DesktopTheme.accent : Colors.secondary
                            border.width: wsContainer.pebble && !hasWindows ? 1 : 0
                            border.color: Colors.secondary
                        }

                        StyledText {
                            visible: isActive
                            anchors.centerIn: parent
                            text: wsId
                            font.family: fontFamily
                            font.bold: true
                            color: Colors.background
                            font.pixelSize: 17
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: changeWorkspace(wsId)
                        }
                    }
                }
            }
        }
    }
}
