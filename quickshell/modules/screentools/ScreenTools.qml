import QtQuick
import Quickshell
import qs.components
import qs.colors
import qs.services as Services
import qs.modules.lock

// Record and screenshot buttons, side by side; stacked beside a standing
// bar (`vertical`). Recording goes through services/ScreenRecord (the edge
// line's pill has the same tools): over the buttons, whether it records
// and for how long, and whether the system's sound goes in (a click
// switches it for the next recording; wf-recorder only records sound it's
// given a source for).
Item {
    id: root

    property bool vertical: false

    width: root.vertical ? 188 : 340
    height: root.vertical ? 214 : 110
    readonly property var rec: Services.ScreenRecord
    readonly property bool recording: root.rec.recording
    property bool hoveredRecord: false
    property bool hoveredScreenshot: false

    Component.onCompleted: root.rec.look()

    Card {
        anchors.fill: parent
        anchors.margins: 6
        radius: 12

        Rectangle {
            id: recordingIndicator
            visible: root.recording
            width: 8
            height: 8
            radius: 4
            color: Colors.error
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12

            SequentialAnimation on opacity {
                running: recordingIndicator.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: root.vertical ? 10 : 9

            // What it's doing, and the sound: side by side, or one over
            // the other beside a standing bar.
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.vertical ? 1 : 3
                columnSpacing: 8
                rowSpacing: 6
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                StyledText {
                    text: root.recording ? "● Recording " + root.rec.clock : root.rec.starting ? "Starting…" : "Capture"
                    color: root.recording ? Colors.error : Colors.on_surface_variant
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    opacity: root.recording ? 1 : 0.7
                }

                StyledText {
                    visible: !root.vertical
                    text: "·"
                    color: Colors.on_surface_variant
                    font.pixelSize: 11
                    opacity: 0.5
                }

                // The system's sound in the recording: for the next one (a
                // click), or what the one going on has.
                ClickableRect {
                    id: soundChip
                    readonly property bool on: root.recording ? root.rec.soundNow : root.rec.withSound
                    width: soundRow.implicitWidth + 16
                    height: 22
                    radius: 11
                    interactive: !root.recording && !root.rec.starting
                    color: soundChip.hovered && soundChip.interactive ? Colors.withAlpha(Colors.primary, 0.16) : "transparent"
                    border.width: 1
                    border.color: soundChip.on ? Colors.withAlpha(Colors.primary, 0.6) : Colors.withAlpha(Colors.outline, 0.5)
                    opacity: soundChip.interactive ? 1 : 0.6
                    cursorShape: soundChip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.rec.toggleSound()

                    Row {
                        id: soundRow
                        anchors.centerIn: parent
                        spacing: 4

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: soundChip.on ? "volume_up" : "volume_off"
                            font.pixelSize: 14
                            color: soundChip.on ? Colors.primary : Colors.on_surface_variant
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: soundChip.on ? "System sound" : "No sound"
                            color: soundChip.on ? Colors.primary : Colors.on_surface_variant
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.vertical ? 1 : 2
                spacing: 12

                ClickableRect {
                    width: root.vertical ? 156 : 140
                    height: 52
                    radius: 10
                    color: root.recording
                        ? (hoveredRecord ? Qt.lighter(Colors.error_container, 1.15) : Colors.error_container)
                        : (hoveredRecord ? Qt.lighter(Colors.primary_container, 1.2) : Colors.primary_container)
                    border.color: root.recording ? Colors.error : Colors.primary
                    border.width: hoveredRecord ? 1.5 : 1
                    opacity: root.rec.starting ? 0.6 : 1

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    scale: hoveredRecord ? 1.03 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 18
                            height: 18
                            radius: root.recording ? 3 : 9
                            color: root.recording ? Colors.error : Colors.primary
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on radius { NumberAnimation { duration: 180 } }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.recording ? "Stop" : "Record"
                            color: root.recording ? Colors.on_error_container : Colors.on_primary_container
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    cursorShape: Qt.PointingHandCursor
                    onEntered: hoveredRecord = true
                    onExited: hoveredRecord = false
                    onClicked: root.rec.toggle()
                }

                ClickableRect {
                    width: root.vertical ? 156 : 140
                    height: 52
                    radius: 10
                    color: hoveredScreenshot
                        ? Qt.lighter(Colors.tertiary_container, 1.2)
                        : Colors.tertiary_container
                    border.color: Colors.tertiary
                    border.width: hoveredScreenshot ? 1.5 : 1

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    scale: hoveredScreenshot ? 1.03 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // Camera icon
                        Item {
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 18
                                height: 14
                                radius: 3
                                color: "transparent"
                                border.color: Colors.tertiary
                                border.width: 1.5
                                anchors.centerIn: parent

                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Colors.tertiary
                                    anchors.centerIn: parent
                                }

                                Rectangle {
                                    width: 6
                                    height: 3
                                    radius: 1
                                    color: Colors.tertiary
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: -1
                                }
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Screenshot"
                            color: Colors.on_tertiary_container
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    cursorShape: Qt.PointingHandCursor
                    onEntered: hoveredScreenshot = true
                    onExited: hoveredScreenshot = false
                    onClicked: {
                            // (the panel goes first, out of the shot)
                            Quickshell.execDetached(["sh", "-c", "qs ipc call systemPanel toggle && \"$0\" copysave area", Quickshell.shellPath("scripts/screenshot")])
                            screenshotFlash.opacity = 1.0
                        }
                }
            }
        }

        Rectangle {
            id: screenshotFlash
            anchors.fill: parent
            radius: 12
            color: "white"
            opacity: 0

            Behavior on opacity {
                SequentialAnimation {
                    NumberAnimation { duration: 80 }
                    PauseAnimation { duration: 40 }
                    NumberAnimation { to: 0; duration: 180 }
                }
            }
        }
    }
}
