pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// Chapter VII: notifications (do not disturb, how long a toast stays) and
// the night light (on or off, and how warm).
Spread {
    id: spread

    readonly property var nt: Services.Notification
    readonly property var nl: Services.NightLight

    // A light's colour at `k` kelvin (Tanner Helland's fit).
    function kelvin(k) {
        const t = k / 100;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const c = v => Math.max(0, Math.min(255, v)) / 255;
        return Qt.rgba(c(r), c(g), c(b), 1);
    }

    leftContent: Plate {
        chapter: 7
        title: "Notices"
        epigraph: "What may interrupt you, for how long, and the light you work by at night."
        figure: "Fig. 12."
        caption: spread.nt.dnd ? "Toasts held back: they wait in the control centre." : "A toast, and how long it stays; below, the night light's warmth."

        Item {
            anchors.fill: parent

            // A toast, its time running out along its foot.
            Rectangle {
                id: toast
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                width: Math.min(parent.width - 60, 420)
                height: 96
                radius: Math.min(BookStyle.b.radius ?? 6, 12) + 4
                color: Colors.surface_container
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                opacity: spread.nt.dnd ? 0.45 : 1

                Rectangle {
                    id: badge
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 12
                    color: Colors.primary_container

                    Glyph {
                        anchors.centerIn: parent
                        text: "mail"
                        filled: true
                        font.pixelSize: 22
                        color: Colors.on_primary_container
                    }
                }

                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "A message for you"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Colors.on_surface
                    }

                    Text {
                        width: parent.width
                        text: "It stays " + spread.nt.toastSeconds + " seconds, unless its app says otherwise."
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        color: Colors.on_surface_variant
                    }
                }

                // The time it has left.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    x: 16
                    height: 3
                    radius: 1.5
                    color: Colors.primary
                    width: (toast.width - 32) * runOut.left

                    QtObject {
                        id: runOut
                        property real left: 1
                    }

                    NumberAnimation {
                        target: runOut
                        property: "left"
                        from: 1
                        to: 0
                        duration: spread.nt.toastSeconds * 1000
                        loops: Animation.Infinite
                        running: !spread.nt.dnd
                    }
                }
            }

            // Do not disturb, stamped across it.
            Rectangle {
                visible: spread.nt.dnd
                anchors.centerIn: toast
                rotation: -8
                width: stamp.implicitWidth + 24
                height: 34
                color: "transparent"
                border.width: 2
                border.color: BookStyle.accent

                BookText {
                    id: stamp
                    anchors.centerIn: parent
                    text: "Do not disturb"
                    font.family: BookStyle.display
                    font.pixelSize: 18
                    font.capitalization: Font.AllUppercase
                    color: BookStyle.accent
                }
            }

            // The night light: a sky from day to night, its warmth marked.
            Item {
                id: sky
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: toast.bottom
                anchors.topMargin: 54
                width: Math.min(parent.width - 60, 420)
                height: 150
                opacity: spread.nl.available ? 1 : 0.5

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: spread.kelvin(2500) }
                        GradientStop { position: 0.5; color: spread.kelvin(4500) }
                        GradientStop { position: 1; color: spread.kelvin(6500) }
                    }
                    opacity: 0.85
                }

                Rectangle {
                    readonly property real f: (spread.nl.temperature - spread.nl.warmest) / (spread.nl.coolest - spread.nl.warmest)
                    x: Math.max(0, Math.min(sky.width - width, sky.width * f - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 70
                    radius: 35
                    color: spread.kelvin(spread.nl.temperature)
                    border.width: 3
                    border.color: spread.nl.enabled ? BookStyle.accent : "#ffffff"

                    Glyph {
                        anchors.centerIn: parent
                        text: spread.nl.enabled ? "bedtime" : "light_mode"
                        filled: true
                        font.pixelSize: 28
                        color: "#3a2a12"
                    }
                }

                BookText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 10
                    text: spread.nl.available ? (spread.nl.enabled ? "On, at " + spread.nl.temperature + " K" : "Off; it would be " + spread.nl.temperature + " K") : "Needs hyprsunset"
                    font.italic: true
                    font.pixelSize: 13
                    color: BookStyle.inkSoft
                }
            }
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Notices and the night"
        intro: "Notifications come as toasts in the corner and wait in the control centre. Do not disturb holds the toasts back; the night light warms the screen after dark."
        spacing: 22

        Entry {
            width: parent.width
            key: "dnd"
            label: "Do not disturb"
            note: "No toasts, but for critical ones; everything still waits in the control centre."

            InkSwitch {
                checked: spread.nt.dnd
                onToggled: spread.nt.setDnd(!spread.nt.dnd)
            }
        }

        Entry {
            width: parent.width
            key: "toast"
            label: "A toast stays"
            note: "When its app doesn't say how long. Pointing at one holds it."
            controlWidth: 290

            InkSlider {
                from: 2
                to: 30
                stepSize: 1
                unit: "s"
                value: spread.nt.toastSeconds
                mark: 5
                onMoved: v => spread.nt.setToastSeconds(v)
            }
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Entry {
            width: parent.width
            key: "night"
            label: "Night light"
            note: spread.nl.available ? "Warms the whole screen, through hyprsunset." : "It needs hyprsunset: sudo pacman -S hyprsunset"
            dim: !spread.nl.available

            InkSwitch {
                checked: spread.nl.enabled
                onToggled: spread.nl.setEnabled(!spread.nl.enabled)
            }
        }

        Entry {
            width: parent.width
            key: "warmth"
            label: "Its warmth"
            note: "Candlelight at the left, daylight at the right."
            controlWidth: 290
            dim: !spread.nl.available

            InkSlider {
                from: spread.nl.warmest
                to: spread.nl.coolest
                stepSize: 100
                unit: "K"
                readoutWidth: 76
                value: spread.nl.temperature
                onMoved: v => spread.nl.setTemperature(v)
            }
        }
    }
}
