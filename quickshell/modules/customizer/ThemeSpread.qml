pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock
import qs.services as Services

// Chapter V, § 1: the desktop theme, taken down from a shelf of them, what
// it changes, its screen effect, and whether the lock screen follows it.
Spread {
    id: spread

    readonly property var dt: Services.DesktopTheme
    readonly property var cur: spread.dt.current

    leftContent: Plate {
        chapter: 5
        title: "Theme & Colour"
        epigraph: "Sixteen bindings for one desktop, each with its own hand."
        figure: "Fig. 9."
        caption: "The themes on their shelf. Take one down to dress the desktop in it, and this book with it."

        ShelfFigure {
            anchors.fill: parent
            anchors.topMargin: 16
        }
    }

    Leaf {
        kicker: "§ 1"
        title: spread.cur ? spread.cur.name : "No theme"
        intro: spread.cur ? spread.cur.description : "The shell as it comes: the wallpaper's colours on plain, rounded surfaces. Take a theme down from the shelf opposite to dress the whole desktop in one style."
        spacing: 18

        // What the theme changes.
        Column {
            width: parent.width
            spacing: 7
            visible: spread.cur !== null

            Repeater {
                model: spread.cur ? spread.cur.changes.slice(0, 5) : []

                Row {
                    required property var modelData
                    width: parent.width
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.icon
                        font.pixelSize: 17
                        color: BookStyle.accent
                    }

                    BookText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        text: modelData.text
                        wrapMode: Text.WordWrap
                        font.pixelSize: BookStyle.bodySize - 1
                    }
                }
            }
        }

        Rule {
            width: parent.width
            kind: "single"
        }

        Entry {
            width: parent.width
            key: "effect"
            label: "Screen effect"
            note: spread.cur ? (spread.dt.screenEffect === "strong" ? spread.cur.effects.strong : spread.cur.effects.subtle) : "A theme's grade over the whole screen."
            dim: !spread.dt.enabled

            InkChoice {
                options: [{ id: "off", label: "Off" }, { id: "subtle", label: "Subtle" }, { id: "strong", label: "Strong" }]
                current: spread.dt.screenEffect
                spacing: 14
                onChosen: id => spread.dt.setScreenEffect(id)
            }
        }

        Entry {
            width: parent.width
            key: "matchLock"
            label: "The lock screen follows it"
            note: "Each theme has a lock screen of its own; this locks you in the theme's."

            InkSwitch {
                checked: spread.dt.matchLock
                onToggled: spread.dt.setMatchLock(!spread.dt.matchLock)
            }
        }

        Row {
            spacing: 22

            InkButton {
                icon: "preview"
                text: "Previews in the Themes panel"
                onClicked: Services.Customizer.openPanel("themes")
            }

            InkButton {
                icon: "lock"
                text: "Lock screens"
                quiet: true
                onClicked: Services.Customizer.openPanel("lockscreen")
            }
        }
    }
}
