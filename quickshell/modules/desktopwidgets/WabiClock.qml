pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock.themes.wabisabi

// Wabi-sabi clock face: the time inside an ensō, the date in the old
// calendar read down two columns (month and day, then the Reiwa year), and
// the solar term under it all.
Item {
    id: root

    property date now: new Date()
    readonly property color ink: Qt.tint(Colors.on_surface, Qt.rgba(0.93, 0.84, 0.66, 0.22))
    readonly property var kou: Wabi.season72(now)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    component Column1: Column {
        id: vert
        property string text
        property int size: 22
        property color color: root.ink

        Repeater {
            model: vert.text.split("")

            Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                font.family: Wabi.serif
                font.pixelSize: vert.size
                color: vert.color
            }
        }
    }

    Column {
        id: body
        spacing: 10

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.75
            shadowBlur: 0.9
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Row {
            spacing: 18

            Item {
                width: 236
                height: 236

                Enso {
                    anchors.fill: parent
                    inkColor: root.ink
                    opacity: 0.92
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, "h:mm")
                        font.family: Wabi.serif
                        font.weight: Font.Light
                        font.pixelSize: 52
                        color: root.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (root.now.getHours() < 12 ? "午前" : "午後") + "  ·  " + Wabi.weekdays[root.now.getDay()]
                        font.family: Wabi.serif
                        font.pixelSize: 14
                        font.letterSpacing: 1
                        color: Colors.withAlpha(root.ink, 0.72)
                    }
                }
            }

            // Read right to left: the year, then the month and day.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                layoutDirection: Qt.RightToLeft

                Column1 {
                    text: Wabi.eraYear(root.now)
                    size: 15
                    color: Colors.withAlpha(root.ink, 0.62)
                }

                Column1 {
                    text: Wabi.date(root.now)
                }
            }
        }

        Text {
            x: 22
            text: root.kou.sekki.ja + "  ·  " + root.kou.sekki.en.toLowerCase() + "  ·  " + Wabi.months[root.now.getMonth()].en.toLowerCase()
            font.family: Wabi.serif
            font.pixelSize: 14
            font.letterSpacing: 0.5
            color: Wabi.accent
        }
    }
}
