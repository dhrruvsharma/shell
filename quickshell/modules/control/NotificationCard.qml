pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock

// One notification: the app and when, the summary, the body (markup and
// links as the app sent them), a picture if it came with one, and a row of
// buttons: the app's own actions, and Reply when the app takes an answer
// (a chat's inline reply), which opens a field right on the card. A click
// anywhere else runs the app's default action and brings its window
// forward; the cross closes it.
//
// The control centre lays these on a well of their own; a toast
// (`toast: true`) sits on the theme's frame (NotificationToast), so it
// draws no well, and shows the time it has left along its foot. The
// countdown stops while the pointer's on it or a reply is being typed.
Item {
    id: card

    required property var n
    property bool toast: false
    // Room kept clear at the header's right end (a frame's seal there).
    property real headerRight: 0
    // A click ran the app's own action (the panel makes way for the app).
    signal acted

    readonly property string icon: Services.Notification.iconOf(n)
    readonly property string picture: Services.Notification.pictureOf(n)
    readonly property var extraActions: (n?.actions ?? []).filter(a => a.identifier !== "default" && a.identifier !== "inline-reply")
    readonly property bool canReply: n?.canReply ?? false
    readonly property bool hasButtons: extraActions.length > 0 || canReply
    readonly property real r: 14
    readonly property real inset: toast ? 0 : 14

    // Typing an answer.
    property bool replying: false
    readonly property bool hovered: area.containsMouse || close.containsMouse || buttonsHover.hovered || replyHover.hovered

    implicitHeight: content.implicitHeight + (toast ? 0 : 24)

    // A toast stays put while it's pointed at or answered.
    Binding {
        when: card.toast && !!card.n
        target: card.n
        property: "held"
        value: card.hovered || card.replying
        restoreMode: Binding.RestoreValue
    }

    Binding {
        when: !!card.n
        target: card.n
        property: "replying"
        value: card.replying
        restoreMode: Binding.RestoreValue
    }

    function send() {
        const n = card.n;
        const text = replyInput.text;
        if (text.trim().length === 0)
            return;
        replyInput.text = "";
        card.replying = false;
        Services.Notification.reply(n, text);
    }

    function openReply() {
        card.replying = true;
        replyInput.forceActiveFocus();
    }

    Rectangle {
        visible: !card.toast
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
        x: card.toast ? -8 : 1
        y: card.toast ? 2 : 10
        width: 3
        height: parent.height - (card.toast ? 4 : 20)
        radius: 1.5
        color: ControlStyle.danger
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const n = card.n;
            if (Services.Notification.defaultAction(n) !== null)
                card.acted();
            Services.Notification.activate(n, !card.toast);
        }
    }

    Column {
        id: content
        x: card.inset
        y: card.toast ? 0 : 12
        width: parent.width - 2 * card.inset
        spacing: card.toast ? 7 : 6

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
                color: Colors.withAlpha(card.toast ? ControlStyle.labelColor : ControlStyle.ink, card.toast ? 0.85 : 0.6)
            }

            MouseArea {
                id: close
                anchors.right: parent.right
                anchors.rightMargin: card.headerRight - 4
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                opacity: card.hovered || card.replying ? 1 : 0
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
                    maximumLineCount: card.toast ? 3 : 4
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

        // The app's buttons, and Reply. They share the width when they fit
        // on one line, else they wrap.
        Flow {
            id: buttons

            readonly property int count: card.extraActions.length + (card.canReply ? 1 : 0)
            readonly property real even: (width - spacing * (count - 1)) / Math.max(1, count)
            readonly property bool fits: card.extraActions.every(a => buttons.measure(a.text) <= even) && (!card.canReply || buttons.measure("Reply") <= even)

            function measure(s) {
                return metrics.advanceWidth(ControlStyle.label(s)) + 44;
            }

            width: parent.width
            visible: card.hasButtons && !card.replying
            spacing: 6
            topPadding: 2

            HoverHandler {
                id: buttonsHover
            }

            FontMetrics {
                id: metrics
                font.family: ControlStyle.ui
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Repeater {
                model: card.extraActions

                NotificationButton {
                    required property var modelData
                    width: buttons.fits ? buttons.even : implicitWidth
                    text: modelData.text
                    onClicked: {
                        const n = card.n;
                        const action = modelData;
                        card.acted();
                        Services.Notification.invoke(n, action);
                    }
                }
            }

            NotificationButton {
                visible: card.canReply
                width: buttons.fits ? buttons.even : implicitWidth
                glyph: "reply"
                text: "Reply"
                primary: true
                onClicked: card.openReply()
            }
        }

        // The answer, typed on the card. Enter sends, Esc puts it away.
        Item {
            id: reply
            width: parent.width
            height: card.replying ? 38 : 0
            visible: card.replying
            opacity: card.replying ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            HoverHandler {
                id: replyHover
            }

            // Clicks in the field stay in it.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: replyInput.forceActiveFocus()
            }

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(12)
                color: ControlStyle.well
                border.width: 1
                border.color: replyInput.activeFocus ? Colors.withAlpha(ControlStyle.accent, 0.7) : ControlStyle.line

                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            TextInput {
                id: replyInput
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: sendButton.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                font.family: ControlStyle.body
                font.pixelSize: 13
                color: ControlStyle.ink
                selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                selectedTextColor: ControlStyle.ink
                selectByMouse: true

                Keys.onReturnPressed: card.send()
                Keys.onEnterPressed: card.send()
                Keys.onEscapePressed: event => {
                    card.replying = false;
                    replyInput.text = "";
                    event.accepted = true;
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: replyInput.text.length === 0
                    text: card.n?.replyPlaceholder || "Reply to " + (card.n?.appName || "them") + "…"
                    elide: Text.ElideRight
                    width: parent.width
                    font: replyInput.font
                    color: Colors.withAlpha(ControlStyle.ink, 0.4)
                }
            }

            MouseArea {
                id: sendButton
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                hoverEnabled: true
                enabled: replyInput.text.trim().length > 0
                cursorShape: Qt.PointingHandCursor
                onClicked: card.send()

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(15)
                    color: sendButton.enabled ? (sendButton.containsMouse ? Qt.lighter(ControlStyle.accent, 1.12) : ControlStyle.accent) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    text: "send"
                    filled: true
                    font.pixelSize: 16
                    color: sendButton.enabled ? ControlStyle.inkOn(ControlStyle.accent) : Colors.withAlpha(ControlStyle.ink, 0.35)
                }
            }
        }
    }
}
