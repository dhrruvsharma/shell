pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// Chapter V, § 2: the colour scheme matugen makes from the wallpaper: light
// or dark, its kind, and its contrast. A change makes it again from the
// wallpaper there is, and every app it themes takes the new colours.
Spread {
    id: spread

    readonly property var pal: Services.Scheme

    leftContent: Plate {
        chapter: 5
        title: "Theme & Colour"
        opening: false
        section: "The palette"
        figure: "Fig. 10."
        caption: "What each kind of scheme makes of your wallpaper. Click a row to use it."

        PaletteFigure {
            anchors.fill: parent
            anchors.topMargin: 6
            lit: spread.focusKey
        }
    }

    Leaf {
        kicker: "§ 2"
        title: "The palette"
        intro: "Every colour on the desktop comes from the wallpaper. Change how it's drawn out and the shell, Hyprland, the terminal and the rest take the new colours in a moment."
        spacing: 18

        Entry {
            width: parent.width
            key: "mode"
            label: "Light or dark"

            InkChoice {
                options: [{ id: "dark", label: "Dark" }, { id: "light", label: "Light" }]
                current: spread.pal.mode
                onChosen: id => spread.pal.setMode(id)
            }
        }

        Entry {
            width: parent.width
            label: "The kind of scheme"
            stacked: true

            Column {
                spacing: 1

                Repeater {
                    model: spread.pal.schemes

                    Item {
                        id: kind

                        required property var modelData
                        readonly property bool on: spread.pal.scheme === kind.modelData.id

                        width: parent.width
                        height: 25

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered)
                                    spread.focusKey = kind.modelData.id;
                                else if (spread.focusKey === kind.modelData.id)
                                    spread.focusKey = "";
                            }
                        }

                        Rectangle {
                            id: dot
                            anchors.verticalCenter: parent.verticalCenter
                            x: 4
                            width: 14
                            height: 14
                            radius: 7
                            color: "transparent"
                            border.width: 1.2
                            border.color: kind.on ? BookStyle.accent : BookStyle.inkSoft

                            Rectangle {
                                anchors.centerIn: parent
                                width: 7
                                height: 7
                                radius: 3.5
                                color: BookStyle.accent
                                visible: kind.on
                            }
                        }

                        BookText {
                            id: kindName
                            anchors.left: dot.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 118
                            text: kind.modelData.name
                            font.family: BookStyle.ui
                            font.pixelSize: 14
                            font.weight: kind.on ? Font.DemiBold : Font.Normal
                            color: kind.on ? BookStyle.accent : BookStyle.ink
                        }

                        BookText {
                            anchors.left: kindName.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: kind.modelData.note
                            elide: Text.ElideRight
                            font.pixelSize: 13
                            font.italic: true
                            color: BookStyle.inkSoft
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: spread.pal.setScheme(kind.modelData.id)
                        }
                    }
                }
            }
        }

        Entry {
            width: parent.width
            key: "contrast"
            label: "Contrast"
            note: "Softer to the left, sharper to the right."
            controlWidth: 290

            InkSlider {
                from: -1
                to: 1
                stepSize: 0.1
                decimals: 1
                value: spread.pal.contrast
                mark: 0
                format: v => Math.abs(v) < 0.05 ? "as made" : (v > 0 ? "+" : "") + v.toFixed(1)
                onMoved: v => spread.pal.setContrast(v)
            }
        }

        InkButton {
            visible: spread.pal.custom
            icon: "restart_alt"
            text: "As matugen makes it"
            quiet: true
            onClicked: spread.pal.reset()
        }
    }
}
