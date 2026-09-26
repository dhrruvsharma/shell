pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock

// "Achievement unlocked" cards that drop in one after another when an unlock
// earns trophies. At most three are shown; the rest are summed up below.
Column {
    id: toasts

    required property LockContext ctx
    property real sc: 1
    property real t: 0

    readonly property var earned: ctx.reward ? ctx.reward.achievements : []

    spacing: 10 * sc

    Connections {
        target: toasts.ctx

        function onGranted() {
            if (toasts.earned.length > 0)
                timeline.restart();
        }
    }

    NumberAnimation {
        id: timeline
        target: toasts
        property: "t"
        from: 0
        to: 1
        duration: 1800
    }

    Repeater {
        model: toasts.earned.slice(0, 3)

        HudPanel {
            id: toast

            required property int index
            required property var modelData
            readonly property real appear: LockTheme.seg(toasts.t, 0.1 + index * 0.14, 0.32 + index * 0.14)

            width: 440 * toasts.sc
            height: 78 * toasts.sc
            cut: 14 * toasts.sc
            fill: LockTheme.panelHi
            accent: LockTheme.gold
            accentLength: 60 * toasts.sc
            opacity: appear
            transform: Translate { x: (1 - toast.appear) * 60 * toasts.sc }

            Item {
                id: badge
                x: 18 * toasts.sc
                anchors.verticalCenter: parent.verticalCenter
                width: 46 * toasts.sc
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.78
                    height: width
                    rotation: 45
                    color: LockTheme.alpha(LockTheme.gold, 0.16)
                    border.width: 1
                    border.color: LockTheme.alpha(LockTheme.gold, 0.6)
                }

                Glyph {
                    anchors.centerIn: parent
                    text: toast.modelData.icon
                    filled: true
                    font.pixelSize: 24 * toasts.sc
                    color: LockTheme.gold
                }
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 16 * toasts.sc
                anchors.right: parent.right
                anchors.rightMargin: 16 * toasts.sc
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * toasts.sc

                Text {
                    text: "ACHIEVEMENT UNLOCKED  ·  +40 XP"
                    font.family: LockTheme.mono
                    font.pixelSize: 10 * toasts.sc
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5 * toasts.sc
                    color: LockTheme.gold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: toast.modelData.name.toUpperCase()
                    font.family: LockTheme.display
                    font.pixelSize: 18 * toasts.sc
                    color: LockTheme.ink
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: toast.modelData.desc
                    font.family: LockTheme.mono
                    font.pixelSize: 11 * toasts.sc
                    color: LockTheme.inkDim
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        visible: toasts.earned.length > 3
        opacity: LockTheme.seg(toasts.t, 0.55, 0.75)
        text: "+" + (toasts.earned.length - 3) + " MORE"
        font.family: LockTheme.mono
        font.pixelSize: 11 * toasts.sc
        font.weight: Font.Bold
        font.letterSpacing: 2.5 * toasts.sc
        color: LockTheme.gold
    }
}
