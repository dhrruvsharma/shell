pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The theme's emblem for the book's cover and frontispiece: 忍 brushed in
// crimson for the shinobi, 道 for the cultivator, an ensō for wabi-sabi, a
// lotus for Devaloka, sonar rings round the porthole for the abyss; the
// theme's own symbol otherwise. `ink` is what it's stamped in.
Item {
    id: emblem

    property color ink: BookStyle.accent
    property real size: 96

    implicitWidth: emblem.size * 1.6
    implicitHeight: emblem.size * 1.6

    Loader {
        anchors.centerIn: parent
        sourceComponent: ({
            sekiro: brushed,
            xianxia: brushed,
            wabisabi: brushed,
            devaloka: lotus,
            abyss: sonar
        })[BookStyle.themeId] ?? glyph
    }

    Component {
        id: brushed

        BrushKanji {
            text: ({ sekiro: "忍", xianxia: "道", wabisabi: "円" })[BookStyle.themeId] ?? "書"
            family: BookStyle.themeId === "xianxia" ? "Ma Shan Zheng" : "Yuji Boku"
            size: emblem.size * 1.15
            ink: emblem.ink
            seed: 4
            dry: 0.55
            bleed: 0.5
        }
    }

    Component {
        id: lotus

        Lotus {
            width: emblem.size * 1.5
            height: emblem.size
            stroke: emblem.ink
            fill: Colors.withAlpha(emblem.ink, 0.2)
            lineWidth: 1.6
        }
    }

    Component {
        id: sonar

        Item {
            width: emblem.size * 1.5
            height: emblem.size * 1.5

            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: emblem.size * (0.62 + index * 0.28)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.2
                    border.color: Colors.withAlpha(emblem.ink, 0.85 - index * 0.2)
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: Services.DesktopTheme.current?.icon ?? "scuba_diving"
                filled: true
                font.pixelSize: emblem.size * 0.5
                color: emblem.ink
            }
        }
    }

    Component {
        id: glyph

        Glyph {
            text: Services.DesktopTheme.current?.icon ?? "auto_stories"
            filled: true
            font.pixelSize: emblem.size
            color: emblem.ink
        }
    }
}
