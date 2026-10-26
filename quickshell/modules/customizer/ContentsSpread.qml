pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.modules.desktoptheme
import qs.modules.lock
import qs.services as Services

// The book's first spread: the frontispiece (its title, an engraved
// medallion with the theme's emblem, whose book it is) and the contents,
// every chapter and section with its page; a click on one turns to it.
Spread {
    id: spread

    leftContent: Item {
        anchors.fill: parent

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            width: parent.width
            spacing: 14

            BookText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: BookStyle.b.title
                wrapMode: Text.WordWrap
                font.family: /[^\x00-\x7f]/.test(BookStyle.b.title) ? BookStyle.cjk : BookStyle.display
                font.pixelSize: /[^\x00-\x7f]/.test(BookStyle.b.title) ? 66 : BookStyle.b.title.length > 14 ? 38 : 48
                color: BookStyle.ink
                lineHeight: 0.95
            }

            BookText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: BookStyle.b.subtitle
                wrapMode: Text.WordWrap
                font.italic: true
                font.pixelSize: BookStyle.bodySize + 2
                color: BookStyle.inkSoft
            }

            Fleuron {
                anchors.horizontalCenter: parent.horizontalCenter
                span: 110
            }
        }

        // The medallion: engraved rings, graduated like an instrument's
        // limb, the theme's emblem at its heart.
        Item {
            id: medal
            anchors.horizontalCenter: parent.horizontalCenter
            y: 250
            width: 300
            height: 300

            Repeater {
                model: 3

                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: medal.width - index * 34
                    height: width
                    radius: width / 2
                    color: index === 2 ? Colors.withAlpha(BookStyle.accent, 0.06) : "transparent"
                    border.width: index === 0 ? 1.5 : 1
                    border.color: index === 1 ? Colors.withAlpha(BookStyle.ink, 0.35) : Colors.withAlpha(BookStyle.ink, 0.6)
                }
            }

            Repeater {
                model: 72

                Rectangle {
                    required property int index
                    x: medal.width / 2 - width / 2
                    y: 1
                    width: 1
                    height: index % 6 === 0 ? 14 : 7
                    color: index % 6 === 0 ? BookStyle.accent : Colors.withAlpha(BookStyle.ink, 0.5)
                    transform: Rotation {
                        origin.x: 0.5
                        origin.y: medal.height / 2 - 1
                        angle: index * 5
                    }
                }
            }

            Emblem {
                anchors.centerIn: parent
                size: 92
            }

            BookText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 16
                text: Services.DesktopTheme.current?.name ?? "No theme"
                font.family: BookStyle.ui
                font.pixelSize: 13
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
                color: BookStyle.inkSoft
            }
        }

        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width
            spacing: 6

            Rule {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160
                kind: "single"
            }

            BookText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Kept by " + (Quickshell.env("USER") || "you") + " · in the year " + Clocks.roman(new Date().getFullYear())
                font.pixelSize: BookStyle.bodySize - 1
                font.italic: true
                color: BookStyle.inkSoft
            }
        }
    }

    // ── Contents ─────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        BookText {
            id: heading
            width: parent.width
            text: "Contents"
            font.family: BookStyle.display
            font.pixelSize: 34
        }

        Rule {
            id: headRule
            anchors.top: heading.bottom
            anchors.topMargin: 12
            width: parent.width
        }

        Column {
            anchors.top: headRule.bottom
            anchors.topMargin: 14
            width: parent.width
            spacing: 3

            Repeater {
                model: BookContents.chapters

                Column {
                    id: chapterBlock

                    required property var modelData
                    readonly property var sections: BookContents.spreads.map((s, i) => ({ s: s, i: i })).filter(e => e.s.chapter === chapterBlock.modelData.n)

                    width: parent.width
                    spacing: 1

                    Line {
                        width: parent.width
                        numeral: BookStyle.roman(chapterBlock.modelData.n).toUpperCase()
                        title: chapterBlock.modelData.title
                        page: BookContents.pageOf(chapterBlock.sections[0].i)
                        target: chapterBlock.sections[0].i
                        major: true
                    }

                    Repeater {
                        model: chapterBlock.sections

                        Line {
                            required property var modelData
                            width: chapterBlock.width
                            title: modelData.s.section
                            page: BookContents.pageOf(modelData.i) + 1
                            target: modelData.i
                            major: false
                        }
                    }

                    Item {
                        width: 1
                        height: 4
                    }
                }
            }
        }

        BookText {
            anchors.bottom: parent.bottom
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Turn a page at its lower corner, or by the tabs on the book's edges. The ribbon brings you back here. ← → turn pages, 1–8 open a chapter, Esc closes."
            wrapMode: Text.WordWrap
            font.italic: true
            font.pixelSize: BookStyle.bodySize - 2
            color: BookStyle.inkSoft
        }
    }

    // A line of the contents: a chapter (its numeral and title) or one of
    // its sections, a dotted leader, and the page it starts on.
    component Line: Item {
        id: line

        property string numeral: ""
        property string title: ""
        property int page: 0
        property int target: 0
        property bool major: false

        height: line.major ? 27 : 21

        Row {
            id: lead
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            BookText {
                width: 44
                visible: line.major
                text: line.numeral
                font.family: BookStyle.numeral
                font.pixelSize: 17
                color: BookStyle.accent
            }

            Item {
                visible: !line.major
                width: 56
                height: 1
            }

            BookText {
                id: name
                text: line.title
                font.family: line.major ? BookStyle.ui : BookStyle.body
                font.pixelSize: line.major ? 16 : BookStyle.bodySize - 1
                font.weight: line.major ? Font.DemiBold : Font.Normal
                font.italic: !line.major
                color: area.containsMouse ? BookStyle.accent : line.major ? BookStyle.ink : BookStyle.inkSoft
            }
        }

        // The leader: dots from the title to the page.
        Row {
            anchors.left: lead.right
            anchors.leftMargin: 8
            anchors.right: pageNo.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            spacing: 5
            clip: true

            Repeater {
                model: 60

                Rectangle {
                    width: 2
                    height: 2
                    radius: 1
                    color: BookStyle.inkFaint
                }
            }
        }

        BookText {
            id: pageNo
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: BookStyle.roman(line.page)
            font.pixelSize: line.major ? 15 : 14
            color: area.containsMouse ? BookStyle.accent : BookStyle.inkSoft
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (spread.book) spread.book.go(line.target)
        }
    }
}
