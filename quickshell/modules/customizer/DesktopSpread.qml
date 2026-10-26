pragma ComponentBehavior: Bound
import QtQuick
import qs.settings
import qs.services as Services

// Chapter VI: what lies on the desktop (the widgets and the visualizer) and
// how a new wallpaper comes in.
Spread {
    id: spread

    readonly property var dw: Services.DesktopWidgets

    leftContent: Plate {
        chapter: 6
        title: "The Desktop"
        epigraph: "What lies on the wallpaper, and how a new one comes in."
        figure: "Fig. 11."
        caption: "Your desktop's widgets where they stand; the ones put away wait in their places. Click one to put it out or away."

        DesktopFigure {
            anchors.fill: parent
            anchors.topMargin: 8
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Widgets and wallpaper"
        intro: "Small things to keep on the wallpaper, each dressed by the desktop theme, and the way a new wallpaper arrives."
        spacing: 18

        Entry {
            width: parent.width
            label: "On the desktop"
            stacked: true

            Column {
                spacing: 4

                Repeater {
                    model: spread.dw.widgets

                    Tick {
                        required property var modelData
                        width: parent.width
                        key: modelData.id
                        icon: modelData.icon
                        label: modelData.name
                        note: modelData.description
                        checked: spread.dw.enabled(modelData.id)
                        onToggled: spread.dw.toggle(modelData.id)
                    }
                }
            }
        }

        Row {
            spacing: 22

            InkButton {
                icon: "restart_alt"
                text: "Back where they started"
                quiet: true
                onClicked: spread.dw.resetPositions()
            }

            InkButton {
                icon: "graphic_eq"
                text: "Shape the visualizer"
                quiet: true
                onClicked: Services.Customizer.openPanel("cava")
            }
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Entry {
            width: parent.width
            key: "animateChoice"
            label: "A new wallpaper grows in"
            note: "In the picker (SUPER+W), the card you choose grows into the wallpaper; off, it's set at once."

            InkSwitch {
                checked: SettingsConfig.wallpaperAnimateChoice
                onToggled: SettingsConfig.wallpaperAnimateChoice = !SettingsConfig.wallpaperAnimateChoice
            }
        }

        Entry {
            width: parent.width
            key: "folder"
            label: "Wallpapers from"
            note: SettingsConfig.wallpaperDir

            InkButton {
                icon: "wallpaper"
                text: "The picker"
                onClicked: Services.Customizer.openPanel("wallpaper")
            }
        }
    }
}
