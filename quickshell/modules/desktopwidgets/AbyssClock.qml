pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock.themes.abyss

// Abyss clock face: a diver's watch glowing in the dark, and beside it the
// time in the boat's instrument type, how deep the hour runs (noon at
// periscope depth, midnight at the bottom of the Challenger Deep) and which
// zone of the ocean that is, the water's temperature and pressure there on
// a depth tape, and the date.
Item {
    id: root

    property date now: new Date()
    readonly property real metres: Deep.depthAt(now)
    readonly property var zone: Deep.zoneAt(metres)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Row {
        id: body
        spacing: 24

        DiveDial {
            anchors.verticalCenter: parent.verticalCenter
            width: 214
            height: 214
            hour: root.now.getHours() % 12 + root.now.getMinutes() / 60
            minute: root.now.getMinutes()
            lower: "−" + Deep.metres(root.metres)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
                shadowBlur: 0.7
                blurMax: 24
                shadowHorizontalOffset: 2
                shadowVerticalOffset: 4
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.8
                shadowBlur: 0.8
                blurMax: 28
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            ZoneGauge {
                anchors.verticalCenter: parent.verticalCenter
                height: info.implicitHeight - 8
                metres: root.metres
            }

            Column {
                id: info
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: Qt.formatTime(root.now, "HH:mm")
                    font.family: Deep.display
                    font.pixelSize: 62
                    color: Deep.foam
                }

                Text {
                    text: "−" + Deep.metres(root.metres) + "  ·  " + root.zone.name.toUpperCase()
                    font.family: Deep.ui
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Deep.lume
                }

                Text {
                    text: Deep.temperature(root.metres).toFixed(1) + " °C  ·  " + Math.round(Deep.pressure(root.metres)) + " ATM  ·  " + root.zone.latin.toUpperCase()
                    font.family: Deep.mono
                    font.pixelSize: 13
                    color: Deep.alpha(Deep.foam, 0.7)
                }

                Text {
                    topPadding: 4
                    text: Qt.formatDate(root.now, "ddd d MMM yyyy").toUpperCase()
                    font.family: Deep.ui
                    font.pixelSize: 13
                    font.letterSpacing: 2.5
                    color: Deep.glow
                }
            }
        }
    }
}
