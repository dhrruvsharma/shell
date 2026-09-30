import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services
import qs.colors
import qs.Core
import QtQuick.Layouts
import qs.components

// The volume / brightness OSD, in a small click-through surface of its own
// that exists only while it shows. (It used to live in the full-screen panel
// surface, which then had to stay mapped and repaint whole for it.)
PanelWindow {
    id: root
    visible: Services.Osd.visible

    anchors.bottom: true
    margins.bottom: 60
    exclusionMode: ExclusionMode.Ignore
    // No layer animation from Hyprland (hypr/quickshell.lua): the card fades
    // itself in, and used to vanish at once.
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}

    implicitWidth: 360
    implicitHeight: 100

    Card {
        anchors.fill: parent
        radius: Services.DesktopTheme.rad(20)

        PanelDecor {
            radius: Services.DesktopTheme.rad(20)
        }
        color: Colors.surface_container_high
        opacity: Services.Osd.visible ? 1.0 : 0.0

        layer.enabled: true
        layer.smooth: true

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Row {
            anchors {
                fill: parent
                margins: 24
            }
            spacing: 20

            // Icon column
            Rectangle {
                width: 52
                height: 52
                radius: Services.DesktopTheme.rad(12)
                color: Colors.primary_container
                anchors.verticalCenter: parent.verticalCenter

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Services.Osd.type === "volume" ? getVolumeIcon() : Icons.brightness
                    font.pixelSize: 28
                    color: Colors.on_primary_container
                }
            }

            // Content column
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                width: parent.width - 52 - 20

                // Title and percentage row
                Row {
                    width: parent.width
                    spacing: 8

                    StyledText {
                        text: Services.Osd.type === "volume" ? "Volume" : "Brightness"
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 180
                        height: 1
                    }

                    StyledText {
                        text: Math.min(Math.round(Services.Osd.value), 100) + "%"
                        color: Colors.on_surface_variant
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Progress bar
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: Services.DesktopTheme.rad(4)
                    color: Colors.surface_container_highest

                    Rectangle {
                        height: parent.height
                        radius: Services.DesktopTheme.rad(4)
                        width: parent.width * Math.min(Math.max(Services.Osd.value, 0), 100) / 100
                        color: Colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Shimmer effect on the fill
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.1) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }
                }
            }
        }
    }

    function getVolumeIcon() {
        let vol = Services.Osd.value
        if (Services.Audio && Services.Audio.muted) return Icons.volumeMuted
        if (vol === 0) return Icons.volumeZero
        if (vol < 33) return Icons.volumeLow
        if (vol < 66) return Icons.volumeMedium
        return Icons.volumeHigh
    }
}