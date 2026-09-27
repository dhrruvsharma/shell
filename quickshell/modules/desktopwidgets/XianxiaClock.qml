pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock
import qs.modules.lock.themes.xianxia

// Cave Abode clock face: a hanging scroll with the double-hour (shichen),
// the time cut into a seal and the date in Chinese numerals, with an English
// gloss running down beside it.
Item {
    id: root

    property date now: new Date()
    readonly property color seal: Colors.tertiary
    readonly property var hour: Xian.shichen(now)

    implicitWidth: 140
    implicitHeight: scrollCol.implicitHeight

    component Vertical: Column {
        id: vert
        property string text
        property int size: 20
        property color color: Colors.on_surface

        Repeater {
            model: vert.text.split("")

            Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                font.family: Xian.cjk
                font.pixelSize: vert.size
                color: vert.color
            }
        }
    }

    Item {
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.7
            shadowBlur: 0.7
            blurMax: 28
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Column {
            id: scrollCol
            x: 10
            width: 120
            spacing: 14

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: 34
                color: LockTheme.alpha(root.seal, 0.7)
            }

            Vertical {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hour.zh
                size: 56
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 66
                height: 66
                radius: 5
                rotation: -3
                color: root.seal

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: LockTheme.alpha(Colors.on_tertiary, 0.55)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -4

                    Repeater {
                        model: [Qt.formatDateTime(root.now, "hh"), Qt.formatDateTime(root.now, "mm")]

                        Text {
                            required property string modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData
                            font.family: Xian.serif
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: Colors.on_tertiary
                        }
                    }
                }
            }

            Vertical {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Xian.chineseDate(root.now)
                size: 21
                color: LockTheme.alpha(Colors.on_surface, 0.8)
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: 34
                color: LockTheme.alpha(root.seal, 0.7)
            }
        }

        Text {
            x: 128
            y: 120
            transformOrigin: Item.TopLeft
            rotation: 90
            text: (root.hour.en + " · " + Qt.formatDateTime(root.now, "h:mm ap")).toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 12
            font.letterSpacing: 4
            color: LockTheme.alpha(Colors.on_surface, 0.62)
        }
    }
}
