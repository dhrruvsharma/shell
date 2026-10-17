pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.colors
import qs.services as Services
import qs.modules.lock

// The notifications, newest first, under the theme's name for them, with
// how many and a way to clear them all; when there are none, the theme's
// line for the quiet. Takes whatever height the panel has left.
ColumnLayout {
    id: root

    required property var center

    readonly property var items: Services.Notification.history.slice().reverse()

    spacing: 12

    SectionTitle {
        Layout.fillWidth: true
        text: ControlStyle.word("notifications")

        // Do not disturb, while it holds the toasts back.
        Glyph {
            visible: Services.Notification.dnd
            anchors.verticalCenter: parent?.verticalCenter
            text: "do_not_disturb_on"
            filled: true
            font.pixelSize: 15
            color: ControlStyle.accent
        }

        Text {
            visible: root.items.length > 0
            anchors.verticalCenter: parent?.verticalCenter
            text: root.items.length
            font.family: ControlStyle.mono
            font.pixelSize: 12
            font.weight: Font.Bold
            color: Colors.withAlpha(ControlStyle.ink, 0.55)
        }

        MouseArea {
            id: clear
            visible: root.items.length > 0
            width: clearText.implicitWidth + 16
            height: clearText.implicitHeight + 8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.Notification.clearAll()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(10)
                color: clear.containsMouse ? ControlStyle.wellHover : "transparent"
            }

            Text {
                id: clearText
                anchors.centerIn: parent
                text: ControlStyle.label("Clear all")
                font.family: ControlStyle.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.capitalization: ControlStyle.caps
                font.letterSpacing: ControlStyle.upper ? 1 : 0
                color: ControlStyle.paper ? ControlStyle.ink : ControlStyle.accent
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 120

        ListView {
            id: list

            readonly property bool overflows: contentHeight > height + 1

            anchors.fill: parent
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: root.items

            delegate: NotificationCard {
                required property var modelData
                width: list.width
                n: modelData
                onActed: root.center.close()
            }

            // Where it runs on past an edge, it fades out into the frame
            // rather than ending on a sliver of a card.
            layer.enabled: overflows
            layer.effect: OpacityMask {
                maskSource: fade
            }
        }

        Rectangle {
            id: fade

            readonly property real edge: 26 / Math.max(1, height)

            anchors.fill: list
            visible: false
            layer.enabled: list.overflows
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: list.atYBeginning ? "white" : "transparent"
                }
                GradientStop {
                    position: fade.edge
                    color: "white"
                }
                GradientStop {
                    position: 1 - fade.edge
                    color: "white"
                }
                GradientStop {
                    position: 1
                    color: list.atYEnd ? "white" : "transparent"
                }
            }
        }

        // The quiet.
        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            visible: root.items.length === 0
            spacing: 12

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Notification.dnd ? "notifications_paused" : "notifications_none"
                font.pixelSize: 34
                color: Colors.withAlpha(ControlStyle.accent, 0.55)
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: ControlStyle.word("notifyIdle")
                font.family: ControlStyle.body
                font.pixelSize: 14
                font.italic: ["scroll", "lancet", "clipping", "brass", "patta", "banner"].includes(ControlStyle.frame)
                color: Colors.withAlpha(ControlStyle.ink, 0.58)
            }

            Text {
                width: parent.width
                visible: Services.Notification.dnd
                horizontalAlignment: Text.AlignHCenter
                text: "Do not disturb is on"
                font.family: ControlStyle.ui
                font.pixelSize: 11
                font.capitalization: ControlStyle.caps
                font.letterSpacing: ControlStyle.upper ? 1.2 : 0.3
                color: Colors.withAlpha(ControlStyle.ink, 0.45)
            }
        }
    }
}
