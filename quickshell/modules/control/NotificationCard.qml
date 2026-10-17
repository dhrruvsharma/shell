pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock

// One notification: the app and when, the summary, the body (markup and
// links as the app sent them), a picture if it came with one, and its
// actions. A click runs the app's default action; the cross closes it.
Item {
    id: card

    required property var n
    // A click ran the app's own action (the panel makes way for the app).
    signal acted

    readonly property string icon: Services.Notification.iconOf(n)
    readonly property string picture: Services.Notification.pictureOf(n)
    readonly property var extraActions: (n?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property real r: 14

    implicitHeight: content.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ControlStyle.corner(card.r, 0)
        topRightRadius: ControlStyle.corner(card.r, 1)
        bottomRightRadius: ControlStyle.corner(card.r, 2)
        bottomLeftRadius: ControlStyle.corner(card.r, 3)
        color: area.containsMouse ? ControlStyle.wellHover : ControlStyle.well
        border.width: 1
        border.color: card.n?.critical ? Colors.withAlpha(ControlStyle.danger, 0.6) : ControlStyle.line

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    // A critical one keeps a mark down its side.
    Rectangle {
        visible: card.n?.critical ?? false
        x: 1
        y: 10
        width: 3
        height: parent.height - 20
        radius: 1.5
        color: ControlStyle.danger
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Services.Notification.defaultAction(card.n) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            const acting = Services.Notification.defaultAction(card.n) !== null;
            Services.Notification.activate(card.n);
            if (acting)
                card.acted();
        }
    }

    Column {
        id: content
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 6

        // The app, and how long ago.
        Item {
            width: parent.width
            height: 20

            Image {
                id: appIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                visible: status === Image.Ready
                source: card.icon
                sourceSize: Qt.size(36, 36)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Glyph {
                anchors.centerIn: appIcon
                visible: !appIcon.visible
                text: "notifications"
                filled: true
                font.pixelSize: 16
                color: ControlStyle.accent
            }

            Text {
                anchors.left: appIcon.right
                anchors.leftMargin: 8
                anchors.right: close.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: ControlStyle.label(card.n?.appName || "Notification") + "  ·  " + (card.n?.timeStr ?? "")
                font.family: ControlStyle.ui
                font.pixelSize: 11
                font.capitalization: ControlStyle.caps
                font.letterSpacing: ControlStyle.upper ? 1.2 : 0.3
                color: Colors.withAlpha(ControlStyle.ink, 0.6)
            }

            MouseArea {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                opacity: area.containsMouse || containsMouse ? 1 : 0
                onClicked: Services.Notification.dismiss(card.n)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(12)
                    color: close.containsMouse ? ControlStyle.wellHover : "transparent"
                }

                Glyph {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 16
                    color: close.containsMouse ? ControlStyle.ink : Colors.withAlpha(ControlStyle.ink, 0.6)
                }
            }
        }

        Item {
            width: parent.width
            height: Math.max(words.implicitHeight, picture.visible ? picture.height : 0)

            Column {
                id: words
                width: parent.width - (picture.visible ? picture.width + 12 : 0)
                spacing: 3

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.n?.summary ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: ControlStyle.body
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: ControlStyle.ink
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.n?.body ?? ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.family: ControlStyle.body
                    font.pixelSize: 12
                    linkColor: ControlStyle.accent
                    color: Colors.withAlpha(ControlStyle.ink, 0.74)
                    onLinkActivated: link => Qt.openUrlExternally(link)

                    HoverHandler {
                        enabled: parent.hoveredLink.length > 0
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Rectangle {
                id: picture
                anchors.right: parent.right
                visible: pic.status === Image.Ready
                width: 54
                height: 54
                radius: ControlStyle.radius(10)
                color: ControlStyle.well
                clip: true

                Image {
                    id: pic
                    anchors.fill: parent
                    source: card.picture
                    sourceSize: Qt.size(108, 108)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }
            }
        }

        // The app's other actions.
        Flow {
            width: parent.width
            visible: card.extraActions.length > 0
            spacing: 6
            topPadding: 2

            Repeater {
                model: card.extraActions

                MouseArea {
                    id: chip
                    required property var modelData
                    width: chipText.implicitWidth + 22
                    height: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        chip.modelData.invoke();
                        card.acted();
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: ControlStyle.radius(14)
                        color: Colors.withAlpha(ControlStyle.accent, chip.containsMouse ? 0.3 : 0.16)
                        border.width: 1
                        border.color: Colors.withAlpha(ControlStyle.accent, 0.35)
                    }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.text
                        font.family: ControlStyle.ui
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.capitalization: ControlStyle.caps
                        color: ControlStyle.paper ? ControlStyle.ink : ControlStyle.accent
                    }
                }
            }
        }
    }
}
