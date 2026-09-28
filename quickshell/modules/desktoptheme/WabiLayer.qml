pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock
import qs.modules.lock.themes.wabisabi
import qs.services as Services

// Wabi-sabi desktop theme, over the wallpaper: a veil of washi paper, edges
// aged a warm brown and two cracks mended with gold (desktop_washi shader),
// and the season in the bottom right corner: this week's micro-season in
// vertical Mincho, its solar term and your grade. Static once drawn: the
// paper settles and the gold fills the cracks as it switches on. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property var kou: Wabi.season72(now)
    readonly property var grade: Wabi.grade(Services.LockStats.level)
    readonly property color ink: Qt.tint(Colors.on_surface, Qt.rgba(0.93, 0.84, 0.66, 0.22))

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width
        property real itemHeight: height
        property real paper: 1
        property real age: 1
        property real seam: LockTheme.seg(root.boot, 0.35, 1)
        property real lineScale: Math.min(2.5, 1 / root.pxScale)
        property color paperColor: Wabi.paper
        property color ageColor: "#5a3d22"
        property color goldColor: Wabi.gold
        property color goldHi: Wabi.goldHi

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_washi.frag.qsb")
    }

    // The season, bottom right: the kō read top to bottom, glossed beside it.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 46
        anchors.bottomMargin: 40
        spacing: 16
        opacity: LockTheme.seg(root.boot, 0.45, 1) * 0.94

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.5
            shadowBlur: 0.7
            blurMax: 24
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Column {
            anchors.bottom: parent.bottom
            spacing: 5

            Text {
                anchors.right: parent.right
                text: root.kou.en.toLowerCase()
                font.family: Wabi.serif
                font.weight: Font.Light
                font.pixelSize: 16
                color: root.ink
            }

            Text {
                anchors.right: parent.right
                text: root.kou.sekki.ja + "  ·  " + root.kou.sekki.en.toLowerCase()
                font.family: Wabi.serif
                font.pixelSize: 12
                font.letterSpacing: 0.5
                color: Colors.withAlpha(root.ink, 0.72)
            }

            Text {
                anchors.right: parent.right
                text: root.grade.ja + "  ·  " + root.grade.en.toLowerCase()
                font.family: Wabi.serif
                font.pixelSize: 12
                font.letterSpacing: 0.5
                color: Wabi.accent
            }
        }

        Column {
            anchors.bottom: parent.bottom

            Repeater {
                model: root.kou.ja.split("")

                Text {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData
                    font.family: Wabi.serif
                    font.pixelSize: 26
                    color: root.ink
                }
            }
        }
    }
}
