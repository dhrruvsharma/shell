pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services
import qs.modules.lock

// Trophy shelf: unlocked count and the five most recent trophies (hover one
// for its name); empty slots show a padlock.
Row {
    id: strip

    property real sc: 1
    readonly property var recent: Services.LockStats.unlockedDefs.slice(0, 5)

    spacing: 10 * sc

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            anchors.right: parent.right
            text: "TROPHIES"
            font.family: LockTheme.mono
            font.pixelSize: 10 * strip.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * strip.sc
            color: LockTheme.inkDim
        }

        Text {
            anchors.right: parent.right
            text: Services.LockStats.achievements.length + " / " + Services.LockStats.achievementDefs.length
            font.family: LockTheme.display
            font.pixelSize: 18 * strip.sc
            color: LockTheme.gold
        }
    }

    Repeater {
        model: 5

        Item {
            id: slot

            required property int index
            readonly property var def: index < strip.recent.length ? strip.recent[index] : null

            width: 40 * strip.sc
            height: width

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.74
                height: width
                rotation: 45
                color: slot.def ? LockTheme.alpha(LockTheme.gold, 0.14) : LockTheme.alpha(LockTheme.ink, 0.05)
                border.width: 1
                border.color: slot.def ? LockTheme.alpha(LockTheme.gold, hover.containsMouse ? 0.9 : 0.5) : LockTheme.line
            }

            Glyph {
                anchors.centerIn: parent
                text: slot.def ? slot.def.icon : "lock"
                filled: slot.def !== null
                font.pixelSize: (slot.def ? 20 : 14) * strip.sc
                color: slot.def ? LockTheme.gold : LockTheme.inkFaint
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: slot.def !== null
            }

            HudPanel {
                visible: hover.containsMouse && slot.def !== null
                anchors.bottom: parent.top
                anchors.bottomMargin: 10 * strip.sc
                anchors.horizontalCenter: parent.horizontalCenter
                width: tip.implicitWidth + 24 * strip.sc
                height: tip.implicitHeight + 14 * strip.sc
                cut: 6 * strip.sc
                fill: LockTheme.panelHi
                accent: LockTheme.gold
                accentLength: 12 * strip.sc

                Column {
                    id: tip
                    anchors.centerIn: parent

                    Text {
                        text: slot.def ? slot.def.name.toUpperCase() : ""
                        font.family: LockTheme.display
                        font.pixelSize: 13 * strip.sc
                        color: LockTheme.ink
                    }

                    Text {
                        text: slot.def ? slot.def.desc : ""
                        font.family: LockTheme.mono
                        font.pixelSize: 10 * strip.sc
                        color: LockTheme.inkDim
                    }
                }
            }
        }
    }
}
