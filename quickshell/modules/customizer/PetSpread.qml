pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.pet
import qs.services as Services

// Chapter VIII: the pet that walks the bar: whether it's there, what it
// is, its coat and name, how much it talks, where it roams, and whether it
// sleeps at night. (Its tricks and reminders are in its hub, SUPER+space.)
Spread {
    id: spread

    readonly property var pet: Services.Pet

    leftContent: Plate {
        chapter: 8
        title: "The Companion"
        epigraph: "It walks the bar, naps, and remembers who feeds it."
        figure: "Fig. 13."
        caption: spread.pet.name + ", your " + spread.pet.species + ": " + spread.pet.bond + ", and " + (spread.pet.moodWords[spread.pet.mood] ?? spread.pet.mood) + ". Click it."

        Item {
            anchors.fill: parent

            Rectangle {
                id: ground
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.72
                width: parent.width * 0.7
                height: 18
                radius: 9
                color: Colors.withAlpha(BookStyle.ink, 0.08)
            }

            PetPortrait {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: ground.verticalCenter
                width: 260
                height: 220
                opacity: spread.pet.shown ? 1 : 0.4
            }

            BookText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: ground.bottom
                anchors.topMargin: 20
                text: spread.pet.name
                font.family: BookStyle.display
                font.pixelSize: 30
            }

            BookText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: ground.bottom
                anchors.topMargin: 62
                text: "Level " + spread.pet.level + " · " + spread.pet.bond
                font.italic: true
                font.pixelSize: 14
                color: BookStyle.inkSoft
            }
        }
    }

    Leaf {
        kicker: "§ 1"
        title: "Your pet"
        intro: "A small friend on the bar. Its tricks, reminders and treats are in its hub (SUPER+space)."
        spacing: 18

        Entry {
            width: parent.width
            key: "shown"
            label: "On the bar"

            InkSwitch {
                checked: spread.pet.shown
                onToggled: spread.pet.setShown(!spread.pet.shown)
            }
        }

        Entry {
            width: parent.width
            key: "species"
            label: "It's a"

            InkChoice {
                options: [{ id: "cat", label: "Cat" }, { id: "fox", label: "Fox" }, { id: "bunny", label: "Bunny" }]
                current: spread.pet.species
                onChosen: id => spread.pet.setSpecies(id)
            }
        }

        Entry {
            width: parent.width
            key: "fur"
            label: "Its coat"
            stacked: true

            Row {
                spacing: 12

                Repeater {
                    model: spread.pet.furNames

                    Column {
                        id: coat

                        required property string modelData
                        readonly property bool on: spread.pet.fur === coat.modelData
                        readonly property color base: coat.modelData === "theme" ? Qt.hsla(Math.max(0, Qt.color(Services.DesktopTheme.accent).hslHue), 0.5, 0.8, 1)
                            : coat.modelData === "natural" ? (spread.pet.furs[spread.pet.species === "fox" ? "fox" : spread.pet.species === "bunny" ? "white" : "cream"].base)
                            : spread.pet.furs[coat.modelData].base

                        spacing: 4

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30
                            height: 30
                            radius: 15
                            color: coat.base
                            border.width: coat.on ? 2.5 : 1
                            border.color: coat.on ? BookStyle.accent : BookStyle.line

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: spread.pet.setFur(coat.modelData)
                            }
                        }

                        BookText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: coat.modelData
                            font.pixelSize: 11
                            font.italic: !coat.on
                            color: coat.on ? BookStyle.accent : BookStyle.inkSoft
                        }
                    }
                }
            }
        }

        Entry {
            width: parent.width
            key: "name"
            label: "Its name"
            controlWidth: 220

            Item {
                implicitWidth: 220
                implicitHeight: 30

                TextInput {
                    id: nameField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: spread.pet.name
                    maximumLength: 24
                    color: BookStyle.ink
                    selectionColor: BookStyle.accent
                    selectedTextColor: BookStyle.onAccent
                    font.family: BookStyle.body
                    font.pixelSize: 16
                    horizontalAlignment: TextInput.AlignRight
                    onEditingFinished: spread.pet.setName(text)
                }

                Rectangle {
                    anchors.top: nameField.bottom
                    anchors.topMargin: 3
                    width: parent.width
                    height: 1
                    color: nameField.activeFocus ? BookStyle.accent : BookStyle.line
                }
            }
        }

        Entry {
            width: parent.width
            key: "chatty"
            label: "It talks"

            InkChoice {
                options: [{ id: "0", label: "Rarely" }, { id: "1", label: "Now and then" }, { id: "2", label: "A lot" }]
                current: String(spread.pet.chatty)
                spacing: 14
                onChosen: id => spread.pet.setChatty(Number(id))
            }
        }

        Entry {
            width: parent.width
            key: "roam"
            label: "It roams"
            stacked: true

            InkChoice {
                options: [{ id: "bar", label: "The whole bar" }, { id: "left", label: "The left" }, { id: "right", label: "The right" }, { id: "still", label: "Stays put" }]
                current: spread.pet.roam
                spacing: 14
                onChosen: id => spread.pet.setRoam(id)
            }
        }

        Entry {
            width: parent.width
            key: "sleep"
            label: "Sleeps at night"
            note: "Curls up from eleven till six."

            InkSwitch {
                checked: spread.pet.sleepAtNight
                onToggled: spread.pet.setSleepAtNight(!spread.pet.sleepAtNight)
            }
        }
    }
}
