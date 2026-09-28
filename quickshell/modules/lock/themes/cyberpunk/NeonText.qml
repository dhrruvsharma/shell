pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Text lit like a neon tube slipping out of register: a pale core glowing in
// the first neon, with a ghost in each neon either side (`split` px apart).
// The glow is a static layer: it only re-renders when the text changes.
Item {
    id: nt

    property string text
    property string family: Neon.display
    property real size: 40
    property int weight: Font.Normal
    property real letterSpacing: 0
    property real split: 3
    property real glow: 1
    property color neonA: Neon.a
    property color neonB: Neon.b
    property color core: Qt.lighter(neonA, 1.4)

    implicitWidth: coreText.implicitWidth
    implicitHeight: coreText.implicitHeight

    Text {
        x: -nt.split
        y: nt.split * 0.5
        visible: nt.split > 0
        text: nt.text
        font: coreText.font
        color: Neon.alpha(nt.neonB, 0.75)
    }

    Text {
        x: nt.split
        y: -nt.split * 0.3
        visible: nt.split > 0
        text: nt.text
        font: coreText.font
        color: Neon.alpha(nt.neonA, 0.45)
    }

    Text {
        id: coreText
        text: nt.text
        font.family: nt.family
        font.pixelSize: nt.size
        font.weight: nt.weight
        font.letterSpacing: nt.letterSpacing
        color: nt.core
        layer.enabled: nt.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: nt.neonA
            shadowOpacity: nt.glow
            shadowBlur: 0.8
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
    }
}
