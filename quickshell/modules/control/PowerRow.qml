pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// Lock, sleep, log out, restart and shut down, as one strip. The last
// three ask first: a click arms the button (it says so, and a line runs out
// under it), a second click within three seconds goes ahead.
Item {
    id: root

    required property var center

    property int armed: -1

    readonly property real r: 14
    readonly property var actions: [
        { icon: "lock", label: "Lock", ask: false, act: () => root.center.lock() },
        { icon: "bedtime", label: "Sleep", ask: false, act: () => root.center.suspend() },
        { icon: "logout", label: "Log out", ask: true, act: () => root.center.logOut() },
        { icon: "restart_alt", label: "Restart", ask: true, act: () => root.center.reboot() },
        { icon: "power_settings_new", label: "Shut down", ask: true, act: () => root.center.powerOff() }
    ]

    implicitHeight: 60

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = -1
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ControlStyle.corner(root.r, 0)
        topRightRadius: ControlStyle.corner(root.r, 1)
        bottomRightRadius: ControlStyle.corner(root.r, 2)
        bottomLeftRadius: ControlStyle.corner(root.r, 3)
        color: ControlStyle.well
        border.width: 1
        border.color: ControlStyle.line
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.actions

            MouseArea {
                id: button
                required property var modelData
                required property int index
                readonly property bool armed: root.armed === index
                readonly property bool first: index === 0
                readonly property bool last: index === root.actions.length - 1
                width: root.width / root.actions.length
                height: root.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.ask && !armed) {
                        root.armed = index;
                        disarm.restart();
                        return;
                    }
                    root.armed = -1;
                    disarm.stop();
                    modelData.act();
                }

                // Lit under the pointer, red while armed; the ends follow
                // the strip's corners.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    topLeftRadius: button.first ? ControlStyle.corner(root.r, 0) : 0
                    bottomLeftRadius: button.first ? ControlStyle.corner(root.r, 3) : 0
                    topRightRadius: button.last ? ControlStyle.corner(root.r, 1) : 0
                    bottomRightRadius: button.last ? ControlStyle.corner(root.r, 2) : 0
                    color: button.armed ? Colors.withAlpha(ControlStyle.danger, 0.18) : button.containsMouse ? ControlStyle.wellHover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                // The seam to the next one.
                Rectangle {
                    visible: !button.last
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height - 26
                    color: ControlStyle.line
                }

                // How long it stays armed.
                Rectangle {
                    visible: button.armed
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    x: 12
                    height: 2
                    radius: 1
                    color: ControlStyle.danger

                    NumberAnimation on width {
                        running: button.armed
                        from: button.width - 24
                        to: 0
                        duration: disarm.interval
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: button.modelData.icon
                        filled: button.containsMouse || button.armed
                        font.pixelSize: 21
                        color: button.armed ? ControlStyle.danger : button.containsMouse ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.8)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ControlStyle.label(button.armed ? "Sure?" : button.modelData.label)
                        font.family: ControlStyle.ui
                        font.pixelSize: 11
                        font.weight: button.armed ? Font.Bold : Font.Normal
                        font.capitalization: ControlStyle.caps
                        font.letterSpacing: ControlStyle.upper ? 0.8 : 0.2
                        color: button.armed ? ControlStyle.danger : Colors.withAlpha(ControlStyle.ink, 0.7)
                    }
                }
            }
        }
    }
}
