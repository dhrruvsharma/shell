pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The bar, § 2: its form (a pill for each widget, one strip the length of
// the bar, or one pill floating clear of the screen's edge and sides, and
// then how far in from the sides), the colour of its containers and of
// their text (a tone of the wallpaper's scheme, or one picked by hand),
// their transparency and an outline, with how well the text reads on them.
Spread {
    id: spread

    readonly property var bs: Services.BarSettings
    // What the colour section colours: "fill" or "ink".
    property string target: "fill"
    readonly property bool custom: spread.target === "fill" ? spread.bs.colorMode === "custom" : spread.bs.textMode === "custom"

    leftContent: Plate {
        chapter: 2
        title: "The Bar"
        opening: false
        section: "Colour and finish"
        figure: "Fig. 3."
        caption: spread.bs.strip ? "The bar as one strip, in the colours set opposite; below, the strip over a chequer, to show how clear it is."
            : spread.bs.floating ? "The bar floating, in the colours set opposite; below, the pill over a chequer, to show how clear it is."
            : "The bar in the colours set opposite; below, its containers over a chequer, to show how clear they are."

        Item {
            anchors.fill: parent

            BarFigure {
                id: strips
                width: parent.width
                height: strips.stripsHeight
                edges: false
                lit: spread.focusKey
            }

            // A container, large, over a chequer: its colour, its text, and
            // how much of what's behind comes through.
            Item {
                id: specimen
                anchors.top: strips.bottom
                anchors.topMargin: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width

                Item {
                    id: chequer
                    anchors.fill: parent
                    clip: true

                    readonly property int cols: Math.max(1, Math.ceil(chequer.width / 14))
                    readonly property int rows: Math.max(0, Math.ceil(chequer.height / 14))

                    Grid {
                        columns: chequer.cols
                        Repeater {
                            model: chequer.cols * chequer.rows

                            Rectangle {
                                required property int index
                                readonly property int cols: chequer.cols
                                width: 14
                                height: 14
                                color: (Math.floor(index / cols) + index % cols) % 2 === 0 ? Colors.withAlpha(BookStyle.ink, 0.16) : Colors.withAlpha(BookStyle.ink, 0.04)
                            }
                        }
                    }
                }

                // A container, or as one strip a stretch of the band, edge
                // to edge.
                Rectangle {
                    anchors.centerIn: parent
                    width: spread.bs.strip ? parent.width : Math.min(parent.width - 60, 420)
                    height: 74
                    radius: spread.bs.strip ? 0 : Services.DesktopTheme.radius(Services.DesktopTheme.look, 37, 74)
                    color: spread.bs.pill
                    border.width: spread.bs.outline && !spread.bs.strip ? 2 : 0
                    border.color: spread.bs.outlineColor

                    // The strip's inner edge, with its hairline.
                    Rectangle {
                        visible: spread.bs.strip
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: Services.DesktopTheme.look.border ? Services.DesktopTheme.borderColor(Services.DesktopTheme.look) : spread.bs.outline ? spread.bs.outlineColor : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Services.Time.format("hh:mm") + "   ·   " + spread.bs.tone.name
                        font.family: Services.DesktopTheme.look.font || Qt.application.font.family
                        font.pixelSize: 28
                        color: spread.bs.ink
                    }
                }
            }
        }
    }

    Leaf {
        kicker: "§ 2"
        title: "Colour and finish"
        intro: "The bar's form, and its containers' colour and their text's: a tone of the wallpaper's own scheme, which follows it when it changes, or a colour of your own. Transparency fades the containers, never the text."
        spacing: 20

        Entry {
            id: form

            // Hyprland's outer gap, where the windows' own sides stand.
            readonly property var gap: Services.WindowLook.value("general.gaps_out")

            width: parent.width
            key: "form"
            label: "Its form"
            note: spread.bs.strip ? "One strip the length of the bar, flush to its edge, in the theme's trim; the widgets lie flat along it."
                : spread.bs.floating ? "One pill, clear of the screen's edge; the rule sets how far in from the sides"
                    + (typeof form.gap === "number" ? " (the tick: your windows)." : ".")
                : "Each widget in a pill of its own, a group of them in a tray."

            // (Close under one another: the choice keeps room of its own
            // round its words.)
            Column {
                spacing: -2

                InkChoice {
                    anchors.right: parent.right
                    options: spread.bs.styles.map(s => ({ id: s.id, label: s.name }))
                    current: spread.bs.style
                    onChosen: id => spread.bs.setStyle(id)
                }

                // Floating: how far the pill's ends stand in from the
                // screen's sides, with a tick where the windows' do.
                InkSlider {
                    width: parent.width
                    height: 32
                    visible: spread.bs.floating
                    from: spread.bs.insetMin
                    to: spread.bs.insetMax
                    stepSize: 2
                    unit: "px"
                    mark: typeof form.gap === "number" ? form.gap : NaN
                    value: spread.bs.inset
                    onMoved: v => spread.bs.setInset(v)
                }
            }
        }

        Entry {
            width: parent.width
            key: "target"
            label: "Colouring"

            InkChoice {
                options: [{ id: "fill", label: "The containers" }, { id: "ink", label: "Their text" }]
                current: spread.target
                onChosen: id => spread.target = id
            }
        }

        Entry {
            width: parent.width
            key: "source"
            label: "Taken from"
            stacked: true

            Column {
                spacing: 14

                InkChoice {
                    options: [{ id: "wallpaper", label: "The wallpaper" }, { id: "custom", label: "A colour of my own" }]
                    current: spread.custom ? "custom" : "wallpaper"
                    onChosen: id => {
                        if (spread.target === "fill")
                            spread.bs.setColorMode(id);
                        else
                            spread.bs.setTextMode(id);
                    }
                }

                // The wallpaper's tones, each as a little container.
                Flow {
                    width: parent.width
                    visible: !spread.custom
                    spacing: 10

                    Repeater {
                        model: spread.target === "fill" ? spread.bs.tones : spread.bs.textTones

                        Item {
                            id: chip

                            required property var modelData
                            readonly property bool on: spread.target === "fill" ? spread.bs.toneId === chip.modelData.id : spread.bs.textToneId === chip.modelData.id
                            readonly property color fill: spread.target === "fill" ? chip.modelData.fill : spread.bs.fill
                            readonly property color text: spread.target === "fill" ? chip.modelData.ink : (chip.modelData.color ?? spread.bs.autoInk)

                            width: 78
                            height: 66

                            Rectangle {
                                id: swatch
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 62
                                height: 36
                                radius: Services.DesktopTheme.radius(Services.DesktopTheme.look, 12, 36)
                                color: chip.fill
                                border.width: 1
                                border.color: BookStyle.line

                                Text {
                                    anchors.centerIn: parent
                                    text: "Aa"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: chip.text
                                }
                            }

                            Rectangle {
                                anchors.fill: swatch
                                anchors.margins: -4
                                radius: swatch.radius + 4
                                color: "transparent"
                                border.width: chip.on ? 2 : chipArea.containsMouse ? 1 : 0
                                border.color: BookStyle.accent
                            }

                            BookText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                text: chip.modelData.name
                                font.pixelSize: 12
                                font.italic: !chip.on
                                color: chip.on ? BookStyle.accent : BookStyle.inkSoft
                            }

                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (spread.target === "fill")
                                        spread.bs.setTone(chip.modelData.id);
                                    else
                                        spread.bs.setTextTone(chip.modelData.id);
                                }
                            }
                        }
                    }
                }

                HsvPicker {
                    width: parent.width
                    height: 186
                    visible: spread.custom
                    value: spread.target === "fill" ? spread.bs.fill : spread.bs.ink
                    onPicked: c => {
                        if (spread.target === "fill")
                            spread.bs.setCustomColor(c);
                        else
                            spread.bs.setCustomText(c);
                    }
                }
            }
        }

        Entry {
            width: parent.width
            key: "transparency"
            label: "Transparency"
            note: "Solid at the left, clear at the right."
            controlWidth: 300

            InkSlider {
                from: 0
                to: 100
                stepSize: 5
                unit: "%"
                value: Math.round(spread.bs.transparency * 100)
                onMoved: v => spread.bs.setTransparency(v / 100)
            }
        }

        Entry {
            width: parent.width
            key: "outline"
            label: "An outline"
            note: spread.bs.strip ? "A hairline in the text's colour along the strip's inner edge (a theme with a border of its own keeps that)."
                : spread.bs.floating ? "A hairline in the text's colour round the pill (a theme with a border of its own keeps that)."
                : "A hairline in the text's colour round each container (a theme with a border of its own keeps that)."

            InkSwitch {
                checked: spread.bs.outline
                onToggled: spread.bs.setOutline(!spread.bs.outline)
            }
        }

        Item {
            width: parent.width
            height: 30

            ContrastBadge {
                anchors.verticalCenter: parent.verticalCenter
            }

            InkButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !spread.bs.lookIsDefault
                icon: "format_color_reset"
                text: "The usual look"
                quiet: true
                onClicked: spread.bs.resetLook()
            }
        }
    }
}
