pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock.themes.wasteland
import qs.services as Services

// Wasteland clock face: a scrap plate bolted up with hazard tape along its
// top, the time stencilled on it, the day of the long year, which watch it
// is on a strip of masking tape, and a safety sign counting the days
// without incident (the unlock streak).
Item {
    id: root

    property date now: new Date()
    readonly property var hm: Qt.formatDateTime(now, "h:mm AP").split(" ")

    implicitWidth: plate.width
    implicitHeight: plate.height

    Item {
        id: plate
        width: col.implicitWidth + 52
        height: col.implicitHeight + 46

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.6
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 4
        }

        ScrapPlate {
            anchors.fill: parent
            seed: 9
            rust: 0.75
            rivetInset: 10
            rivetSize: 7
        }

        HazardStripes {
            x: 24
            y: 0
            width: parent.width - 48
            height: 9
            stripe: 7
            colorA: Waste.hazard
            colorB: Waste.grime
        }

        Column {
            id: col
            x: 26
            y: 22
            spacing: 2

            Row {
                spacing: 10

                Text {
                    id: time
                    text: root.hm[0]
                    font.family: Waste.stencil
                    font.pixelSize: 84
                    font.weight: Font.Bold
                    color: Waste.bone
                }

                Text {
                    anchors.baseline: time.baseline
                    text: root.hm[1] ?? ""
                    font.family: Waste.stencilCond
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    color: Waste.hazard
                }
            }

            Text {
                text: "DAY " + Clocks.dayOfYear(root.now) + "  ·  " + Qt.formatDate(root.now, "ddd d MMM yyyy").toUpperCase()
                font.family: Waste.stencilCond
                font.pixelSize: 20
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Waste.hazard
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                spacing: 14

                // Which watch it is, on masking tape.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: watch.implicitWidth + 18
                    height: watch.implicitHeight + 6
                    rotation: -1.5
                    color: Waste.tape
                    opacity: 0.95

                    Text {
                        id: watch
                        anchors.centerIn: parent
                        text: Waste.watch(root.now).toLowerCase()
                        font.family: Waste.type
                        font.pixelSize: 13
                        color: Waste.tapeInk
                    }
                }

                // The safety sign.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: count.implicitWidth + 12
                        height: count.implicitHeight + 2
                        color: Waste.bone

                        Text {
                            id: count
                            anchors.centerIn: parent
                            text: Services.LockStats.liveStreak
                            font.family: Waste.stencilCond
                            font.pixelSize: 18
                            font.weight: Font.Black
                            color: Services.LockStats.liveStreak > 0 ? "#2f6b2a" : Waste.danger
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DAYS WITHOUT\nINCIDENT"
                        lineHeight: 0.85
                        font.family: Waste.cond
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        color: Waste.bone
                    }
                }
            }
        }
    }
}
