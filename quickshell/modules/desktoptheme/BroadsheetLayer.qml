pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.modules.lock
import qs.modules.lock.themes.newspaper
import qs.services as Services

// Broadsheet desktop theme: the wallpaper printed in the morning paper, in
// four-colour halftone on newsprint with the fold across the middle
// (desktop_press shader; `wallpaper` is a texture of what's under the
// layer), and bottom right a clipping with the paper's name and your byline
// (the lock level as your job in the newsroom, XP as circulation). Static
// once drawn: the press runs as it switches on, dots growing out of blank
// paper. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1
    property Item wallpaper: null

    readonly property int level: Services.LockStats.level
    readonly property string user: Quickshell.env("USER") || "desktop"

    ShaderEffect {
        anchors.fill: parent
        visible: root.wallpaper !== null
        opacity: LockTheme.seg(root.boot, 0, 0.35)

        property variant source: root.wallpaper
        property real itemWidth: width
        property real itemHeight: height
        property real press: LockTheme.seg(root.boot, 0.1, 1)
        property real cell: Math.max(5, 3 / root.pxScale)
        property real fold: 1
        property color paperColor: Press.paper

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_press.frag.qsb")
    }

    // The byline, cut out of the paper, bottom right.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 42
        anchors.bottomMargin: 38
        width: byline.implicitWidth + 32
        height: byline.implicitHeight + 24
        opacity: LockTheme.seg(root.boot, 0.55, 1)

        Rectangle {
            x: 5
            y: 5
            width: parent.width
            height: parent.height
            color: Press.alpha("black", 0.45)
        }

        Rectangle {
            anchors.fill: parent
            color: Press.paper
        }

        Column {
            id: byline
            anchors.centerIn: parent
            spacing: 3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Press.paperName(root.user)
                font.family: Press.masthead
                font.pixelSize: 22
                font.weight: Font.Black
                color: Press.ink
            }

            Rectangle {
                width: parent.width
                height: 2
                color: Press.ink
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Press.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 2
                text: Press.volume(root.now) + "  ·  " + Press.number(root.now) + "  ·  " + Press.edition(root.now)
                font.family: Press.body
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.6
                color: Press.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "By " + root.user + ", " + Press.career(root.level) + "  —  circulation " + Press.count(Services.LockStats.xp)
                font.family: Press.body
                font.pixelSize: 12
                font.italic: true
                color: Press.inkSoft
            }
        }
    }
}
