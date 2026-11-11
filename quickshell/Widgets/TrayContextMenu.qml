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
// the submenu belongs to, entries and all). Entries show their icon, a
// check or a dot when they're ticked, an arrow when they open a submenu,
// and are dimmed while the app has them disabled.
//
// With the bar as one strip, or floating (services/StripShape), it's a
// drawer of the strip like the bar's panels: against it, of its colour,
// unrolling out of it, joined to it through the theme's fillets with the
// strip's hairline on round it (components/StripDrawer), in the strip's own
// text, accent and wash; too near an end of the bar (the tray's usually at
// the end) it goes into the corner there, joined to the screen's side as
// well, or flush with the floating pill's end.
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

    // A drawer of the strip, and its colours there.
    readonly property bool joined: Services.StripShape.active
    readonly property color ink: root.joined ? Services.BarSettings.ink : Colors.on_surface
    readonly property color quiet: root.joined ? Colors.withAlpha(Services.BarSettings.ink, 0.62) : Colors.on_surface_variant
    readonly property color accent: root.joined ? Services.BarSettings.glyph : Colors.primary

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

        readonly property real menuWidth: 240
        readonly property real contentHeight: menuColumn.implicitHeight + 16
        readonly property string edge: Services.BarLayout.edge
        readonly property bool vertical: Services.BarLayout.vertical
        // How far it has unrolled out of the bar, 0 to 1.
        property real unroll: root.hasCurrent ? 1 : 0

        // As a drawer: where it'd start along the bar, centred on the icon,
        // and so whether it goes into a corner ("start", "end" or ""),
        // keeping room past the menu there for the fillet into the
        // screen's side, as far in from that side as the strip's end is.
        readonly property real length: wrapper.vertical ? wrapper.contentHeight : wrapper.menuWidth
        readonly property real centred: Math.round(root.menuPos - wrapper.length / 2)
        readonly property real barLength: wrapper.vertical ? root.height : root.width
        readonly property string corner: !root.joined ? ""
            : wrapper.centred + wrapper.length > wrapper.barLength - Services.StripShape.cornerRoom ? "end"
            : wrapper.centred < Services.StripShape.cornerRoom ? "start" : ""
        readonly property real foot: wrapper.corner !== "" ? Services.StripShape.cornerFoot : 0
        readonly property real side: Services.StripShape.side
        readonly property real along: wrapper.corner === "start" ? wrapper.side
            : wrapper.corner === "end" ? wrapper.barLength - wrapper.length - wrapper.side : wrapper.centred

        // It comes out of the bar by the tray (the surface stops at the
        // bar's exclusive zone): down from a top bar, up from a bottom one,
        // sideways from a standing one, its corners square where it meets
        // the bar (a hair clear of it), or as a drawer, against the strip.
        x: root.joined ? (!vertical ? along : edge === "left" ? 0 : root.width - width)
            : !vertical ? Math.max(8, Math.min(root.width - menuWidth - 8, root.menuPos - menuWidth / 2))
            : edge === "left" ? 2 : root.width - width - 2
        y: root.joined ? (vertical ? along : edge === "bottom" ? root.height - height : 0)
            : vertical ? Math.max(8, Math.min(root.height - contentHeight - 8, root.menuPos - contentHeight / 2))
            : edge === "bottom" ? root.height - height - 2 : 2
        width: vertical ? (menuWidth + foot) * unroll : menuWidth
        height: vertical ? contentHeight : (contentHeight + foot) * unroll
        visible: unroll > 0
        clip: true

        // Out of the strip: the drawer it's on.
        StripDrawer {
            visible: root.joined
            key: "tray"
            inset: 0
            atStart: wrapper.corner === "start"
            atEnd: wrapper.corner === "end"
            foot: wrapper.foot
        }

        Rectangle {
            id: menuBg

            // Sideways, the menu keeps its size and is wiped in from the
            // bar; as a drawer it keeps it either way, against the strip.
            x: wrapper.edge === "right" ? wrapper.width - width : 0
            y: root.joined && wrapper.edge === "bottom" ? wrapper.height - height : 0
            width: wrapper.menuWidth
            height: wrapper.vertical || root.joined ? wrapper.contentHeight : wrapper.height
            color: root.joined ? "transparent" : Colors.surface_container
            clip: true
            topLeftRadius: root.joined || wrapper.edge === "top" || wrapper.edge === "left" ? 0 : 14
            topRightRadius: root.joined || wrapper.edge === "top" || wrapper.edge === "right" ? 0 : 14
            bottomLeftRadius: root.joined || wrapper.edge === "bottom" || wrapper.edge === "left" ? 0 : 14
            bottomRightRadius: root.joined || wrapper.edge === "bottom" || wrapper.edge === "right" ? 0 : 14

            Rectangle {
                id: highlight

                property real targetY: 0
                property bool active: false

                x: 8
                y: menuColumn.y + targetY
                width: parent.width - 16
                height: 36
                radius: root.joined ? Services.DesktopTheme.rad(8) : 8
                color: root.joined ? Services.BarSettings.ink : Colors.secondary
                opacity: active ? (root.joined ? 0.1 : 0.15) : 0

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
                            color: root.accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Back"
                            color: backMouse.containsMouse ? root.ink : root.quiet
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
                        readonly property bool usable: !isSeparator && modelData.enabled
                        readonly property bool lit: usable && highlight.active && highlight.targetY === menuItem.y
                        readonly property bool hasIcon: modelData.icon !== undefined && modelData.icon !== ""
                        // Ticked: a check box's check, a radio button's dot.
                        readonly property bool ticked: modelData.buttonType !== QsMenuButtonType.None && modelData.checkState === Qt.Checked

                        width: menuColumn.width
                        height: isSeparator ? 12 : 36
                        opacity: isSeparator || modelData.enabled ? 1 : 0.45

                        Divider {
                            visible: isSeparator
                            anchors.centerIn: parent
                            width: parent.width - 16
                            color: root.joined && Services.StripShape.lined ? Services.StripShape.line
                                : root.joined ? Colors.withAlpha(Services.BarSettings.ink, 0.14) : Colors.outline_variant
                            opacity: root.joined ? 1 : 0.5
                        }

                        Rectangle {
                            visible: menuItem.lit
                            width: 3
                            height: 16
                            radius: 2
                            color: root.accent
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
                                    visible: menuItem.hasIcon
                                    layer.enabled: true

                                    layer.effect: ColorOverlay {
                                        color: menuItem.lit ? root.accent : root.quiet
                                    }

                                }

                                // No icon: a radio button's ring, or nothing.
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: !menuItem.hasIcon && modelData.buttonType === QsMenuButtonType.RadioButton
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: menuItem.ticked ? root.accent : "transparent"
                                    border.width: 1.5
                                    border.color: menuItem.ticked ? root.accent : root.quiet
                                }

                            }

                            StyledText {
                                text: modelData.text || ""
                                color: menuItem.lit ? root.ink : Colors.withAlpha(root.ink, 0.8)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 0.2
                                verticalAlignment: Text.AlignVCenter
                            }

                            // A submenu's arrow, or a check box's check (a
                            // radio button with an icon shows its dot here).
                            StyledText {
                                readonly property bool check: menuItem.ticked && (modelData.buttonType === QsMenuButtonType.CheckBox || menuItem.hasIcon)
                                visible: menuItem.hasChildren || check
                                text: menuItem.hasChildren ? "" : modelData.buttonType === QsMenuButtonType.CheckBox ? "" : ""
                                font.family: "Symbols Nerd Font"
                                color: root.accent
                                font.pixelSize: menuItem.hasChildren || modelData.buttonType === QsMenuButtonType.CheckBox ? 12 : 7
                            }

                        }

                        MouseArea {
                            id: itemMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: menuItem.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: {
                                if (menuItem.usable) {
                                    highlight.targetY = menuItem.y;
                                    highlight.active = true;
                                } else {
                                    highlight.active = false;
                                }
                            }
                            onClicked: {
                                if (!menuItem.usable)
                                    return;
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
