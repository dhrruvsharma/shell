pragma ComponentBehavior: Bound
import QtQuick

// Characters written with a loaded brush: `text` in a brush face, given
// ragged, inky edges, dry streaks and a faint bleed (shaders/brush_kanji),
// and written in as `progress` runs 0 → 1. Sekiro's 死, 忍殺, 回生 and 危.
// `vertical` stacks the characters into a column. It keeps a margin round
// the glyphs for the ink to bleed into.
Item {
    id: root

    property string text: ""
    property string family: "Yuji Boku"
    property real size: 300
    property color ink: "#c8202a"
    property real progress: 1
    property real seed: 1
    property real dry: 0.6
    property real bleed: 0.6
    property bool vertical: false
    readonly property real pad: Math.round(size * 0.12)

    implicitWidth: glyphs.implicitWidth + 2 * pad
    implicitHeight: glyphs.implicitHeight + 2 * pad
    visible: progress > 0

    Item {
        anchors.fill: parent
        layer.enabled: root.visible
        layer.smooth: true
        layer.effect: ShaderEffect {
            property real itemWidth: root.width
            property real itemHeight: root.height
            property color inkColor: root.ink
            property real progress: root.progress
            property real seed: root.seed
            property real dry: root.dry
            property real bleed: root.bleed

            fragmentShader: Qt.resolvedUrl("../shaders/brush_kanji.frag.qsb")
        }

        Text {
            id: glyphs
            x: root.pad
            y: root.pad
            text: root.vertical ? root.text.split("").join("\n") : root.text
            font.family: root.family
            font.pixelSize: root.size
            lineHeight: root.vertical ? 0.94 : 1
            horizontalAlignment: Text.AlignHCenter
            color: "white"
        }
    }
}
