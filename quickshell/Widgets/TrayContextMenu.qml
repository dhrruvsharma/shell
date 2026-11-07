import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.components
import qs.services as Services

// A tray app's menu, rolled out of the bar by its icon (Tray.qml opens it).
// While it shows, the whole screen is its: a click anywhere else closes it
// (rather than going through to what's under it), and so does Esc. A
// submenu opens in its place, with Back at its top; each level keeps an
// opener of its own (pointing one opener at a submenu lets go of the menu
// the submenu belongs to, entries and all).
PanelWindow {
    id: root

    // The menus gone into: the app's, then each submenu.
    property var chain: []
    readonly property var current: [opener0, opener1, opener2, opener3][Math.max(0, Math.min(3, root.chain.length - 1))]
    // Where the tray icon's middle lies along the bar (screen x on a lying
    // bar, y on a standing one).
    property real menuPos: 0
    property bool hasCurrent: false
    property int animLength: 400
    property var animCurve: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]

    function open(handle, pos) {
        chain = [handle];
        menuPos = pos;
        hasCurrent = true;
    }

    function close() {
        hasCurrent = false;
    }

    // A second right click on the same icon closes it.
    function toggle(handle, pos) {
        if (hasCurrent && chain[0] === handle)
            close();
        else
            open(handle, pos);
    }

    function enter(submenu) {
        if (chain.length < 4)
            chain = chain.concat([submenu]);
    }

    function back() {
        if (chain.length > 1)
            chain = chain.slice(0, -1);
    }

    onChainChanged: highlight.active = false

    // Full-screen surface: mapped only while a menu is showing or closing.
    visible: hasCurrent || wrapper.unroll > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.hasCurrent ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Anywhere but the menu: closes it.
    MouseArea {
        anchors.fill: parent
        enabled: root.hasCurrent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
    }

    QsMenuOpener {
        id: opener0
        menu: root.chain[0] ?? null
    }
    QsMenuOpener {
        id: opener1
        menu: root.chain[1] ?? null
    }
    QsMenuOpener {
        id: opener2
        menu: root.chain[2] ?? null
    }
    QsMenuOpener {
        id: opener3
        menu: root.chain[3] ?? null
    }

    Item {
        id: wrapper

        focus: true
        Keys.onEscapePressed: {
            if (root.chain.length > 1)
                root.back();
            else
                root.close();
        }

        readonly property real contentHeight: menuColumn.implicitHeight + 16
        readonly property string edge: Services.BarLayout.edge
        readonly property bool vertical: Services.BarLayout.vertical
        // How far it has unrolled out of the bar, 0 to 1.
        property real unroll: root.hasCurrent ? 1 : 0

        // It comes out of the bar by the tray (the surface stops at the
        // bar's exclusive zone): down from a top bar, up from a bottom one,
        // sideways from a standing one, its corners square where it meets
        // the bar.
        x: !vertical ? Math.max(8, Math.min(root.width - 248, root.menuPos - 120))
            : edge === "left" ? 2 : root.width - width - 2
        y: vertical ? Math.max(8, Math.min(root.height - contentHeight - 8, root.menuPos - contentHeight / 2))
            : edge === "bottom" ? root.height - height - 2 : 2
        width: vertical ? 240 * unroll : 240
        height: vertical ? contentHeight : contentHeight * unroll
        visible: unroll > 0
        clip: true

        Rectangle {
            id: menuBg

            // Sideways, the menu keeps its size and is wiped in from the bar.
            x: wrapper.edge === "right" ? wrapper.width - width : 0
            width: wrapper.vertical ? 240 : wrapper.width
            height: wrapper.vertical ? wrapper.contentHeight : wrapper.height
            color: Colors.surface_container  // was: Colors.on_surface
            clip: true
            topLeftRadius: wrapper.edge === "top" || wrapper.edge === "left" ? 0 : 14
            topRightRadius: wrapper.edge === "top" || wrapper.edge === "right" ? 0 : 14
            bottomLeftRadius: wrapper.edge === "bottom" || wrapper.edge === "left" ? 0 : 14
            bottomRightRadius: wrapper.edge === "bottom" || wrapper.edge === "right" ? 0 : 14

            Rectangle {
                id: highlight

                property real targetY: 0
                property bool active: false

                x: 8
                y: menuColumn.y + targetY
                width: parent.width - 16
                height: 36
                radius: 8
                color: Colors.secondary  // was: Colors.secondary
                opacity: active ? 0.15 : 0

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.8
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            Column {
                id: menuColumn

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 2

                // In a submenu: the way back up.
                Item {
                    id: backRow

                    visible: root.chain.length > 1
                    width: menuColumn.width
                    height: 36

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        StyledText {
                            Layout.preferredWidth: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: ""
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 12
                            color: Colors.primary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Back"
                            color: backMouse.containsMouse ? Colors.on_surface : Colors.on_surface_variant
                            font.pixelSize: 13
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: backMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            highlight.targetY = backRow.y;
                            highlight.active = true;
                        }
                        onClicked: root.back()
                    }
                }

                Repeater {
                    model: root.current.children

                    delegate: Item {
                        id: menuItem

                        property bool isSeparator: modelData.isSeparator
                        property bool hasChildren: modelData.hasChildren

                        width: menuColumn.width
                        height: isSeparator ? 12 : 36

                        Divider {
                            visible: isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 16
                            color: Colors.outline_variant  // was: colors.border
                            opacity: 0.5
                        }

                        Rectangle {
                            visible: !isSeparator && highlight.active && highlight.targetY === menuItem.y
                            width: 3
                            height: 16
                            radius: 2
                            color: Colors.primary  // was: colors.accent
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        RowLayout {
                            visible: !isSeparator
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: modelData.icon || ""
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    visible: modelData.icon !== undefined && modelData.icon !== ""
                                    layer.enabled: true

                                    layer.effect: ColorOverlay {
                                        color: (highlight.active && highlight.targetY === menuItem.y)
                                            ? Colors.primary           // was: colors.accent
                                            : Colors.on_surface_variant // was: colors.muted
                                    }

                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    visible: !(modelData.icon !== undefined && modelData.icon !== "")
                                    text: ""
                                    font.family: "Symbols Nerd Font"
                                    font.pixelSize: 6
                                    color: (highlight.active && highlight.targetY === menuItem.y)
                                        ? Colors.on_surface          // was: Colors.on_surface
                                        : Colors.on_surface_variant  // was: colors.muted
                                }

                            }

                            StyledText {
                                text: modelData.text || ""
                                color: (highlight.active && highlight.targetY === menuItem.y)
                                    ? Colors.on_surface  // was: colors.fg
                                    : Qt.rgba(
                                        Qt.color(Colors.on_surface).r,
                                        Qt.color(Colors.on_surface).g,
                                        Qt.color(Colors.on_surface).b,
                                        0.8
                                    )                        // was: Qt.rgba(colors.fg.r/g/b, 0.8)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 0.2
                                verticalAlignment: Text.AlignVCenter
                            }

                            StyledText {
                                visible: (modelData.checkable && modelData.checked) || menuItem.hasChildren
                                text: menuItem.hasChildren ? "" : ""
                                font.family: "Symbols Nerd Font"
                                color: Colors.primary  // was: colors.accent
                                font.pixelSize: 12
                            }

                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onEntered: {
                                if (!menuItem.isSeparator) {
                                    highlight.targetY = menuItem.y;
                                    highlight.active = true;
                                } else {
                                }
                            }
                            onClicked: {
                                if (!menuItem.isSeparator) {
                                    if (modelData.hasChildren) {
                                        root.enter(modelData);
                                    } else {
                                        modelData.triggered();
                                        root.close();
                                    }
                                }
                            }
                        }

                    }

                }

            }

        }

        Behavior on unroll {
            NumberAnimation {
                duration: root.animLength
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.animCurve
            }

        }

    }

    // While it shows, all of the screen (see above); while it rolls back up,
    // none of it, so the next click goes where it's meant to.
    mask: root.hasCurrent ? null : noInput

    Region {
        id: noInput
    }

}
